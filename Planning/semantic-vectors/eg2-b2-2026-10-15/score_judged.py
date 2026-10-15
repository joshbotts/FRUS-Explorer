#!/usr/bin/env python3
"""Score two semantic routes' top tens against the owner's judgments (Track B, step B2).

BASE and CAND are harness verdict sheets (query,route,rank,volume,document,header,relevant); their
`semantic` rows are the two top tens. A row's judgment is any 0 or 1 either sheet holds for the same
query and document (a 1 wins a disagreement, which is reported). Unjudged rows bound the figures: the
floor counts them as misses, the ceiling as hits. Run from the repository root.

  BASE  default Planning/semantic-vectors/eval-2026-08-27/verdicts.csv (the 300m, judged 2026-08-27)
  CAND  default Planning/semantic-vectors/eval-eg2-2026-10-15/verdicts.csv (EmbeddingGemma 2)
  OUT   optional JSON path
"""
import csv
import json
import os

BASE = os.environ.get("BASE", "Planning/semantic-vectors/eval-2026-08-27/verdicts.csv")
CAND = os.environ.get("CAND", "Planning/semantic-vectors/eval-eg2-2026-10-15/verdicts.csv")
REGISTERS = {"research": [1, 2, 3, 6, 8, 10, 11, 16, 18],
             "keyword": [5, 7, 9, 12, 13, 19, 20, 21, 22, 23, 24],
             "known_item": [4, 17, 25], "wrong_premise": [15], "null": [14]}


def rows(path):
    with open(path) as fh:
        return list(csv.DictReader(fh))


judged, conflicts = {}, []
for path in (BASE, CAND):
    for r in rows(path):
        if r["relevant"] in ("0", "1"):
            key = (int(r["query"]), r["volume"], r["document"])
            value = int(r["relevant"])
            if key in judged and judged[key] != value:
                conflicts.append(key)
            judged[key] = max(judged.get(key, value), value)


def top(path):
    out = {}
    for r in rows(path):
        if r["route"] == "semantic":
            out.setdefault(int(r["query"]), []).append((r["volume"], r["document"]))
    return out


def score(lists, queries):
    rel = no = unjudged = 0
    rr_floor = rr_ceiling = 0.0
    for q in queries:
        first_floor = first_ceiling = None
        for i, doc in enumerate(lists[q]):
            j = judged.get((q,) + doc)
            rel += j == 1
            no += j == 0
            unjudged += j is None
            if first_floor is None and j == 1:
                first_floor = i + 1
            if first_ceiling is None and j != 0:
                first_ceiling = i + 1
        rr_floor += 1.0 / first_floor if first_floor else 0.0
        rr_ceiling += 1.0 / first_ceiling if first_ceiling else 0.0
    total = rel + no + unjudged
    return {"judged_relevant": rel, "judged_not": no, "unjudged": unjudged,
            "precision_over_judged": round(rel / (rel + no), 3) if rel + no else None,
            "precision_floor": round(rel / total, 3), "precision_ceiling": round((rel + unjudged) / total, 3),
            "mrr_floor": round(rr_floor / len(queries), 3), "mrr_ceiling": round(rr_ceiling / len(queries), 3)}


base, cand = top(BASE), top(CAND)
queries = sorted(base)
assert queries == sorted(cand)
result = {"base": BASE, "cand": CAND, "conflicting_judgments": [list(k) for k in conflicts],
          "overlap_mean": round(sum(len(set(base[q]) & set(cand[q])) for q in queries) / len(queries), 2),
          "overlap_by_query": {q: len(set(base[q]) & set(cand[q])) for q in queries}}
for label, lists in (("base", base), ("cand", cand)):
    result[label + "_scores"] = {"all": score(lists, queries)}
    result[label + "_scores"].update({name: score(lists, qs) for name, qs in REGISTERS.items()})
text = json.dumps(result, indent=2, sort_keys=True)
if os.environ.get("OUT"):
    open(os.environ["OUT"], "w").write(text + "\n")
print(text)
