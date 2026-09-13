#!/usr/bin/env python3
"""Share of 1861-1899 pre-1906 documents with a Source Explorer suggestion, under three denominators,
to reconcile with the 76.9% / 85.9% figure quoted in the task context. Read-only. Stdlib only."""
import json, os
G = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/geo-fix"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "se_denominator.json")
res = {}
for label in ("before", "after"):
    c = {"all": [0, 0], "gate_ok": [0, 0], "gate_ok_not_front_not_editorial": [0, 0]}
    gates = {}
    for line in open(os.path.join(G, label + "-docs.jsonl"), encoding="utf-8"):
        r = json.loads(line); y = r.get("appYear")
        if y is None or not (1861 <= y <= 1899): continue
        has = 1 if r.get("shown") else 0
        gates[r.get("gate")] = gates.get(r.get("gate"), 0) + 1
        c["all"][0] += 1; c["all"][1] += has
        if r.get("gate") == "ok":
            c["gate_ok"][0] += 1; c["gate_ok"][1] += has
            if not r.get("front") and not r.get("editorial"):
                c["gate_ok_not_front_not_editorial"][0] += 1; c["gate_ok_not_front_not_editorial"][1] += has
    res[label] = {k: {"docs": v[0], "with": v[1], "share": round(v[1] / v[0], 4) if v[0] else None} for k, v in c.items()}
    res[label]["gates"] = gates
json.dump(res, open(OUT, "w"), indent=1); print(json.dumps(res, indent=1))
