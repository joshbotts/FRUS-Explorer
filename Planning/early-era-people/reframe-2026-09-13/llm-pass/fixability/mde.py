#!/usr/bin/env python3
"""What the 64-doc sample can detect. Simulated 'improved arm' = an existing arm with k of its errors fixed
(FPs removed and/or misses recovered, chosen uniformly at random), paired with the base arm under the SAME
band-stratified document bootstrap design as grains.py (seed 234). Called real = 95% percentile CI lower bound > 0.
This is the HIGH-correlation (best case) scenario: a real Claude arm would differ from the base on more than the
fixed errors, so its paired interval is wider. INFERRED."""
import os, sys, json, random, collections
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-grains")
import grains as G
G.RESAMPLES = 2000
sd = G.sd
gold, bands = sd.load_ground_truth(os.environ["GROUND_TRUTH"])
arms = {n: sd.collect_predictions(p, l, gold, True)[0] for n, (p, l) in G.STORES.items() if n in ("editor", "filtered_control", "filtered_sweep")}
E, FC, FS = arms["editor"], arms["filtered_control"], arms["filtered_sweep"]
cand = {"filtered_sweep": FS, "filtered_control": FC, "editor+filtered_control": G.union_exact(E, FC),
        "editor+filtered_sweep": G.union_exact(E, FS), "editor+intersection_sweep_side": G.union_exact(E, G.intersection(FS, FC)),
        "editor+filtered_control+filtered_sweep": G.union_exact(E, FC, FS)}
keys = sorted(gold); idx = {k: i for i, k in enumerate(keys)}
band_names, by_band, resamples = G.make_resamples(bands, keys)
mults = []
for draw in resamples:
    c = collections.Counter()
    for b in band_names:
        for k in draw[b]: c[idx[k]] += 1
    mults.append(c)
def f1(h, p, g):
    pr = h/p if p else 0; rc = h/g if g else 0
    return 2*pr*rc/(pr+rc) if pr+rc else 0
def pct(v, q):
    v = sorted(v); i = q*(len(v)-1); lo = int(i); hi = min(lo+1, len(v)-1); return v[lo]+(v[hi]-v[lo])*(i-lo)
out = {}
TRIALS = 200
for grain in ("mention_relaxed", "presence"):
    for name, P in cand.items():
        if grain == "mention_relaxed":
            cnt = G.mention_doc_counts(gold, P)
            H = [cnt[k][1] for k in keys]; PR = [cnt[k][2] for k in keys]; GL = [cnt[k][3] for k in keys]
        else:
            cnt = G.presence_doc_counts(gold, P)[0]
            H = [cnt[k][0] for k in keys]; PR = [cnt[k][1] for k in keys]; HG = [cnt[k][2] for k in keys]; GL = [cnt[k][3] for k in keys]
        base = []
        for m in mults:
            if grain == "mention_relaxed":
                h = sum(H[d]*w for d, w in m.items()); p = sum(PR[d]*w for d, w in m.items()); g = sum(GL[d]*w for d, w in m.items())
                base.append((h, p, h, g))
            else:
                base.append((sum(H[d]*w for d, w in m.items()), sum(PR[d]*w for d, w in m.items()), sum(HG[d]*w for d, w in m.items()), sum(GL[d]*w for d, w in m.items())))
        # error pools per doc
        if grain == "mention_relaxed":
            fps = [d for d in range(len(keys)) for _ in range(PR[d]-H[d])]; mis = [d for d in range(len(keys)) for _ in range(GL[d]-H[d])]
        else:
            fps = [d for d in range(len(keys)) for _ in range(PR[d]-H[d])]; mis = [d for d in range(len(keys)) for _ in range(GL[d]-HG[d])]
        tot_h = sum(H); tot_p = sum(PR); tot_hg = sum(H if grain == "mention_relaxed" else HG); tot_g = sum(GL)
        base_f1 = f1(tot_h, tot_p, tot_g) if grain == "mention_relaxed" else (lambda pr, rc: 2*pr*rc/(pr+rc))(tot_h/tot_p, tot_hg/tot_g)
        res = {"base_point_f1": round(base_f1, 4), "fp_instances": len(fps), "miss_instances": len(mis), "scenarios": {}}
        for scen in ("fix_false_positives", "fix_misses", "fix_mixed"):
            pool = fps if scen == "fix_false_positives" else mis if scen == "fix_misses" else [("fp", d) for d in fps] + [("miss", d) for d in mis]
            if scen != "fix_mixed": pool = [("fp" if scen == "fix_false_positives" else "miss", d) for _, d in enumerate(pool)] if False else [(("fp" if scen == "fix_false_positives" else "miss"), d) for d in pool]
            if not pool: continue
            grid = sorted(set([1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 80, 100, 125, 150, 200, 250, 300, 350]) & set(range(1, len(pool)+1)))
            rows = []
            for k in grid:
                rng = random.Random(1000 + k)
                called = 0; pdiffs = []
                for t in range(TRIALS):
                    pick = rng.sample(pool, k)
                    dh = collections.Counter(); dp = collections.Counter(); dhg = collections.Counter()
                    for kind, d in pick:
                        if kind == "fp": dp[d] -= 1
                        else:
                            dh[d] += 1; dp[d] += 1; dhg[d] += 1
                    diffs = []
                    for m, (h, p, hg, g) in zip(mults, base):
                        h2 = h + sum(v*m.get(d, 0) for d, v in dh.items()); p2 = p + sum(v*m.get(d, 0) for d, v in dp.items()); hg2 = hg + sum(v*m.get(d, 0) for d, v in dhg.items())
                        if grain == "mention_relaxed":
                            diffs.append(f1(h2, p2, g) - f1(h, p, g))
                        else:
                            a = (lambda pr, rc: 2*pr*rc/(pr+rc) if pr+rc else 0)(h2/p2 if p2 else 0, hg2/g)
                            b0 = (lambda pr, rc: 2*pr*rc/(pr+rc) if pr+rc else 0)(h/p if p else 0, hg/g)
                            diffs.append(a - b0)
                    if pct(diffs, 0.025) > 0: called += 1
                    th = tot_h + sum(dh.values()); tp = tot_p + sum(dp.values()); thg = tot_hg + sum(dhg.values())
                    pd = (f1(th, tp, tot_g) if grain == "mention_relaxed" else (lambda pr, rc: 2*pr*rc/(pr+rc))(th/tp, thg/tot_g)) - base_f1
                    pdiffs.append(pd)
                rows.append({"k": k, "share_called_real": called/TRIALS, "mean_point_f1_gain": round(sum(pdiffs)/len(pdiffs), 4)})
                if called/TRIALS >= 0.9: break
            first50 = next((r for r in rows if r["share_called_real"] >= 0.5), None)
            first80 = next((r for r in rows if r["share_called_real"] >= 0.8), None)
            res["scenarios"][scen] = {"grid": rows, "k50": first50, "k80": first80}
            print("%-16s %-40s base F1 %.3f FP %4d miss %4d  %-20s k50 %s  k80 %s" % (grain, name, base_f1, len(fps), len(mis), scen, first50, first80))
        out["%s|%s" % (grain, name)] = res
json.dump({"method": __doc__, "resamples": G.RESAMPLES, "trials": TRIALS, "results": out}, open("mde.json", "w"), indent=1)
