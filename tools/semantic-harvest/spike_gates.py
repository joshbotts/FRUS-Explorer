#!/usr/bin/env python3
"""V-0 spike gates over the five raw spike stores (Phase 2 of the semantic runbook).

Consumes the Studio's `frus-semantic-raw-spike-*` stores (validated first — checksums,
head/bin/meta consistency, identical decompressed text layers) and produces the numbers
the design doc's §8 says pick the full-run model:

  Gate A  weak positives   cross_references edges from the live app index, page anchors
                           resolved through page_ranges; MRR@10 / hit@10 per model per era.
  Gate B  quantization     recall@10 versus each model's own float full-dim truth for:
          ladder           MRL-truncated float-256, int8-256, int8-128, binary-256 Hamming,
                           and the shipping pipeline (Hamming top-200 -> int8-256 rerank).
                           Plus the free model-quant rung: nomic Q4_K_M vs Q8_0.
  Gate C  blind panel      100 era-stratified anchor->top-neighbor rows at the shipping
                           config, pre-1900 its own bucket, Schedule A and the two most
                           digit-dense frus1861 docs forced in; judgment column empty.
                           Model/scores go to a separate key file so the panel stays blind.
  Wall clock               chars/s from each store's run-manifest, extrapolated to the
                           1.374 B-char corpus (M2 ride-along §1, measured 2026-08-07).

Pooling rule (recorded in the output JSON): chunk vectors arrive unit-norm from LM Studio
(verified across all five stores); document vector = char-length-weighted mean of chunk
vectors, L2-renormalized. Matryoshka truncation renormalizes after the cut. int8 is
per-vector symmetric (scale = max|x|/127); binary is the sign bit.

Unlike the Studio-side scripts this one needs numpy (it is the Air-side analysis half —
the design doc's Stage-1 toolchain is Python regardless). Everything else is stdlib.
Deterministic: fixed RNG seed, explicit sorts, sorted JSON keys.

Environment:
  STORES     comma-separated label=path pairs; default the five spike stores under ~
  DB         live index (read-only); default the app container's frus.db
  OUT_DIR    default Planning/semantic-spike
  PANEL_MODEL  store label to stage the panel from (default: best overall Gate-A MRR@10,
               the forbidden-quant 'nomic' Q4_K_M store excluded from candidacy)
"""

import csv
import gzip
import json
import os
import random
import sqlite3
import sys

import numpy as np

SEED = 18610810  # frus1861 + 2026-08-10, fixed forever
SPIKE_VOLUMES = ["frus1861", "frus1938v01", "frus1948v06"]
ERA = {"frus1861": "pre-1900", "frus1938v01": "interwar", "frus1948v06": "cold-war"}
PANEL_QUOTA = {"frus1861": 34, "frus1938v01": 33, "frus1948v06": 33}
CORPUS_CHARS = 1.374e9  # M2-Semantic-Pipeline-Ride-Along.md §1, measured 2026-08-07
RERANK_POOL = 200  # Hamming candidates fed to the int8 rerank (design §4.2)
TOP_K = 10
SNIPPET_CHARS = 280

DEFAULT_STORES = ",".join(
    "%s=%s" % (label, os.path.expanduser("~/frus-semantic-raw-spike-" + label))
    for label in ["gemma", "arctic", "nomic", "nomic-q8", "bge"]
)
DEFAULT_DB = os.path.expanduser(
    "~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
)


# ---------------------------------------------------------------- store loading

def load_store(path):
    """Pooled document matrix + aligned keys + text layer for one spike store."""
    manifest = json.load(open(os.path.join(path, "run-manifest.json")))
    dim = manifest["dim"]
    keys, texts, doc_vecs = [], {}, []
    for vol in SPIKE_VOLUMES:
        head = json.load(open(os.path.join(path, "vectors", vol + ".head.json")))
        vecs = np.fromfile(os.path.join(path, "vectors", vol + ".bin"), dtype="<f4")
        vecs = vecs.reshape(head["chunks"], dim)
        meta = [json.loads(line) for line in open(os.path.join(path, "vectors", vol + ".meta.jsonl"))]
        assert len(meta) == head["chunks"]
        with gzip.open(os.path.join(path, "text", vol + ".jsonl.gz"), "rt", encoding="utf-8") as fh:
            docs = [json.loads(line) for line in fh]
        assert len(docs) == head["docs"]
        # Chunk rows are written in doc order; pool by (doc, char-length weight).
        by_doc = {}
        for row, m in zip(vecs, meta):
            by_doc.setdefault(m["d"], []).append((m["c1"] - m["c0"], row))
        for doc in docs:  # doc order == ordinal order == extraction order
            weighted = by_doc[doc["d"]]
            weights = np.array([w for w, _ in weighted], dtype=np.float64)
            stacked = np.stack([r for _, r in weighted]).astype(np.float64)
            pooled = (stacked * weights[:, None]).sum(axis=0) / weights.sum()
            norm = np.linalg.norm(pooled)
            doc_vecs.append(pooled / norm)
            keys.append((vol, doc["d"]))
            texts[(vol, doc["d"])] = doc["t"]
    matrix = np.stack(doc_vecs).astype(np.float32)
    return {"manifest": manifest, "dim": dim, "keys": keys,
            "index": {k: i for i, k in enumerate(keys)}, "texts": texts, "float_full": matrix}


# ---------------------------------------------------------------- quantization

def truncate(matrix, dims):
    cut = matrix[:, :dims]
    return cut / np.linalg.norm(cut, axis=1, keepdims=True)


def is_mrl(store):
    """bge-small is the no-MRL control; truncating it would be a fictional config."""
    return "bge" not in store["manifest"]["model"]


def mrl_dims(store):
    """The truncation rungs each model's card actually sanctions. arctic l-v2.0
    documents 256 only; running undocumented cuts would measure fictional configs."""
    model = store["manifest"]["model"]
    if "embeddinggemma" in model or "nomic" in model:
        return [512, 256, 128]
    if "arctic" in model:
        return [256]
    return [256, 128] if is_mrl(store) else []


def shipping_dims(store):
    """256 for the Matryoshka models (the design's Tier shape); native width for the
    no-MRL control, which could never ship at 256 anyway."""
    return 256 if is_mrl(store) and store["dim"] > 256 else store["dim"]


def int8_quantize(matrix):
    scale = np.abs(matrix).max(axis=1) / 127.0
    q = np.clip(np.rint(matrix / scale[:, None]), -127, 127).astype(np.int8)
    return q, scale.astype(np.float32)


def int8_scores(q, scale, query_rows):
    """Approximate cosine of query_rows against every vector (int8 dot x scales)."""
    dots = q[query_rows].astype(np.int32) @ q.T.astype(np.int32)
    return dots * scale[query_rows][:, None] * scale[None, :]


def pack_bits(matrix):
    return np.packbits(matrix >= 0, axis=1)


def hamming_distances(packed, query_rows):
    xor = np.bitwise_xor(packed[query_rows][:, None, :], packed[None, :, :])
    return np.bitwise_count(xor).sum(axis=2, dtype=np.int32)


def top_k_from_scores(scores, self_row, k, tie_key):
    """Indices of the k best scores, self excluded, ties broken by stable key order."""
    order = np.lexsort((tie_key, -scores))
    return [i for i in order if i != self_row][:k]


# ---------------------------------------------------------------- Gate A: weak positives

def load_edges(db_path, doc_index):
    """Directed weak-positive pairs (source_row, {target_rows}) per volume, deduplicated.

    Document anchors are taken as stored; page anchors resolve through page_ranges to
    every document spanning that page (the referenced document usually starts there; any
    member counting as a hit mirrors what a reader lands on). Self-references and
    endpoints outside the store's document set are dropped and counted.
    """
    con = sqlite3.connect("file:%s?mode=ro" % db_path, uri=True)
    pages = {}  # (vol, page_int) -> [doc_id]
    marks = ",".join("?" * len(SPIKE_VOLUMES))
    for vol, doc, page in con.execute(
            "SELECT volume_id, document_id, page_number_int FROM page_ranges "
            "WHERE volume_id IN (%s) AND page_number_type='arabic' "
            "ORDER BY volume_id, page_number_int, document_id" % marks, SPIKE_VOLUMES):
        pages.setdefault((vol, page), []).append(doc)
    pairs, dropped = {}, {"self": 0, "unresolved_page": 0, "not_in_store": 0, "cross_volume": 0}
    rows = con.execute(
        "SELECT source_volume_id, source_document_id, target_volume_id, target_document_id "
        "FROM cross_references WHERE source_volume_id IN (%s) AND is_broken=0 "
        "ORDER BY id" % marks, SPIKE_VOLUMES)
    resolved_pairs = 0
    for svol, sdoc, tvol, tdoc in rows:
        if tvol and tvol != svol:
            dropped["cross_volume"] += 1  # its vectors are outside the spike set
            continue
        if tdoc.startswith("pg_"):
            try:
                targets = pages.get((svol, int(tdoc[3:])), [])
            except ValueError:
                targets = []  # roman-numeral front-matter page
            if not targets:
                dropped["unresolved_page"] += 1
                continue
        else:
            targets = [tdoc]
        source = doc_index.get((svol, sdoc))
        target_rows = frozenset(
            doc_index[(svol, t)] for t in targets if (svol, t) in doc_index and t != sdoc)
        if source is None or (not target_rows and any((svol, t) in doc_index for t in targets)):
            dropped["self" if source is not None else "not_in_store"] += 1
            continue
        if not target_rows:
            dropped["not_in_store"] += 1
            continue
        before = len(pairs.get((svol, source), set()))
        for t in sorted(target_rows):
            pairs.setdefault((svol, source), set()).add(t)
        resolved_pairs += len(pairs[(svol, source)]) - before
    con.close()
    per_volume = {}
    for (vol, source), targets in sorted(pairs.items()):
        per_volume.setdefault(vol, []).append((source, sorted(targets)))
    return per_volume, dropped, resolved_pairs


def gate_a(store, edges_by_volume, score_fn):
    """Standard multi-relevant MRR@10 per volume: one query per citing document, relevant
    set = the union of everything it cites, rank of the first relevant result. The page-
    anchor labels are noisy (an editorial "see p. N" often lands on a tangentially related
    document), so the wider rank statistics are reported alongside — the same noise hits
    every model identically, which is what makes the gate comparative."""
    tie_key = np.arange(len(store["keys"]))
    out = {}
    all_ranks = []
    for vol, edges in sorted(edges_by_volume.items()):
        sources = sorted({s for s, _ in edges})
        scores = score_fn(sources)
        by_source = {s: scores[i] for i, s in enumerate(sources)}
        ranks = []
        for source, targets in edges:
            order = np.lexsort((tie_key, -np.asarray(by_source[source], dtype=np.float64)))
            ranked = [i for i in order if i != source]
            ranks.append(min(ranked.index(t) + 1 for t in targets))
        all_ranks += ranks
        out[vol] = summarize_ranks(ranks)
    out["overall"] = summarize_ranks(all_ranks)
    return out


def summarize_ranks(ranks):
    arr = np.array(ranks)
    return {"queries": len(arr),
            "mrr@10": round(float(np.where(arr <= TOP_K, 1.0 / arr, 0.0).mean()), 4),
            "hit@10": round(float((arr <= 10).mean()), 4),
            "hit@50": round(float((arr <= 50).mean()), 4),
            "hit@100": round(float((arr <= 100).mean()), 4),
            "median_rank": int(np.median(arr))}


# ---------------------------------------------------------------- Gate B: the ladder

def gate_b(store):
    """recall@10 against the store's own float full-dim truth, per rung. MRL stores run
    the truncation rungs; the no-MRL control runs the same quantizations at native width
    (truncating it would measure a config that could never ship)."""
    full = store["float_full"]
    n = len(full)
    tie_key = np.arange(n)
    sims = full @ full.T
    truth = [set(top_k_from_scores(sims[i], i, TOP_K, tie_key)) for i in range(n)]

    ladder = {}

    def recall(top_lists, name):
        overlap = [len(truth[i] & set(top_lists[i])) / TOP_K for i in range(n)]
        ladder[name] = round(float(np.mean(overlap)), 4)

    def quant_rungs(cut, dims, hamming_too):
        q, scale = int8_quantize(cut)
        q_scores = int8_scores(q, scale, np.arange(n))
        recall([top_k_from_scores(q_scores[i], i, TOP_K, tie_key) for i in range(n)],
               "int8-%d" % dims)
        if not hamming_too:
            return
        packed = pack_bits(cut)
        dist = hamming_distances(packed, np.arange(n))
        recall([top_k_from_scores(-dist[i].astype(np.float32), i, TOP_K, tie_key)
                for i in range(n)], "binary-%d" % dims)
        rerank_top = []
        for i in range(n):
            cands = top_k_from_scores(-dist[i].astype(np.float32), i, RERANK_POOL, tie_key)
            cand_scores = (q[cands].astype(np.int32) @ q[i].astype(np.int32)
                           ) * scale[cands] * scale[i]
            order = np.lexsort((np.array(cands), -cand_scores))
            rerank_top.append([cands[j] for j in order[:TOP_K]])
        recall(rerank_top, "hamming%d->int8-%d" % (RERANK_POOL, dims))

    for dims in [d for d in mrl_dims(store) if d < store["dim"]]:
        cut = truncate(full, dims)
        cut_sims = cut @ cut.T
        recall([top_k_from_scores(cut_sims[i], i, TOP_K, tie_key) for i in range(n)],
               "float-%d" % dims)
        quant_rungs(cut, dims, hamming_too=(dims == 256))
    if not is_mrl(store):
        quant_rungs(full, store["dim"], hamming_too=True)
    return ladder


def quant_pair_agreement(store_a, store_b):
    """Same model one quant tier apart: does the ladder's foundation move? recall@10 of
    each store's float-full truth against the other's, plus rank-1 agreement."""
    assert store_a["keys"] == store_b["keys"]
    n = len(store_a["keys"])
    tie_key = np.arange(n)
    tops = []
    for store in (store_a, store_b):
        sims = store["float_full"] @ store["float_full"].T
        tops.append([top_k_from_scores(sims[i], i, TOP_K, tie_key) for i in range(n)])
    overlap = [len(set(tops[0][i]) & set(tops[1][i])) / TOP_K for i in range(n)]
    rank1 = sum(1 for i in range(n) if tops[0][i][0] == tops[1][i][0]) / n
    return {"recall@10_mutual": round(float(np.mean(overlap)), 4),
            "rank1_agreement": round(rank1, 4)}


# ---------------------------------------------------------------- Gate C: blind panel

def shipping_top1(store, rows):
    """Top-1 via the shipping pipeline: Hamming top-200 -> int8 rerank at the store's
    shipping width (256 for MRL models; native for the control, marked in the key)."""
    dims = shipping_dims(store)
    cut = truncate(store["float_full"], dims) if dims < store["dim"] else store["float_full"]
    q, scale = int8_quantize(cut)
    packed = pack_bits(cut)
    tie_key = np.arange(len(cut))
    dist = hamming_distances(packed, np.array(rows))
    out = {}
    for qi, i in enumerate(rows):
        cands = top_k_from_scores(-dist[qi].astype(np.float32), i, RERANK_POOL, tie_key)
        cand_scores = (q[cands].astype(np.int32) @ q[i].astype(np.int32)) * scale[cands] * scale[i]
        order = np.lexsort((np.array(cands), -cand_scores))
        best = cands[order[0]]
        out[i] = (best, float(cand_scores[order[0]]),
                  float(store["float_full"][i] @ store["float_full"][best]))
    return out


def digit_density(text):
    return sum(c.isdigit() for c in text) / max(1, len(text))


def stage_panel(stores, panel_label, out_dir):
    store = stores[panel_label]
    rng = random.Random(SEED)
    anchors = []
    vol_docs = {vol: [k for k in store["keys"] if k[0] == vol] for vol in SPIKE_VOLUMES}
    # Forced structural anchors: Schedule A plus the two most digit-dense frus1861 docs
    # (the lexical assessment's "structural-document cousins", chosen by measurement).
    forced = [("frus1861", "d1")]
    density = sorted(vol_docs["frus1861"], key=lambda k: (-digit_density(store["texts"][k]), k))
    forced += [k for k in density[:3] if k not in forced][:2]
    for vol in SPIKE_VOLUMES:
        pool = [k for k in vol_docs[vol] if k not in forced]
        quota = PANEL_QUOTA[vol] - sum(1 for f in forced if f[0] == vol)
        anchors += [f for f in forced if f[0] == vol] + rng.sample(sorted(pool), quota)
    rows = [store["index"][k] for k in anchors]
    top1 = shipping_top1(store, rows)
    # Top-1 agreement across every store at its shipping config, as a per-row signal.
    agreement = {i: 0 for i in rows}
    for label in sorted(stores):
        other = shipping_top1(stores[label], rows) if label != panel_label else top1
        for i in rows:
            if stores[label]["keys"][other[i][0]] == store["keys"][top1[i][0]]:
                agreement[i] += 1

    def snip(key):
        return " ".join(store["texts"][key].split())[:SNIPPET_CHARS]

    panel_path = os.path.join(out_dir, "blind-panel.csv")
    key_path = os.path.join(out_dir, "blind-panel-key.csv")
    with open(panel_path, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["row", "era", "anchor_volume", "anchor_doc", "anchor_snippet",
                    "neighbor_volume", "neighbor_doc", "neighbor_snippet",
                    "verdict (good / moderate / garbage)", "note"])
        for row_no, key in enumerate(anchors, 1):
            i = store["index"][key]
            nkey = store["keys"][top1[i][0]]
            w.writerow([row_no, ERA[key[0]], key[0], key[1], snip(key),
                        nkey[0], nkey[1], snip(nkey), "", ""])
    with open(key_path, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["row", "model", "config", "int8_score", "float_cosine",
                    "top1_agreement_of_%d" % len(stores)])
        config = "hamming%d->int8-%d" % (RERANK_POOL, shipping_dims(store))
        for row_no, key in enumerate(anchors, 1):
            i = store["index"][key]
            w.writerow([row_no, panel_label, config,
                        round(top1[i][1], 4), round(top1[i][2], 4), agreement[i]])
    return panel_path, key_path, anchors


# ---------------------------------------------------------------- main

def main():
    stores_spec = os.environ.get("STORES", DEFAULT_STORES)
    db_path = os.environ.get("DB", DEFAULT_DB)
    out_dir = os.environ.get("OUT_DIR", os.path.join("Planning", "semantic-spike"))
    os.makedirs(out_dir, exist_ok=True)

    stores = {}
    for part in stores_spec.split(","):
        label, path = part.split("=", 1)
        print("loading %s ..." % label)
        stores[label] = load_store(path)
    reference = next(iter(stores.values()))
    for label, store in stores.items():
        assert store["keys"] == reference["keys"], "doc set diverges: %s" % label

    edges, dropped, resolved_pairs = load_edges(db_path, reference["index"])
    print("weak-positive queries: %s, %d resolved pairs (dropped: %s)"
          % ({v: len(e) for v, e in sorted(edges.items())}, resolved_pairs, dropped))

    results = {"pooling": "char-length-weighted mean of unit-norm chunk vectors, L2-renormalized",
               "seed": SEED, "db": db_path, "top_k": TOP_K, "rerank_pool": RERANK_POOL,
               "weak_positive_queries": {v: len(e) for v, e in sorted(edges.items())},
               "weak_positive_resolved_pairs": resolved_pairs,
               "weak_positive_drops": dropped, "models": {}}

    for label in sorted(stores):
        store = stores[label]
        print("gates for %s (dim %d) ..." % (label, store["dim"]))
        entry = {"model": store["manifest"]["model"], "dim": store["dim"],
                 "prefix": store["manifest"]["prefix"],
                 "chunk_chars": store["manifest"]["chunk_chars"]}
        entry["gate_a_float_full"] = gate_a(
            store, edges, lambda rows, m=store["float_full"]: m[rows] @ m.T)
        dims = shipping_dims(store)
        cut = truncate(store["float_full"], dims) if dims < store["dim"] else store["float_full"]
        q, scale = int8_quantize(cut)
        entry["gate_a_int8_%d" % dims] = gate_a(
            store, edges, lambda rows, q=q, s=scale: int8_scores(q, s, np.array(rows)))
        entry["gate_b_ladder"] = gate_b(store)
        totals = store["manifest"]["totals_this_run"]
        rate = totals["chars"] / totals["embed_secs"]
        entry["throughput_chars_per_s"] = round(rate)
        entry["full_corpus_hours"] = round(CORPUS_CHARS / rate / 3600, 1)
        results["models"][label] = entry

    if "nomic" in stores and "nomic-q8" in stores:
        results["nomic_q4_vs_q8"] = quant_pair_agreement(stores["nomic"], stores["nomic-q8"])

    candidates = {label: results["models"][label]["gate_a_float_full"]["overall"]["mrr@10"]
                  for label in sorted(stores) if label != "nomic"}
    auto = max(sorted(candidates), key=lambda l: candidates[l])
    panel_label = os.environ.get("PANEL_MODEL", auto)
    results["panel"] = {"model": panel_label, "auto_pick": auto,
                        "auto_pick_basis": "best overall Gate-A MRR@10 at float full-dim, "
                                           "Q4_K_M store excluded"}
    panel_path, key_path, anchors = stage_panel(stores, panel_label, out_dir)
    results["panel"]["rows"] = len(anchors)
    results["panel"]["csv"] = panel_path
    results["panel"]["key"] = key_path

    out_json = os.path.join(out_dir, "spike-gates.json")
    json.dump(results, open(out_json, "w"), indent=2, sort_keys=True)
    print("\n" + json.dumps(results, indent=2, sort_keys=True))
    print("\nwrote %s, %s, %s" % (out_json, panel_path, key_path))


if __name__ == "__main__":
    main()
