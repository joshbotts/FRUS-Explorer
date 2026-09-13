#!/usr/bin/env python3
"""Size of the filing-role label's main measured failure class, over every shown scope document (live-index export):
despatch labels whose header ADDRESSEE is not the Department (a Secretary/acting Secretary surname or office) --
foreign-government papers and U.S.-minister-to-foreign-office notes printed as their own documents.
The addressee test is THIS PROGRAM'S heuristic (a surname list), not an app rule. Also: the titles behind the
reconciliation's Python-only repairs (earlier arm B 'repaired' where the merged app keys read no country), and the
final S_after label signatures. Writes out/at-risk.json."""
import os, sys, json, re, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib_se as S
import measure_chapter_rule as M

SEC = re.compile(r"\b(?:(?:acting |assistant )?secretary(?: of state)?\b(?! (?:of|for) (?!state))|department of state|department|mr\.? (?:[a-z]\. ?)*(?:seward|fish|evarts|blaine|frelinghuysen|bayard|foster|gresham|olney|sherman|day|hay|root|hunter|adee|wharton|uhl|washburne|davis|porter|rives|hill|loomis|cadwalader|hale|black|trescot|brown|payson|lee|cridler))\b")
scope = set(S.scope_volumes(1905))
DA = S.load_docs(S.AFTER, scope)
DB = S.load_docs(S.BEFORE, scope)
C = collections.Counter()
X = collections.defaultdict(list)
T = collections.Counter()
TX = collections.defaultdict(list)
for (v, d), r in DA.items():
    b = S.band_of_volume(v)
    ac = S.arm_S(r)
    if ac is not None:
        C[(b, "shown docs")] += 1
        snd, adr = S.header_sides(r.get("header"))
        for conf in ("high", "medium"):
            if any(c["category"] == "diplomaticDespatches" and c["confidence"] == conf for c in ac["cands"]):
                k = f"despatch-{conf}"
                C[(b, k)] += 1
                if adr is None:
                    C[(b, k, "no sender/addressee split")] += 1
                elif SEC.search(adr.lower()):
                    C[(b, k, "addressee is a Secretary/Department")] += 1
                else:
                    C[(b, k, "addressee NOT a Secretary/Department")] += 1
                    if len(X[(b, k)]) < 12:
                        X[(b, k)].append([v + "/" + d, (r.get("header") or "")[:80], (r.get("dateline") or "")[:45], ac["chapter"]])
    a0 = M.arm_b(DB[(v, d)])
    at = S.arm_T(r)
    if a0 and a0.get("via") == "repaired" and not (at and at["geo_ok"]):
        T[(b, a0["chapter"])] += 1
        if len(TX[a0["chapter"]]) < 3:
            TX[a0["chapter"]].append(v + "/" + d)
for k, n in sorted(C.items(), key=lambda kv: str(kv[0])):
    print(k, n)
for k, v in X.items():
    print("EX", k, v[:6])
print("Python-only repaired titles (documents where earlier arm B mapped a territory by its own repair and the merged app keys do not):")
for k, n in T.most_common(25):
    print("  ", n, k, TX[k[1]])
o = json.load(open(os.path.join(HERE, "out", "merged-rule.json")))
sigs = {k: v for k, v in o["label_signatures"].items()}
for k in ("S_after|1861-1899", "S_after|1900-1905", "T_after|1861-1899", "S_before|1861-1899"):
    print("SIG", k, sigs.get(k))
json.dump({"counts": {"|".join(map(str, k)): n for k, n in C.items()}, "examples": {"|".join(k): v for k, v in X.items()},
           "python_only_repaired_titles": {"|".join(map(str, k)): n for k, n in T.items()}, "label_signatures": sigs},
          open(os.path.join(HERE, "out", "at-risk.json"), "w"), indent=1)
