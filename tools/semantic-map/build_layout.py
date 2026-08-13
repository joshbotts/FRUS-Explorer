#!/usr/bin/env python3
"""Tier-0 layout stage: the map's 2-D coordinates and clusters (V-4).

Reads the pooled document matrix, projects it to two dimensions, clusters it, and writes a compact
binary the Swift packer folds into the bundled artifact. This is the stage the V-4a spike identified
as V-4's critical path — the renderer was never the problem, and PCA-2D is a featureless cloud
(10.0% of the variance), so the map's entire value lives here.

    .cache/semantic-map-venv/bin/python tools/semantic-map/build_layout.py

Environment:
  POOL_DIR    directory holding doc_f32_768.npy + doc_keys.jsonl, as written by
              tools/semantic-harvest/corpus-gates/pool_docs.py   (default ~/frus-semantic-gates/pool)
  OUT_DIR     where to write layout.bin + layout-meta.json       (default Planning/semantic-map)
  DIMS        width of the vectors to project                    (default 256, the shipping width)
  NEIGHBORS   UMAP n_neighbors                                   (default 15)
  MIN_DIST    UMAP min_dist                                      (default 0.1)
  MIN_CLUSTER HDBSCAN min_cluster_size                           (default 250)
  SEED        random_state for every stage                       (default 18610810)

Why it takes its input from the pooled matrix rather than from the raw store: pooling is already
implemented twice — once in `pool_docs.py` and once in `SemanticVectorsGeneratorCore` — and both are
pinned against each other by measurement. A third implementation here would be a third thing that can
drift. The matrix's SHA-256 is recorded in provenance so the layout can always be traced to the
vectors it describes.

What this deliberately does NOT do: cluster *labels*. The design asks for c-TF-IDF labels "through
the WordCloudKit tokenizer and stopword stack, so labels speak the same vocabulary as every cloud
surface" — and that tokenizer is Swift. Labelling here would mean a second vocabulary that silently
disagrees with every word-cloud surface in the app, which is the cross-source-join failure this
repository keeps re-learning. Python emits cluster *ids*; Swift names them.
"""

import hashlib
import json
import os
import sys
import time

import numpy as np

SEED = int(os.environ.get("SEED", "18610810"))
DIMS = int(os.environ.get("DIMS", "256"))
NEIGHBORS = int(os.environ.get("NEIGHBORS", "15"))
MIN_DIST = float(os.environ.get("MIN_DIST", "0.1"))
MIN_CLUSTER = int(os.environ.get("MIN_CLUSTER", "250"))
POOL_DIR = os.path.expanduser(os.environ.get("POOL_DIR", "~/frus-semantic-gates/pool"))
OUT_DIR = os.environ.get("OUT_DIR", "Planning/semantic-map")

# The int16 grid the artifact stores. ±30000 rather than ±32767 so a later pass can nudge points
# apart without overflowing the type.
GRID_EXTENT = 30000.0


def log(message):
    print("[%s] %s" % (time.strftime("%H:%M:%S"), message), flush=True)


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    matrix_path = os.path.join(POOL_DIR, "doc_f32_768.npy")
    keys_path = os.path.join(POOL_DIR, "doc_keys.jsonl")
    for path in (matrix_path, keys_path):
        if not os.path.exists(path):
            sys.exit("missing input: %s (run tools/semantic-harvest/corpus-gates/pool_docs.py)" % path)

    log("hashing input matrix (traceability, not integrity)")
    matrix_digest = sha256_file(matrix_path)

    vectors = np.load(matrix_path, mmap_mode="r")
    count = vectors.shape[0]
    log("documents %d | native dims %d | projecting from %d" % (count, vectors.shape[1], DIMS))

    with open(keys_path) as handle:
        first_key = json.loads(handle.readline())
    key_count = sum(1 for _ in open(keys_path))
    if key_count != count:
        sys.exit("keys (%d) and matrix rows (%d) disagree" % (key_count, count))

    # Truncate to the shipping width and renormalise, so the layout describes the vectors the device
    # actually scores with rather than the full-width ones it never sees.
    # `np.asarray` on a memmap whose dtype already matches returns a READ-ONLY view, and the
    # in-place renormalise below then fails. Copy explicitly.
    cut = np.array(vectors[:, :DIMS], dtype=np.float32)
    norms = np.linalg.norm(cut, axis=1, keepdims=True)
    if not np.all(norms > 0):
        sys.exit("a truncated vector has no length — refusing to place it on a map")
    cut /= norms

    from sklearn.decomposition import PCA

    log("PCA -> 50 components")
    started = time.time()
    # Fit once and reuse: an earlier draft called `fit` a second time purely to log the variance,
    # which is a full pass over 314,483 x 256 for a number already in the fitted estimator.
    pca = PCA(n_components=50, random_state=SEED)
    reduced = pca.fit_transform(cut)
    variance = 100.0 * float(pca.explained_variance_ratio_.sum())
    log("PCA in %.1fs | explained variance %.1f%%" % (time.time() - started, variance))
    del cut

    import umap

    log("UMAP -> 2 (n_neighbors=%d, min_dist=%.2f, metric=cosine, random_state=%d)"
        % (NEIGHBORS, MIN_DIST, SEED))
    started = time.time()
    # random_state is set deliberately even though it costs UMAP its parallelism: an artifact that
    # rearranges itself between runs cannot be diffed, cannot be regression-tested, and would move
    # every document's position on screen after a rebuild that changed nothing.
    embedding = umap.UMAP(
        n_components=2, n_neighbors=NEIGHBORS, min_dist=MIN_DIST,
        metric="cosine", random_state=SEED, verbose=True).fit_transform(reduced)
    umap_seconds = time.time() - started
    log("UMAP in %.1f min" % (umap_seconds / 60))

    from sklearn.cluster import HDBSCAN

    log("HDBSCAN over the 2-D embedding (min_cluster_size=%d)" % MIN_CLUSTER)
    started = time.time()
    # Clustered in the 2-D embedding rather than in 50-D: the clusters a reader sees are the ones the
    # map draws, and clustering the high-dimensional space would produce labels that contradict the
    # picture. That is also what makes it affordable at 314k points.
    labels = HDBSCAN(min_cluster_size=MIN_CLUSTER, min_samples=10).fit_predict(embedding)
    cluster_seconds = time.time() - started
    clusters = int(labels.max()) + 1
    noise = int((labels < 0).sum())
    log("HDBSCAN in %.1f min | %d clusters | %d unclustered (%.1f%%)"
        % (cluster_seconds / 60, clusters, noise, 100.0 * noise / count))
    if clusters > 65534:
        sys.exit("%d clusters exceeds the artifact's uint16 cluster id" % clusters)

    # Grid to int16, preserving aspect: a map that stretched one axis to fill the range would put
    # documents at distances the embedding never claimed.
    low, high = embedding.min(axis=0), embedding.max(axis=0)
    span = float(np.max(high - low))
    if span <= 0:
        sys.exit("the embedding collapsed to a point")
    centred = embedding - (low + high) / 2.0
    grid = np.rint(centred / span * (2 * GRID_EXTENT)).astype(np.int16)

    os.makedirs(OUT_DIR, exist_ok=True)
    # Layout binary: int16 x, int16 y, uint16 cluster (0xFFFF = unclustered), per document, in the
    # pooled matrix's row order — which is the artifact's row order.
    packed = np.empty((count, 3), dtype=np.uint16)
    packed[:, 0] = grid[:, 0].view(np.uint16)
    packed[:, 1] = grid[:, 1].view(np.uint16)
    packed[:, 2] = np.where(labels < 0, 0xFFFF, labels).astype(np.uint16)
    layout_path = os.path.join(OUT_DIR, "layout.bin")
    packed.tofile(layout_path)

    meta = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "documents": count,
        "firstKey": first_key,
        "sourceMatrix": os.path.basename(matrix_path),
        "sourceMatrixSHA256": matrix_digest,
        "projectedFromDims": DIMS,
        "seed": SEED,
        "pca": {"components": 50, "explainedVariancePercent": round(variance, 2)},
        "umap": {"nNeighbors": NEIGHBORS, "minDist": MIN_DIST, "metric": "cosine",
                 "seconds": round(umap_seconds, 1)},
        "hdbscan": {"minClusterSize": MIN_CLUSTER, "minSamples": 10,
                    "clusters": clusters, "unclustered": noise,
                    "seconds": round(cluster_seconds, 1)},
        "grid": {"extent": GRID_EXTENT, "layout": "int16 x, int16 y, uint16 cluster (0xFFFF=none)"},
        "versions": {},
    }
    for module in ("numpy", "sklearn", "umap"):
        try:
            meta["versions"][module] = __import__(module).__version__
        except Exception:  # pragma: no cover - a missing module cannot reach here
            meta["versions"][module] = "unknown"
    with open(os.path.join(OUT_DIR, "layout-meta.json"), "w") as handle:
        json.dump(meta, handle, indent=2, sort_keys=True)

    log("wrote %s (%.2f MB) + layout-meta.json"
        % (layout_path, os.path.getsize(layout_path) / 1e6))


if __name__ == "__main__":
    main()
