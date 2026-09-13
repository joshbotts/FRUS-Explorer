#!/usr/bin/env python3
"""Tie-break sensitivity of the presence grain on the M2a gold (uses v_gold.py's own functions).
Checks the reversed-order matching is still MAXIMUM (same relaxed hits per document), and prints the
gold and predicted spans behind every key whose true/false status flips. Writes v-tiebreak.json."""
import collections, gzip, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import v_gold as vg
gold = collections.defaultdict(list)
for line in open(vg.M2A + "/m2a-ground-truth.jsonl", encoding="utf-8"):
    if line.strip():
        r = json.loads(line); gold[(r["v"], r["d"])].append((r["s"], r["e"], r["n"]))
for x in open(vg.M2A + "/m2a-ground-truth-documents.jsonl", encoding="utf-8"):
    if x.strip():
        r = json.loads(x); gold.setdefault((r["v"], r["d"]), [])
gold = {k: sorted(v) for k, v in gold.items()}
docs = sorted(gold)
arms = {a: {} for a in vg.DIRS}
for vol in sorted({v for v, _ in docs}):
    for a, dp in vg.DIRS.items():
        byd = collections.defaultdict(set)
        for r in vg.read_jsonl(dp, vol):
            byd[r["d"]].add((r["s"], r["e"], r["n"]))
        for v, d in docs:
            if v == vol:
                arms[a][(v, d)] = sorted(byd.get(d, ()))
ov = lambda a, b: min(a[1], b[1]) - max(a[0], b[0]) > 0
agr = {k: sorted(set(arms["E"][k]) | {x for x in arms["FS"][k] if any(ov(x, y) for y in arms["FC"][k])}) for k in docs}
euf = {k: sorted(set(arms["E"][k]) | set(arms["FC"][k])) for k in docs}
out = {"maximum_check": {}, "flips": []}
for name, preds in (("agreement_sweep_side", agr), ("editor_union_fc", euf), ("filtered_control", arms["FC"]), ("filtered_sweep", arms["FS"])):
    bad = [k for k in docs if len(vg.matching(gold[k], preds[k])) != len(vg.matching(gold[k], preds[k], reverse=True))]
    out["maximum_check"][name] = {"documents_where_cardinality_differs": len(bad)}
for k in docs:
    g, p = gold[k], agr[k]
    res = []
    for rev in (False, True):
        m = vg.matching(g, p, rev)
        pk = collections.defaultdict(bool)
        for i, x in enumerate(p):
            pk[vg.gkey(x[2])] |= i in m
        res.append((pk, m))
    flipped = [key for key in res[0][0] if res[0][0][key] != res[1][0][key]]
    if flipped:
        out["flips"].append({"doc": "%s/%s" % k, "flipped_keys": {key: {"forward_true": res[0][0][key], "reversed_true": res[1][0][key]} for key in flipped},
                             "gold_spans_overlapping": sorted({(s, e, n) for s, e, n in g if any(ov((s, e), (ps, pe)) for ps, pe, pn in p if vg.gkey(pn) in flipped)}),
                             "predicted_spans_of_flipped_and_competing": sorted({(ps, pe, pn) for ps, pe, pn in p if any(ov((ps, pe), (s, e)) for s, e, n in g if any(ov((s, e), (qs, qe)) for qs, qe, qn in p if vg.gkey(qn) in flipped))})})
json.dump(out, open(os.path.join(HERE, "v-tiebreak.json"), "w"), indent=1, ensure_ascii=False)
print(json.dumps(out["maximum_check"]))
for f in out["flips"]:
    print(f["doc"], f["flipped_keys"]); print("   gold:", f["gold_spans_overlapping"]); print("   preds:", f["predicted_spans_of_flipped_and_competing"])
