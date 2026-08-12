#!/usr/bin/env python3
"""Spot verification of nn_ladder.py outputs.

1. Truth cosines: all finite, within [-1.0001, 1.0001] (settles whether the
   Accelerate matmul RuntimeWarnings were spurious FP-flag noise).
2. For 12 queries (4 per band, deterministic pick), recompute the float truth
   top-10 with the pinned FULL lexsort (np.lexsort((arange(n), -scores))) on a
   float32 GEMM row — verifying select_topk's threshold prefilter is exact.
3. Same 12 queries: recompute int8-256 corpus-wide top-10 the pinned slow way
   (int32 matmul -> * scale outer product, full lexsort) and compare.
4. Same 12 queries: recompute hamming top-200 -> int8-256 rerank the pinned slow
   way (float32 -dist scores, full lexsort; rerank lexsort((cands,-scores))).
"""

import json
import os

import numpy as np

ASSESS = os.path.expanduser(os.environ.get("ASSESS_DIR", "~/frus-semantic-gates"))
POOL = os.path.join(ASSESS, "pool")
WORK = os.path.join(ASSESS, "nn_work")
TOP_K = 10
RERANK_POOL = 200

qz = np.load(os.path.join(WORK, "queries.npz"))
qrows = qz["qrows"]
tz = np.load(os.path.join(WORK, "truth.npz"))
truth_rows, truth_cos = tz["rows"], tz["cos"]

report = {}
report["truth_cos_finite"] = bool(np.isfinite(truth_cos).all())
report["truth_cos_min"] = float(truth_cos.min())
report["truth_cos_max"] = float(truth_cos.max())

F = np.load(os.path.join(POOL, "doc_f32_768.npy"))
n = F.shape[0]
tie_key = np.arange(n)

# pick 12 queries: 4 evenly spaced per band block of 1200
picks = [i for b in range(3) for i in (b * 1200 + 7, b * 1200 + 400, b * 1200 + 801, b * 1200 + 1199)]


def full_lexsort_topk(scores, self_row, k):
    order = np.lexsort((tie_key, -scores))
    return [i for i in order if i != self_row][:k]


mism = {"truth": 0, "int8_256": 0, "ham256": 0}

q256 = np.load(os.path.join(POOL, "doc_int8_256.npy"))
s256 = np.load(os.path.join(POOL, "doc_scale_256.npy"))
bits = np.load(os.path.join(POOL, "doc_bits_256.npy"))
packed64 = np.ascontiguousarray(bits).view(np.uint64)
iz = np.load(os.path.join(WORK, "int8_256.npz"))["rows"]
hz = np.load(os.path.join(WORK, "hamming_reranks.npz"))["r256"]

for p in picks:
    i = int(qrows[p])
    # 1. truth
    sims = (F[i][None, :] @ F.T)[0]
    ref = full_lexsort_topk(sims, i, TOP_K)
    if list(truth_rows[p]) != ref:
        mism["truth"] += 1
    # 2. int8-256 pinned slow path
    dots = q256[i].astype(np.int32)[None, :] @ q256.T.astype(np.int32)
    scores = (dots[0] * s256[i]) * s256          # int32*f32 -> f64, elementwise
    ref = full_lexsort_topk(scores, i, TOP_K)
    if list(iz[p]) != ref:
        mism["int8_256"] += 1
    # 3. hamming -> int8-256 rerank pinned slow path
    xor = packed64[i][None, :] ^ packed64
    dist = np.bitwise_count(xor).sum(axis=1, dtype=np.int32)
    cands = full_lexsort_topk(-dist.astype(np.float32), i, RERANK_POOL)
    cand_scores = (q256[cands].astype(np.int32) @ q256[i].astype(np.int32)
                   ) * s256[cands] * s256[i]
    order = np.lexsort((np.array(cands), -cand_scores))
    ref = [cands[j] for j in order[:TOP_K]]
    if list(hz[p]) != ref:
        mism["ham256"] += 1

report["spot_check_queries"] = len(picks)
report["mismatches"] = mism
print(json.dumps(report, indent=2, sort_keys=True))
with open(os.path.join(ASSESS, "nn_verify.json"), "w") as fh:
    json.dump(report, fh, indent=2, sort_keys=True)
