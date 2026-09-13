#!/usr/bin/env python3
"""Print 20 random documents (12 from 1861-1899, 8 from 1900-1905, by app year) beside the harness's
Source Explorer output, for reading. Seed fixed. stdlib only."""
import json, random, sys
H = sys.argv[1] if len(sys.argv) > 1 else "."
docs = [json.loads(l) for l in open(f"{H}/frus-pre1906-classified.jsonl")]
rng = random.Random(234)
a = [d for d in docs if d["appYear"] and 1861 <= d["appYear"] <= 1899]
b = [d for d in docs if d["appYear"] and 1900 <= d["appYear"] <= 1905]
for d in rng.sample(a, 12) + rng.sample(b, 8):
    print("=" * 100)
    print(f"{d['volume']}/{d['d']}  year={d['appYear']} gate={d['gate']}")
    print(f"  header  : {d['header']}")
    print(f"  dateline: {d['dateline']}")
    print(f"  path    : {d['sectionPath']}")
    print(f"  chosen  : [{d['chosenTitleIndex']}] {d['chosenTitle']}")
    for r in d["shown"]:
        print(f"  SHOWN   : {r['category']} geo={r['geoKeys']} conf={r['confidence']} rolls={r['rollCount']} {r['rollNaIds'][:2]}")
    if not d["shown"]:
        print("  SHOWN   : (nothing)")
        for t in d["classifierByTitle"]:
            print(f"    title {t['title']!r}: " + "; ".join(f"{c['category']} {c['geoKeys']} rolls={c.get('rollCount')}" for c in t["classifications"]))
