import json, sys
import numpy as np
SP = sys.argv[1]
d = json.load(open(f"{SP}/d2/calibration.json"))
def pairs(kind):
    xs, ys = [], []
    if kind == "related":
        # Quantile match: rank-k scores of independent anchor samples (same seeded rows in both pools).
        a = {r["anchor"]: r for r in d["300m"]["related"]}; b = {r["anchor"]: r for r in d["eg2"]["related"]}
        for k in a:
            xs += b[k]["top20"]; ys += a[k]["top20"]
    else:
        for s in kind:
            a = {r["text"]: r for r in d["300m"][s]}; b = {r["text"]: r for r in d["eg2"][s]}
            for t in a:
                xs += b[t]["top10"]; ys += a[t]["top10"]
    return np.array(xs), np.array(ys)
def fit_c0(xs, ys):
    best = None
    for c0 in np.arange(0.20, 0.80, 0.001):
        pred = (xs - c0) / (1 - c0)
        err = np.mean((pred - ys) ** 2)
        if best is None or err < best[1]: best = (c0, err)
    return best
for kind, label in ((("owner", "topical", "null"), "typed, all"), (("owner", "topical"), "typed, on-topic"), (("null",), "typed, null"), ("related", "related doc-doc")):
    xs, ys = pairs(kind)
    c0, err = fit_c0(xs, ys)
    pred = (xs - c0) / (1 - c0)
    # also an unconstrained affine fit for comparison
    A = np.vstack([xs, np.ones_like(xs)]).T; (m, b), *_ = np.linalg.lstsq(A, ys, rcond=None)
    print(f"{label:18s} n={len(xs):5d} c0={c0:.3f} rmse={np.sqrt(err)*100:.1f} pts | median shown raw {np.median(xs)*100:.0f}% -> mapped {np.median(pred)*100:.0f}% vs 300m {np.median(ys)*100:.0f}% | free affine: {m:.3f}x{b:+.3f} (1.0 -> {m+b:.3f})")
# What c0=0.47 shows, per surface
c0 = 0.47
def show(c): return round(max(0, min(1, (c - c0) / (1 - c0))) * 100)
for m in ("300m", "eg2"):
    pass
print()
for s in ("owner", "topical", "null"):
    r1 = [r["top10"][0] for r in d["eg2"][s] if r["text"] != "Space aliens"]
    r10 = [r["top10"][9] for r in d["eg2"][s] if r["text"] != "Space aliens"]
    a1 = [r["top10"][0] for r in d["300m"][s] if r["text"] != "Space aliens"]
    a10 = [r["top10"][9] for r in d["300m"][s] if r["text"] != "Space aliens"]
    print(f"{s:8s} rank1: 300m raw {np.median(a1)*100:.0f}% | EG2 raw {np.median(r1)*100:.0f}% | EG2 at c0=0.47 {show(np.median(r1))}% ;; rank10: 300m {np.median(a10)*100:.0f}% | EG2 raw {np.median(r10)*100:.0f}% | EG2 mapped {show(np.median(r10))}%")
sa3 = [r for r in d["300m"]["owner"] if r["text"] == "Space aliens"][0]; sa2 = [r for r in d["eg2"]["owner"] if r["text"] == "Space aliens"][0]
print(f"Space aliens rank1: 300m {sa3['top10'][0]*100:.0f}% | EG2 raw {sa2['top10'][0]*100:.0f}% | mapped {show(sa2['top10'][0])}%")
rel3 = d["300m"]["related"]; rel2 = d["eg2"]["related"]
for k, lab in ((0, "top1"), (9, "top10"), (19, "top20")):
    print(f"related {lab}: 300m {np.median([r['top20'][k] for r in rel3])*100:.0f}% | EG2 raw {np.median([r['top20'][k] for r in rel2])*100:.0f}% | mapped {show(np.median([r['top20'][k] for r in rel2]))}%")
