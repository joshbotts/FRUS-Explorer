#!/usr/bin/env python3
"""INFERRED ceilings for a perfect adjudicator over candidate pools, on the 64-document M2a gold, using the
scorer's own match() (via grains.py, which sets GROUND_TRUTH/STORE/TEXT_DIR before importing score_detections)."""
import os, sys, json, collections
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-grains")
import grains as G
sd = G.sd
gold, bands = sd.load_ground_truth(os.environ["GROUND_TRUTH"])
arms = {}
for name, (path, layer) in G.STORES.items():
    arms[name], refused = sd.collect_predictions(path, layer, gold, True)
    assert not refused, (name, refused)
E, FC, FS, RS, RC = arms["editor"], arms["filtered_control"], arms["filtered_sweep"], arms["raw_sweep"], arms["raw_control"]
pools = {
    "filtered_control": FC, "filtered_sweep": FS,
    "editor+filtered_control": G.union_exact(E, FC),
    "editor+filtered_sweep": G.union_exact(E, FS),
    "editor+filtered_control+filtered_sweep": G.union_exact(E, FC, FS),
    "editor+raw_control+raw_sweep (unfiltered pool, reference)": G.union_exact(E, RC, RS),
}
G_TOTAL = sum(len(v) for v in gold.values())
def f1(p, r): return 2*p*r/(p+r) if p+r else 0.0
res = {}
for name, P in pools.items():
    tot = collections.Counter(); byb = collections.defaultdict(collections.Counter)
    unrec = []
    gk_total = gk_found = gk_overlap = 0
    for key, gs in sorted(gold.items()):
        pr = P.get(key, [])
        strict, relaxed, used_p, used_g = sd.match(gs, pr)
        b = bands[key]
        for c in (tot, byb[b]):
            c["strict"] += strict; c["relaxed"] += relaxed; c["pred"] += len(pr); c["gold"] += len(gs)
        # presence: grains rule on the pool
        gkeys = collections.defaultdict(bool); gover = collections.defaultdict(bool)
        for i, (s, e, n) in enumerate(gs):
            k = G.surface_key(n)
            gkeys[k] |= (i in used_g)
            gover[k] |= any(G.overlaps((s, e), (ps, pe)) for ps, pe, _ in pr)
            if i not in used_g:
                unrec.append({"doc": "%s/%s" % key, "band": b, "n": n, "s": s, "e": e,
                              "overlapped_by": [pn for ps, pe, pn in pr if G.overlaps((s, e), (ps, pe))]})
        gk_total += len(gkeys); gk_found += sum(gkeys.values()); gk_overlap += sum(gover.values())
        for c in (tot, byb[b]):
            c["gk"] += len(gkeys); c["gkf"] += sum(gkeys.values())
    def block(c):
        R = c["relaxed"]/c["gold"]; Rs = c["strict"]/c["gold"]; Pk = c["gkf"]/c["gk"]
        return {"gold": c["gold"], "pool_predictions": c["pred"],
                "unadjudicated_relaxed_P": round(c["relaxed"]/c["pred"], 4) if c["pred"] else None,
                "ceiling_relaxed": {"P": 1.0, "R": round(R, 4), "F1": round(f1(1, R), 4), "hits": c["relaxed"]},
                "ceiling_strict_select_only": {"P": 1.0, "R": round(Rs, 4), "F1": round(f1(1, Rs), 4), "hits": c["strict"]},
                "ceiling_strict_select_and_trim": {"P": 1.0, "R": round(R, 4), "F1": round(f1(1, R), 4)},
                "ceiling_presence": {"P": 1.0, "R": round(Pk, 4), "F1": round(f1(1, Pk), 4), "gold_keys": c["gk"], "found": c["gkf"]}}
    res[name] = {"overall": block(tot), "by_band": {b: block(c) for b, c in sorted(byb.items())},
                 "presence_any_overlap_upper_bound": {"found": gk_overlap, "of": gk_total, "R": round(gk_overlap/gk_total, 4)},
                 "unrecoverable_gold_mentions": unrec}
    o = res[name]["overall"]
    print("%-58s pool=%4d  relaxed R %.3f F1 %.3f | strict-select R %.3f F1 %.3f | presence R %.3f F1 %.3f (any-overlap %d/%d) | unrecoverable %d" % (
        name, o["pool_predictions"], o["ceiling_relaxed"]["R"], o["ceiling_relaxed"]["F1"], o["ceiling_strict_select_only"]["R"], o["ceiling_strict_select_only"]["F1"],
        o["ceiling_presence"]["R"], o["ceiling_presence"]["F1"], gk_overlap, gk_total, len(unrec)))
    for b, bb in res[name]["by_band"].items():
        print("     %-10s gold %3d relaxed R %.3f strict-sel R %.3f presence R %.3f (%d/%d keys)" % (b, bb["gold"], bb["ceiling_relaxed"]["R"], bb["ceiling_strict_select_only"]["R"], bb["ceiling_presence"]["R"], bb["ceiling_presence"]["found"], bb["ceiling_presence"]["gold_keys"]))
    if "control+filtered_sweep" in name or "unfiltered" in name:
        for u in unrec: print("       UNRECOVERABLE", u)
json.dump({"label": "INFERRED ceilings (perfect adjudicator: keeps exactly the pool predictions in a maximum matching -> P=1). POST-HOC, in-sample, 64 docs / %d mentions." % G_TOTAL,
           "pools": res}, open("ceilings.json", "w"), indent=1, ensure_ascii=False)
