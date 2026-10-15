"""B4 decision 2: how each model's displayed score (the int8-512 cosine the chip shows) is spread.

Typed queries: the owner's 25 (one a null control), 45 on-topic and 20 off-topic written by the B4
session. Each query is truncated to 512, L2-renormalised, int8-quantised (rint, max|x|/127) as
SemanticQuantization does, and scored against every document's int8-512 row in the pool, as
SemanticShard.cosine does (dot x scale x scale). A full scan, not the Hamming-800 funnel, whose
recall@10 is 0.90 (EG2) and 0.86 (300m), so a rank's score here can sit a hair above the app's.

Related Documents: 600 anchor documents (seeded) scored against every document the same way,
self excluded, for the doc-to-doc chip.
"""
import json, sys
import numpy as np

SP = sys.argv[1]
POOLS = {"300m": "/Users/jbotts/frus-b2/gates-300m/pool", "eg2": "/Users/jbotts/frus-b2/gates-eg2/pool"}
SETS = ["owner", "topical", "null"]
DIMS = 512

def quantize(v):
    v = np.asarray(v, dtype=np.float64)[:DIMS]
    n = np.sqrt(np.sum(v * v))
    v = (v / n).astype(np.float32)
    scale = np.float32(np.max(np.abs(v)) / 127.0)
    codes = np.clip(np.rint(v / scale), -127, 127).astype(np.int8)
    return codes, scale

out = {}
for model, pool in POOLS.items():
    codes = np.load(f"{pool}/doc_int8_{DIMS}.npy", mmap_mode="r")
    scales = np.load(f"{pool}/doc_scale_{DIMS}.npy").astype(np.float64)
    C = np.asarray(codes, dtype=np.float32)  # exact for int8 dot sums < 2^24 per term sum
    keys = [json.loads(l) for l in open(f"{pool}/doc_keys.jsonl")]
    res = {}
    for s in SETS:
        fx = json.load(open(f"{SP}/d2/q-{s}-{model}.json"))
        rows = []
        for q in fx["queries"]:
            qc, qs = quantize(q["vector"])
            dots = C @ qc.astype(np.float32)
            sc = dots.astype(np.float64) * scales * float(qs)
            top = np.argsort(-sc, kind="stable")[:10]
            rows.append({
                "text": q["text"],
                "top10": [round(float(sc[i]), 4) for i in top],
                "top10keys": [f'{keys[i]["v"]}/{keys[i]["d"]}' for i in top],
                "mean": round(float(sc.mean()), 4),
                "std": round(float(sc.std()), 4),
                "p50": round(float(np.median(sc)), 4),
                "p99": round(float(np.percentile(sc, 99)), 4),
                "p999": round(float(np.percentile(sc, 99.9)), 4),
            })
        res[s] = rows
    # Related: doc-to-doc for 600 anchors.
    rng = np.random.default_rng(18610810)
    anchors = np.sort(rng.choice(C.shape[0], size=600, replace=False))
    rel = []
    for start in range(0, len(anchors), 100):
        a = anchors[start:start + 100]
        dots = C[a] @ C.T
        sc = dots.astype(np.float64) * scales[a][:, None] * scales[None, :]
        for j, row in enumerate(a):
            sc[j, row] = -9
            top = np.argsort(-sc[j], kind="stable")[:20]
            rel.append({"anchor": f'{keys[row]["v"]}/{keys[row]["d"]}',
                        "top20": [round(float(sc[j, i]), 4) for i in top],
                        "mean": round(float(sc[j][sc[j] > -9].mean()), 4)})
    res["related"] = rel
    out[model] = res
    print(model, "done", flush=True)

json.dump(out, open(f"{SP}/d2/calibration.json", "w"))
