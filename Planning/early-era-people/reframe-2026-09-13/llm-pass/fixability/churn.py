#!/usr/bin/env python3
"""INFERRED detectability. A simulated adjudicator over the pool editor+filtered_control+filtered_sweep removes each
pool FP with prob r_fp and wrongly removes each pool TP with prob r_tp (independently; a removed TP is not re-matched,
which is conservative). Compared, paired over the same band-stratified document bootstrap (grains.py design, seed 234),
against the best existing unadjudicated arm at each grain (mention relaxed: editor+intersection_sweep_side 0.794 —
tied with editor+filtered_control; presence: editor+intersection_sweep_side 0.828). Reports share of trials where the
95% CI of the difference excludes 0 above ('better') or below ('worse')."""
import os, sys, json, random, collections
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-grains")
import grains as G
G.RESAMPLES = 1000
sd = G.sd
gold, bands = sd.load_ground_truth(os.environ["GROUND_TRUTH"])
A = {n: sd.collect_predictions(p, l, gold, True)[0] for n, (p, l) in G.STORES.items() if n in ("editor", "filtered_control", "filtered_sweep")}
E, FC, FS = A["editor"], A["filtered_control"], A["filtered_sweep"]
POOL = G.union_exact(E, FC, FS)
BEST = G.union_exact(E, G.intersection(FS, FC))
keys = sorted(gold); idx = {k: i for i, k in enumerate(keys)}
band_names, by_band, resamples = G.make_resamples(bands, keys)
M = []
for draw in resamples:
    c = collections.Counter(idx[k] for b in band_names for k in draw[b]); M.append(list(c.items()))
def F(h, p, hg, g):
    pr = h/p if p else 0; rc = hg/g if g else 0
    return 2*pr*rc/(pr+rc) if pr+rc else 0
def pct(v, q):
    v = sorted(v); i = q*(len(v)-1); lo = int(i); hi = min(lo+1, len(v)-1); return v[lo]+(v[hi]-v[lo])*(i-lo)
out = {}
T = 40
for grain in ("mention_relaxed", "presence"):
    if grain == "mention_relaxed":
        pc = G.mention_doc_counts(gold, POOL); bc = G.mention_doc_counts(gold, BEST)
        P4 = [(pc[k][1], pc[k][2], pc[k][1], pc[k][3]) for k in keys]; B4 = [(bc[k][1], bc[k][2], bc[k][1], bc[k][3]) for k in keys]
    else:
        pc = G.presence_doc_counts(gold, POOL)[0]; bc = G.presence_doc_counts(gold, BEST)[0]
        P4 = [pc[k] for k in keys]; B4 = [bc[k] for k in keys]
    base_res = []
    for m in M:
        s = [0, 0, 0, 0]
        for d, w in m:
            for j in range(4): s[j] += B4[d][j]*w
        base_res.append(F(*s))
    bt = [sum(x[j] for x in B4) for j in range(4)]
    best_f1 = F(*bt)
    rows = []
    for r_fp in (0.5, 0.7, 0.8, 0.9, 0.95, 1.0):
        for r_tp in (0.0, 0.02, 0.05, 0.10, 0.20):
            rng = random.Random(int(r_fp*1000)*7 + int(r_tp*1000))
            better = worse = 0; pts = []
            for t in range(T):
                V = []
                for (h, p, hg, g) in P4:
                    fp = p - h
                    hk = sum(1 for _ in range(h) if rng.random() >= r_tp)
                    fk = sum(1 for _ in range(fp) if rng.random() >= r_fp)
                    # a removed true pred removes one found gold unit (approximation at presence grain)
                    V.append((hk, hk + fk, hg - (h - hk), g))
                vt = [sum(x[j] for x in V) for j in range(4)]
                pts.append(F(*vt) - best_f1)
                diffs = []
                for m, b0 in zip(M, base_res):
                    s = [0, 0, 0, 0]
                    for d, w in m:
                        x = V[d]
                        s[0] += x[0]*w; s[1] += x[1]*w; s[2] += x[2]*w; s[3] += x[3]*w
                    diffs.append(F(*s) - b0)
                lo, hi = pct(diffs, 0.025), pct(diffs, 0.975)
                better += lo > 0; worse += hi < 0
            row = {"r_fp": r_fp, "r_tp": r_tp, "mean_point_diff_vs_best": round(sum(pts)/T, 4), "share_called_better": better/T, "share_called_worse": worse/T}
            rows.append(row)
            print("%-16s best %.3f  r_fp %.2f r_tp %.2f  point diff %+.3f  better %.2f worse %.2f" % (grain, best_f1, r_fp, r_tp, row["mean_point_diff_vs_best"], row["share_called_better"], row["share_called_worse"]))
    out[grain] = {"best_existing_arm": "editor+intersection_sweep_side", "best_f1": round(best_f1, 4), "rows": rows}
json.dump({"method": __doc__, "resamples": G.RESAMPLES, "trials": T, "results": out}, open("churn.json", "w"), indent=1)
