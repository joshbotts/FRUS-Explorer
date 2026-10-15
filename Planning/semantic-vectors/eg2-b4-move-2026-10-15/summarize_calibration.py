import json, sys, math
import numpy as np
SP = sys.argv[1]
d = json.load(open(f"{SP}/d2/calibration.json"))
def q(a, ps=(10, 50, 90)):
    a = np.asarray(a); return " / ".join(f"{np.percentile(a, p):.3f}" for p in ps)
nan = 0
for m in d:
    for s, rows in d[m].items():
        for r in rows:
            vals = r.get("top10") or r.get("top20")
            nan += sum(1 for v in vals if v != v)
print("NaN values:", nan)
for m in ("300m", "eg2"):
    print(f"== {m}")
    for s in ("owner", "topical", "null"):
        rows = d[m][s]
        if s == "owner":
            nulls = [r for r in rows if r["text"] == "Space aliens"]
            rows = [r for r in rows if r["text"] != "Space aliens"]
            for r in nulls: print(f"   owner null 'Space aliens': rank1 {r['top10'][0]:.3f} rank10 {r['top10'][9]:.3f} mean {r['mean']:.3f}")
        r1 = [r["top10"][0] for r in rows]; r10 = [r["top10"][9] for r in rows]
        mean = [r["mean"] for r in rows]; std = [r["std"] for r in rows]
        print(f"   {s:8s} n={len(rows):2d} rank1 p10/50/90 {q(r1)} | rank10 {q(r10)} | corpus mean {q(mean)} | std {np.median(std):.3f} | p99.9 {np.median([r['p999'] for r in rows]):.3f}")
    rel = d[m]["related"]
    t1 = [r["top20"][0] for r in rel]; t10 = [r["top20"][9] for r in rel]; t20 = [r["top20"][19] for r in rel]
    print(f"   related n={len(rel)} top1 p10/50/90 {q(t1)} | top10 {q(t10)} | top20 {q(t20)} | mean {np.median([r['mean'] for r in rel]):.3f}")
# AUC of rank-1: topical(+owner on-topic) vs null(+space aliens)
def auc(pos, neg):
    pos = np.asarray(pos); neg = np.asarray(neg)
    return float(np.mean([(p > n_) + 0.5 * (p == n_) for p in pos for n_ in neg]))
for m in ("300m", "eg2"):
    on = [r["top10"][0] for r in d[m]["owner"] if r["text"] != "Space aliens"] + [r["top10"][0] for r in d[m]["topical"]]
    off = [r["top10"][0] for r in d[m]["null"]] + [r["top10"][0] for r in d[m]["owner"] if r["text"] == "Space aliens"]
    on10 = [r["top10"][9] for r in d[m]["owner"] if r["text"] != "Space aliens"] + [r["top10"][9] for r in d[m]["topical"]]
    off10 = [r["top10"][9] for r in d[m]["null"]] + [r["top10"][9] for r in d[m]["owner"] if r["text"] == "Space aliens"]
    # z-scores against each query's own corpus distribution
    onz = [(r["top10"][0] - r["mean"]) / r["std"] for r in d[m]["owner"] if r["text"] != "Space aliens"] + [(r["top10"][0] - r["mean"]) / r["std"] for r in d[m]["topical"]]
    offz = [(r["top10"][0] - r["mean"]) / r["std"] for r in d[m]["null"]] + [(r["top10"][0] - r["mean"]) / r["std"] for r in d[m]["owner"] if r["text"] == "Space aliens"]
    print(f"{m}: AUC rank1 on vs off {auc(on, off):.3f} (n {len(on)} vs {len(off)}); rank10 {auc(on10, off10):.3f}; z rank1 {auc(onz, offz):.3f}; on rank1 median {np.median(on):.3f} off median {np.median(off):.3f}; max off {max(off):.3f}; on below max off: {sum(1 for x in on if x <= max(off))}")
# paired shift per on-topic query, eg2 - 300m
for s in ("owner", "topical", "null"):
    a = {r["text"]: r for r in d["300m"][s]}; b = {r["text"]: r for r in d["eg2"][s]}
    sh1 = [b[t]["top10"][0] - a[t]["top10"][0] for t in a]; sh10 = [b[t]["top10"][9] - a[t]["top10"][9] for t in a]
    print(f"shift eg2-300m {s}: rank1 p10/50/90 {q(sh1)}; rank10 {q(sh10)}")
