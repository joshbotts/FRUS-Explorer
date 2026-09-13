#!/usr/bin/env python3
"""Hunter gap-window rows (out/merged-rule.json hunter_gap_rows) joined to their filing-role labels in out/rows.jsonl.gz.
Asks: does the non-identity label name the Department for Hunter's own head rows, where POCOM identity fails?"""
import json, gzip, collections, os
HERE = os.path.dirname(os.path.abspath(__file__))
o = json.load(open(os.path.join(HERE, "out", "merged-rule.json")))
want = {(h["doc"], h["side"], h["grain"]) for h in o["hunter_gap_rows"]}
C = collections.Counter()
seen = collections.Counter()
for line in gzip.open(os.path.join(HERE, "out", "rows.jsonl.gz"), "rt"):
    r = json.loads(line)
    if r.get("sur") != "Hunter":
        continue
    key = (r["v"] + "/" + r["d"], r["t"], r["grain"])
    if key not in want:
        continue
    seen[key] += 1
    for arm in ("S_before", "S_after", "T_after"):
        lab = r.get(arm + ":label")
        own = None if not lab else lab.split(" -- ")[0]
        C[(arm, r["grain"], r["t"], own)] += 1
for k, v in sorted(C.items(), key=lambda kv: str(kv[0])):
    print(k, v)
print("distinct (doc, side, grain) keys matched:", len(seen), "of", len(want))
json.dump({"|".join(map(str, k)): v for k, v in C.items()}, open(os.path.join(HERE, "out", "hunter-labels.json"), "w"), indent=1)
