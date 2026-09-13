#!/usr/bin/env python3
"""Source Explorer pre-1906 classifier before/after #1292, 1861-1899 documents.
Read-only over geo-fix/{before,after}-docs.jsonl. Stdlib only. Writes se_shift.json beside itself."""
import json, os
from collections import Counter
G = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/geo-fix"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "se_shift.json")

def band(y):
    if y is None: return "undated"
    return "pre-1861" if y < 1861 else ("1861-1899" if y < 1900 else ("1900-1905" if y < 1906 else "1906+"))

def load(path):
    d = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            r = json.loads(line)
            cats = tuple(sorted({s["category"] for s in r.get("shown") or []}))
            confs = tuple(sorted({s.get("confidence") for s in r.get("shown") or []}))
            rolls = sum(len(s.get("rollNaIds") or []) for s in r.get("shown") or [])
            d[(r["volume"], r["d"])] = (r.get("appYear"), cats, confs, rolls)
    return d

before = load(os.path.join(G, "before-docs.jsonl"))
after = load(os.path.join(G, "after-docs.jsonl"))
out = {"docs_before": len(before), "docs_after": len(after), "bands": {}}
for b in ["1861-1899", "1900-1905"]:
    keys = [k for k, v in after.items() if band(v[0]) == b]
    res = {"documents": len(keys)}
    for label, src in (("before", before), ("after", after)):
        withs = [k for k in keys if k in src and src[k][1]]
        cat_docs = Counter()
        conf_docs = Counter()
        for k in withs:
            for c in src[k][1]: cat_docs[c] += 1
            for c in src[k][2]: conf_docs[str(c)] += 1
        res[label] = {"with_suggestion": len(withs), "share": round(len(withs) / len(keys), 4) if keys else None,
                      "docs_by_category": dict(cat_docs.most_common()), "docs_by_confidence": dict(conf_docs)}
    trans = Counter()
    for k in keys:
        bc = before.get(k, (None, (), (), 0))[1]; ac = after[k][1]
        if not bc and ac: trans["none->some"] += 1
        elif bc and not ac: trans["some->none"] += 1
        elif bc and ac and bc != ac: trans["some->different categories"] += 1
        elif bc and ac: trans["same categories"] += 1
        else: trans["none->none"] += 1
    res["transitions"] = dict(trans)
    foreign = {"notesToForeignMissions", "notesFromForeignMissions"}
    res["after_docs_only_foreign_mission_notes"] = sum(1 for k in keys if after[k][1] and set(after[k][1]) <= foreign)
    res["after_docs_any_foreign_mission_notes"] = sum(1 for k in keys if set(after[k][1]) & foreign)
    out["bands"][b] = res
json.dump(out, open(OUT, "w"), indent=1)
print(json.dumps(out, indent=1))
