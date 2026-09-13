#!/usr/bin/env python3
"""Foreign-legation subchapters nested under a country title: the merged walk stops at the parent, so the legation
rules never run and the label's country is the PARENT's. Counts, per band and arm (S_after shown / T_after), the
documents whose legation name (lib_se.foreign_legation_name, mirror of the app rule, parity-pinned) maps to a
different POCOM territory than the title the arm used. Name->territory mapping is lib_se.terr_of_place (this
program's crosswalk); an unmapped name is counted as 'untestable'. Writes out/legation-nesting.json."""
import os, sys, json, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib_se as S
scope = set(S.scope_volumes(1905))
DA = S.load_docs(S.AFTER, scope)
C = collections.Counter()
X = collections.defaultdict(list)
for (v, d), r in DA.items():
    if S.doc_kind(r) != "foreign-legation":
        continue
    b = S.band_of_volume(v)
    leg_titles = [t for t in r["sectionPath"] if S.foreign_legation_name(t)]
    name = S.foreign_legation_name(leg_titles[-1])
    lt = S.terr_of_place(name) or (S.terr_of_place(S.ADJ.get(name.split()[-1])) if name.split() else None)
    for arm, fn in (("S_after", S.arm_S), ("T_after", S.arm_T)):
        ac = fn(r)
        if ac is None:
            C[(b, arm, "no classification")] += 1
            continue
        used = ac["kind_used"]
        if used != "country":
            C[(b, arm, "used " + str(used))] += 1
            continue
        ut = S.terr_of_key(ac["geo_key"])
        if lt is None or ut is None:
            k = "used parent country; legation name unmapped (untestable)"
        elif set(lt) & set(ut):
            k = "used parent country; SAME country as the legation"
        else:
            k = "used parent country; DIFFERENT country from the legation"
        C[(b, arm, k)] += 1
        if "DIFFERENT" in k and len(X[(b, arm)]) < 10:
            X[(b, arm)].append([v + "/" + d, r["sectionPath"][-2:], (r["header"] or "")[:50], ac["geo_key"], name])
        if "untestable" in k and len(X[(b, arm, "u")]) < 5:
            X[(b, arm, "u")].append([v + "/" + d, r["sectionPath"][-2:], name])
for k, n in sorted(C.items()):
    print(k, n)
for k, v in X.items():
    print("EX", k, v)
json.dump({"counts": {"|".join(k): n for k, n in C.items()}, "examples": {"|".join(map(str, k)): v for k, v in X.items()}},
          open(os.path.join(HERE, "out", "legation-nesting.json"), "w"), indent=1)
