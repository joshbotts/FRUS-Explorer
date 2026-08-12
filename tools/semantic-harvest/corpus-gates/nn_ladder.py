#!/usr/bin/env python3
"""Corpus-scale nearest-neighbor structure + quantization ladder (assessment task).

Reuses spike_gates.py's pinned numeric procedures exactly:
  - int8_scores: int8 dot products (exact integers) x scale outer product; numpy
    promotes int32*float32 -> float64, so scores here are computed as
    exact_dot.astype(float64) * scale_f32[:,None] * scale_f32[None,:] (bit-identical).
    The exact integer dots are obtained via float32 GEMM: |dot| <= 512*127^2 = 8,258,048
    < 2^24, so every partial sum is an exactly-representable integer in float32.
  - hamming: XOR + popcount (np.bitwise_count) on the packed 256-bit sign vectors.
  - tie-break identical to top_k_from_scores: score desc, then row index asc,
    self-row excluded. Implemented via an exact threshold prefilter + lexsort on the
    tie band (provably identical to the full lexsort; see select_topk).
  - rerank tie-break identical to gate_b's rerank: lexsort((cands, -cand_scores)).

Seed 18610810 (spike_gates.SEED). Deterministic throughout.
"""

import json
import os
import random
import resource
import sys
import time

import numpy as np

SEED = 18610810
TOP_K = 10
RERANK_POOL = 200
CHAR_FLOOR = 200          # queries must have >= 200 chars
QUERIES_PER_BAND = 1200
BAND_ORDER = ["pre1900", "1900_1945", "post1945"]  # fixed sampling order

ASSESS = os.path.expanduser(os.environ.get("ASSESS_DIR", "~/frus-semantic-gates"))
POOL = os.path.join(ASSESS, "pool")
WORK = os.path.join(ASSESS, "nn_work")
MANIFEST = os.environ.get("MANIFEST", "FRUSExplorer/Resources/manifest.json")

os.makedirs(WORK, exist_ok=True)


def log(msg):
    print("[%s] %s" % (time.strftime("%H:%M:%S"), msg), flush=True)


def rss_gb():
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1e9  # bytes on macOS


# ---------------------------------------------------------------- exact top-k
def select_topk(scores, self_row, k):
    """First k rows of np.lexsort((arange(n), -scores)) with self_row removed.

    Exact: thr = the (k+2)-th largest score value (counting multiplicity); every
    member of the true top-(k+2) has score >= thr, so the candidate set
    {i: scores[i] >= thr} contains it, and the full tie band at thr is included,
    so index-ascending tie-break within the band is preserved.
    """
    n = scores.shape[0]
    kth = n - (k + 2)
    thr = np.partition(scores, kth)[kth]
    cand = np.flatnonzero(scores >= thr)
    order = np.lexsort((cand, -scores[cand]))
    sel = cand[order]
    return sel[sel != self_row][:k]


# ---------------------------------------------------------------- load inputs
def load_keys():
    keys = []
    with open(os.path.join(POOL, "doc_keys.jsonl")) as fh:
        for line in fh:
            keys.append(json.loads(line))
    return keys


def band_of_volume(manifest):
    bands = {}
    for e in manifest:
        ye = int(e["dateRange"]["earliest"][:4])
        yl = int(e["dateRange"]["latest"][:4])
        mid = (ye + yl) / 2.0
        bands[e["volumeId"]] = ("pre1900" if mid < 1900
                                else ("1900_1945" if mid <= 1945 else "post1945"))
    return bands


def main():
    t0 = time.time()
    manifest = json.load(open(MANIFEST))
    vol_band = band_of_volume(manifest)
    band_volume_counts = {b: 0 for b in BAND_ORDER}
    for v, b in vol_band.items():
        band_volume_counts[b] += 1

    keys = load_keys()
    n = len(keys)
    log("keys: %d" % n)
    vols = [k["v"] for k in keys]
    dids = [k["d"] for k in keys]
    chars = np.array([k["chars"] for k in keys], dtype=np.int64)
    row_band = np.array([BAND_ORDER.index(vol_band[v]) for v in vols], dtype=np.int8)
    # volume ids as ints for fast same-volume checks
    vol_ids = {}
    row_vol = np.empty(n, dtype=np.int32)
    for i, v in enumerate(vols):
        row_vol[i] = vol_ids.setdefault(v, len(vol_ids))

    band_doc_counts = {b: int((row_band == bi).sum()) for bi, b in enumerate(BAND_ORDER)}
    band_below_floor = {b: int(((row_band == bi) & (chars < CHAR_FLOOR)).sum())
                        for bi, b in enumerate(BAND_ORDER)}

    # ------------------------------------------------------------ query sample
    qpath = os.path.join(WORK, "queries.npz")
    if os.path.exists(qpath):
        z = np.load(qpath)
        qrows = z["qrows"]
        log("resume: %d queries" % len(qrows))
    else:
        rng = random.Random(SEED)
        qrows = []
        for bi, b in enumerate(BAND_ORDER):
            eligible = sorted(np.flatnonzero((row_band == bi) & (chars >= CHAR_FLOOR)).tolist())
            take = (eligible if len(eligible) <= QUERIES_PER_BAND
                    else rng.sample(eligible, QUERIES_PER_BAND))
            qrows += sorted(take)
        qrows = np.array(qrows, dtype=np.int64)
        np.savez(qpath, qrows=qrows)
        log("sampled %d queries" % len(qrows))
    Q = len(qrows)
    q_band = row_band[qrows]

    # ------------------------------------------------------------ float truth
    tpath = os.path.join(WORK, "truth.npz")
    F = np.load(os.path.join(POOL, "doc_f32_768.npy"), mmap_mode=None)
    log("loaded F %s rss=%.2fGB" % (F.shape, rss_gb()))
    if os.path.exists(tpath):
        z = np.load(tpath)
        truth_rows, truth_cos = z["rows"], z["cos"]
        log("resume: truth loaded")
    else:
        truth_rows = np.empty((Q, TOP_K), dtype=np.int64)
        truth_cos = np.empty((Q, TOP_K), dtype=np.float32)
        B = 300
        for s in range(0, Q, B):
            batch = qrows[s:s + B]
            sims = F[batch] @ F.T                     # float32 GEMM, as in gate_b
            for j in range(len(batch)):
                top = select_topk(sims[j], batch[j], TOP_K)
                truth_rows[s + j] = top
                truth_cos[s + j] = sims[j][top]
            if (s // B) % 4 == 0:
                log("truth %d/%d rss=%.2fGB" % (s + len(batch), Q, rss_gb()))
        np.savez(tpath, rows=truth_rows, cos=truth_cos)
        log("truth done")

    # ------------------------------------------------------------ int8 configs
    def int8_config(dims):
        path = os.path.join(WORK, "int8_%d.npz" % dims)
        if os.path.exists(path):
            return np.load(path)["rows"]
        q = np.load(os.path.join(POOL, "doc_int8_%d.npy" % dims))
        scale = np.load(os.path.join(POOL, "doc_scale_%d.npy" % dims))
        Xf = q.astype(np.float32)
        s64 = scale.astype(np.float64)
        out = np.empty((Q, TOP_K), dtype=np.int64)
        B = 200
        for s in range(0, Q, B):
            batch = qrows[s:s + B]
            dots = (Xf[batch] @ Xf.T).astype(np.float64)   # exact integer dots
            scores = dots * s64[batch][:, None] * s64[None, :]
            for j in range(len(batch)):
                out[s + j] = select_topk(scores[j], batch[j], TOP_K)
            if (s // B) % 4 == 0:
                log("int8-%d %d/%d rss=%.2fGB" % (dims, s + len(batch), Q, rss_gb()))
        np.savez(path, rows=out)
        del q, Xf
        return out

    int8_256_rows = int8_config(256)
    log("int8-256 done")
    int8_512_rows = int8_config(512)
    log("int8-512 done")

    # ------------------------------------------------ hamming funnel + reranks
    hpath = os.path.join(WORK, "hamming_reranks.npz")
    if os.path.exists(hpath):
        z = np.load(hpath)
        ham256_rows, ham512_rows = z["r256"], z["r512"]
        log("resume: hamming reranks loaded")
    else:
        bits = np.load(os.path.join(POOL, "doc_bits_256.npy"))
        packed64 = np.ascontiguousarray(bits).view(np.uint64)   # (n, 4)
        q256 = np.load(os.path.join(POOL, "doc_int8_256.npy"))
        s256 = np.load(os.path.join(POOL, "doc_scale_256.npy"))
        q512 = np.load(os.path.join(POOL, "doc_int8_512.npy"))
        s512 = np.load(os.path.join(POOL, "doc_scale_512.npy"))
        ham256_rows = np.empty((Q, TOP_K), dtype=np.int64)
        ham512_rows = np.empty((Q, TOP_K), dtype=np.int64)
        B = 100
        for s in range(0, Q, B):
            batch = qrows[s:s + B]
            xor = packed64[batch][:, None, :] ^ packed64[None, :, :]
            dist = np.bitwise_count(xor).sum(axis=2, dtype=np.int32)
            del xor
            for j in range(len(batch)):
                i = batch[j]
                cands = select_topk(-dist[j].astype(np.float32), i, RERANK_POOL)
                carr = np.asarray(cands)
                for qm, sm, out in ((q256, s256, ham256_rows), (q512, s512, ham512_rows)):
                    cand_scores = (qm[carr].astype(np.int32) @ qm[i].astype(np.int32)
                                   ) * sm[carr] * sm[i]
                    order = np.lexsort((carr, -cand_scores))
                    out[s + j] = carr[order[:TOP_K]]
            if (s // B) % 6 == 0:
                log("hamming %d/%d rss=%.2fGB" % (s + len(batch), Q, rss_gb()))
        np.savez(hpath, r256=ham256_rows, r512=ham512_rows)
        del bits, packed64, q256, q512
        log("hamming reranks done")

    # ------------------------------------------------------------ metrics
    def recall(config_rows):
        r = np.array([len(set(truth_rows[i]) & set(config_rows[i])) / TOP_K
                      for i in range(Q)])
        out = {"overall": round(float(r.mean()), 4)}
        for bi, b in enumerate(BAND_ORDER):
            out[b] = round(float(r[q_band == bi].mean()), 4)
        return out

    configs = {
        "int8-256": int8_256_rows,
        "int8-512": int8_512_rows,
        "hamming200->int8-256": ham256_rows,
        "hamming200->int8-512": ham512_rows,
    }
    recalls = {name: recall(rows) for name, rows in configs.items()}

    # neighbor structure at shipping config and float truth
    def structure(rows_mat):
        top1 = rows_mat[:, 0]
        sv1 = row_vol[top1] == row_vol[qrows]
        sb1 = row_band[top1] == q_band
        sv10 = row_vol[rows_mat] == row_vol[qrows][:, None]
        sb10 = row_band[rows_mat] == q_band[:, None]
        out = {"overall": {
            "same_volume_top1": round(float(sv1.mean()), 4),
            "same_volume_top10": round(float(sv10.mean()), 4),
            "same_band_top1": round(float(sb1.mean()), 4),
            "same_band_top10": round(float(sb10.mean()), 4),
        }}
        for bi, b in enumerate(BAND_ORDER):
            m = q_band == bi
            out[b] = {
                "same_volume_top1": round(float(sv1[m].mean()), 4),
                "same_volume_top10": round(float(sv10[m].mean()), 4),
                "same_band_top1": round(float(sb1[m].mean()), 4),
                "same_band_top10": round(float(sb10[m].mean()), 4),
            }
        return out

    struct_float = structure(truth_rows)
    struct_ship = structure(ham256_rows)

    # top-1 cosine distributions
    t1cos = truth_cos[:, 0].astype(np.float64)
    ship_top1 = ham256_rows[:, 0]
    ship_t1cos = np.einsum("ij,ij->i", F[qrows], F[ship_top1]).astype(np.float64)

    def dist_stats(x):
        return {"min": round(float(x.min()), 4),
                "p25": round(float(np.percentile(x, 25)), 4),
                "median": round(float(np.percentile(x, 50)), 4),
                "p75": round(float(np.percentile(x, 75)), 4),
                "max": round(float(x.max()), 4)}

    def per_band_stats(x):
        out = {"overall": dist_stats(x)}
        for bi, b in enumerate(BAND_ORDER):
            out[b] = dist_stats(x[q_band == bi])
        return out

    cos_stats_float = per_band_stats(t1cos)
    cos_stats_ship = per_band_stats(ship_t1cos)

    # near-duplicate contamination
    def dup_share(thresh):
        out = {"overall": round(float((t1cos > thresh).mean()), 4)}
        for bi, b in enumerate(BAND_ORDER):
            out[b] = round(float((t1cos[q_band == bi] > thresh).mean()), 4)
        return out

    dup_098 = dup_share(0.98)
    dup_0995 = dup_share(0.995)

    # 30 highest-cosine (query, top1) pairs
    order = np.lexsort((qrows, -t1cos))
    pairs_path = os.path.join(ASSESS, "neighbors_top_pairs.jsonl")
    with open(pairs_path, "w") as fh:
        for i in order[:30]:
            nrow = int(truth_rows[i, 0])
            qi = int(qrows[i])
            fh.write(json.dumps({
                "cosine": round(float(t1cos[i]), 6),
                "band": BAND_ORDER[q_band[i]],
                "query": {"volume": vols[qi], "docId": dids[qi], "chars": int(chars[qi])},
                "top1": {"volume": vols[nrow], "docId": dids[nrow], "chars": int(chars[nrow])},
                "same_volume": bool(row_vol[qi] == row_vol[nrow]),
            }, sort_keys=True) + "\n")

    results = {
        "task": "corpus-scale nearest-neighbor structure + quantization ladder",
        "seed": SEED,
        "top_k": TOP_K,
        "rerank_pool": RERANK_POOL,
        "char_floor": CHAR_FLOOR,
        "corpus_docs": n,
        "procedures": {
            "truth": "float32 GEMM doc_f32_768 @ doc_f32_768.T (gate_b's sims), "
                     "top-10 via lexsort tie-break (score desc, row asc), self excluded",
            "int8": "exact integer dots (f32 GEMM, |dot|<2^24) cast to float64 x "
                    "scale outer product == spike_gates int8_scores bit-for-bit",
            "hamming": "XOR + np.bitwise_count over packed 256-bit sign vectors; "
                       "top-200 tie-break (dist asc, row asc); rerank lexsort((cands,-scores))",
            "sampling": "random.Random(18610810).sample over sorted eligible rows per band, "
                        "band order pre1900,1900_1945,post1945; chars >= 200 floor",
        },
        "bands": {
            "volume_counts": band_volume_counts,
            "doc_counts": band_doc_counts,
            "docs_below_char_floor": band_below_floor,
            "docs_below_char_floor_total": int(sum(band_below_floor.values())),
        },
        "queries": {
            "total": Q,
            "per_band": {b: int((q_band == bi).sum()) for bi, b in enumerate(BAND_ORDER)},
        },
        "recall_at_10_vs_float768": recalls,
        "neighbor_structure": {
            "float768": struct_float,
            "shipping_hamming200_int8_256": struct_ship,
        },
        "top1_cosine_float768": cos_stats_float,
        "top1_float_cosine_of_shipping_top1": cos_stats_ship,
        "near_duplicate_share_top1_cosine": {
            "gt_0.98": dup_098,
            "gt_0.995": dup_0995,
        },
        "top_pairs_file": pairs_path,
        "elapsed_secs": round(time.time() - t0, 1),
        "peak_rss_gb": round(rss_gb(), 2),
    }
    out_path = os.path.join(ASSESS, "neighbors.json")
    json.dump(results, open(out_path, "w"), indent=2, sort_keys=True)
    log("wrote %s" % out_path)
    log("DONE elapsed=%.1fs peak_rss=%.2fGB" % (time.time() - t0, rss_gb()))


if __name__ == "__main__":
    main()
