#!/usr/bin/env python3
"""Every chapter title (leaf of the section path) of an in-scope document whose classifier output
needs a country but whose path has no title the crosswalk maps to a POCOM territory (arm B)."""
import json, collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_chapter_rule as M, ner_store
scope = [v for v in ner_store.scope_volumes(M.MARKED) if int(v[4:8]) <= 1905]
leaf = collections.defaultdict(collections.Counter); nonpath = collections.Counter()
for line in open(M.HARNESS):
    r = json.loads(line)
    if r["volume"] not in scope:
        continue
    c = M.arm_b(r)
    if c and not c["terr"] and any(k["category"] in M.GEO_CATS for k in c["classifications"]):
        b = M.band(r["volume"])
        leaf[b][(r["volume"], " / ".join(r["sectionPath"][-2:]))] += 1
with open("unmapped-chapter-titles.tsv", "w") as f:
    f.write("band\tvolume\tlast_two_path_titles\tdocs\n")
    for b in sorted(leaf):
        for (v, t), n in sorted(leaf[b].items(), key=lambda kv: (-kv[1], kv[0])):
            f.write(f"{b}\t{v}\t{t}\t{n}\n")
for b in sorted(leaf):
    print(b, "distinct (volume,title)", len(leaf[b]), "docs", sum(leaf[b].values()))
