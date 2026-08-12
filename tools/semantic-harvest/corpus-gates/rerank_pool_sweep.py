#!/usr/bin/env python3
"""Supplement to nn_ladder.py: price RERANK_POOL alongside rerank width.

The corpus-scale ladder showed the 256-bit hamming top-200 funnel costs 0.021
recall@10 when reranked at int8-256 but 0.047 at int8-512 — the pool becomes the
binding constraint exactly when the rerank tier improves. This sweep measures
hamming top-P -> int8-{256,512} rerank recall@10 vs the SAME float-768 truth and
query sample (checkpointed by nn_ladder.py), for P in {200, 400, 800, 1600}.
All numeric procedures identical to nn_ladder.py (select_topk threshold prefilter
+ lexsort tie band; rerank lexsort((cands, -scores)); np.bitwise_count hamming).
"""

import json
import os
import time

import numpy as np

SEED = 18610810
TOP_K = 10
POOLS = [200, 400, 800, 1600]
BAND_ORDER = ["pre1900", "1900_1945", "post1945"]

ASSESS = os.path.expanduser(os.environ.get("ASSESS_DIR", "~/frus-semantic-gates"))
POOL = os.path.join(ASSESS, "pool")
WORK = os.path.join(ASSESS, "nn_work")
MANIFEST = os.environ.get("MANIFEST", "FRUSExplorer/Resources/manifest.json")


def log(msg):
    print("[%s] %s" % (time.strftime("%H:%M:%S"), msg), flush=True)


def select_topk(scores, self_row, k):
    n = scores.shape[0]
    kth = n - (k + 2)
    thr = np.partition(scores, kth)[kth]
    cand = np.flatnonzero(scores >= thr)
    order = np.lexsort((cand, -scores[cand]))
    sel = cand[order]
    return sel[sel != self_row][:k]


def main():
    t0 = time.time()
    manifest = json.load(open(MANIFEST))
    vol_band = {}
    for e in manifest:
        mid = (int(e["dateRange"]["earliest"][:4]) + int(e["dateRange"]["latest"][:4])) / 2.0
        vol_band[e["volumeId"]] = ("pre1900" if mid < 1900
                                   else ("1900_1945" if mid <= 1945 else "post1945"))
    vols = []
    with open(os.path.join(POOL, "doc_keys.jsonl")) as fh:
        for line in fh:
            vols.append(json.loads(line)["v"])
    row_band = np.array([BAND_ORDER.index(vol_band[v]) for v in vols], dtype=np.int8)

    qrows = np.load(os.path.join(WORK, "queries.npz"))["qrows"]
    truth_rows = np.load(os.path.join(WORK, "truth.npz"))["rows"]
    Q = len(qrows)
    q_band = row_band[qrows]
    log("queries %d, truth loaded" % Q)

    bits = np.load(os.path.join(POOL, "doc_bits_256.npy"))
    packed64 = np.ascontiguousarray(bits).view(np.uint64)
    q256 = np.load(os.path.join(POOL, "doc_int8_256.npy"))
    s256 = np.load(os.path.join(POOL, "doc_scale_256.npy"))
    q512 = np.load(os.path.join(POOL, "doc_int8_512.npy"))
    s512 = np.load(os.path.join(POOL, "doc_scale_512.npy"))

    maxp = max(POOLS)
    out_rows = {(p, d): np.empty((Q, TOP_K), dtype=np.int64) for p in POOLS for d in (256, 512)}
    B = 100
    for s in range(0, Q, B):
        batch = qrows[s:s + B]
        xor = packed64[batch][:, None, :] ^ packed64[None, :, :]
        dist = np.bitwise_count(xor).sum(axis=2, dtype=np.int32)
        del xor
        for j in range(len(batch)):
            i = batch[j]
            cands_max = select_topk(-dist[j].astype(np.float32), i, maxp)
            for p in POOLS:
                carr = np.asarray(cands_max[:p])
                for dims, qm, sm in ((256, q256, s256), (512, q512, s512)):
                    cand_scores = (qm[carr].astype(np.int32) @ qm[i].astype(np.int32)
                                   ) * sm[carr] * sm[i]
                    order = np.lexsort((carr, -cand_scores))
                    out_rows[(p, dims)][s + j] = carr[order[:TOP_K]]
        if (s // B) % 6 == 0:
            log("sweep %d/%d" % (s + len(batch), Q))

    def recall(rows_mat):
        r = np.array([len(set(truth_rows[i]) & set(rows_mat[i])) / TOP_K for i in range(Q)])
        out = {"overall": round(float(r.mean()), 4)}
        for bi, b in enumerate(BAND_ORDER):
            out[b] = round(float(r[q_band == bi].mean()), 4)
        return out

    results = {"seed": SEED, "queries": Q, "top_k": TOP_K,
               "recall_at_10_vs_float768": {
                   "hamming%d->int8-%d" % (p, d): recall(out_rows[(p, d)])
                   for p in POOLS for d in (256, 512)}}
    path = os.path.join(ASSESS, "rerank_pool_sweep.json")
    json.dump(results, open(path, "w"), indent=2, sort_keys=True)
    log("done in %.0fs -> %s" % (time.time() - t0, path))
    print(json.dumps(results["recall_at_10_vs_float768"], indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
