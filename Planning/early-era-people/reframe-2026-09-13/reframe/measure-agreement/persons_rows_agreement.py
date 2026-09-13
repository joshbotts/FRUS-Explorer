#!/usr/bin/env python3
"""Persons-row grain for the agreement arm under read-cost/persons_rows.py's OWN key
(' '.join(n.split()).lower(), distinct per volume, summed; pre-1910 by manifest dateRange.earliest).
Controls: marked == 30,327 / 12,654 and marked ∪ filtered control == 340,614 / 146,301 (persons-rows-output.json).
Writes persons-rows-agreement.json."""
import collections, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import agreement as A
import census_orig_copy as census
ner_store = census.ner_store
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
H = os.path.expanduser
man = {v["volumeId"]: int(v["dateRange"]["earliest"][:4]) for v in json.load(open(REPO + "/FRUSExplorer/Resources/manifest.json"))}
def norm(n): return " ".join(n.split()).lower()
vols = ner_store.scope_volumes(H("~/frus-ner-raw"))
acc = {k: collections.Counter() for k in ("marked", "union_marked_filtered_control", "agreement", "intersection_sweep_side")}
corpus = {k: set() for k in acc}
for v in vols:
    by = {}
    for name, store, layer in (("E", "~/frus-ner-raw", "marked"), ("FC", "~/frus-ner-raw-control-filtered", "detected"), ("FS", "~/frus-ner-raw-filtered", "detected")):
        g = collections.defaultdict(list)
        for r in ner_store.volume_layer(H(store), layer, v):
            g[r["d"]].append((r["s"], r["e"], r["n"]))
        by[name] = g
    s = {k: set() for k in acc}
    for d in set(by["E"]) | set(by["FC"]) | set(by["FS"]):
        e, fc, fs = by["E"].get(d, []), by["FC"].get(d, []), by["FS"].get(d, [])
        int_fs = A.split_detectors(fc, fs)[0]
        s["marked"] |= {norm(x[2]) for x in e}
        s["union_marked_filtered_control"] |= {norm(x[2]) for x in e} | {norm(x[2]) for x in fc}
        s["agreement"] |= {norm(x[2]) for x in e} | {norm(x[2]) for x in int_fs}
        s["intersection_sweep_side"] |= {norm(x[2]) for x in int_fs}
    for k in acc:
        acc[k]["persons_rows_sum_per_volume_distinct"] += len(s[k])
        acc[k]["name_bytes_sum"] += sum(len(x) for x in s[k])
        if man[v] < 1910:
            acc[k]["pre1910"] += len(s[k])
        corpus[k] |= s[k]
out = {k: dict(acc[k], corpus_distinct_strings=len(corpus[k])) for k in acc}
exp = json.load(open(REPO + "/Planning/early-era-people/feasibility-2026-09-12/read-cost/persons-rows-output.json"))
out["controls"] = {"marked": [exp["marked"]["persons_rows_sum_per_volume_distinct"], exp["marked"]["pre1910"], exp["marked"]["corpus_distinct_strings"]],
                   "union": [exp["union"]["persons_rows_sum_per_volume_distinct"], exp["union"]["pre1910"], exp["union"]["corpus_distinct_strings"]]}
out["controls_ok"] = (out["controls"]["marked"] == [out["marked"]["persons_rows_sum_per_volume_distinct"], out["marked"]["pre1910"], out["marked"]["corpus_distinct_strings"]]
                      and out["controls"]["union"] == [out["union_marked_filtered_control"]["persons_rows_sum_per_volume_distinct"], out["union_marked_filtered_control"]["pre1910"], out["union_marked_filtered_control"]["corpus_distinct_strings"]])
json.dump(out, open(os.path.join(HERE, "persons-rows-agreement.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
