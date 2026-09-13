#!/usr/bin/env python3
"""Marked from/to rows whose surname_of() is Seward, 1861-1869 volumes: how often the SURFACE itself
distinguishes F. W. from W. H. (read-only)."""
import re, sys, json, collections
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, REPO + "/tools/semantic-harvest"); import ner_store
import os
MARKED = os.path.expanduser("~/frus-ner-raw")
c = collections.Counter(); ex = collections.Counter()
for vol in ner_store.scope_volumes(MARKED):
    m = re.match(r"frus(\d{4})", vol)
    if not m or not (1861 <= int(m.group(1)) <= 1869): continue
    for r in ner_store.volume_layer(MARKED, "marked", vol):
        if r["t"] not in ("from", "to"): continue
        n = " ".join(r["n"].split())
        if not re.search(r"\bSeward\b", n): continue
        c["rows"] += 1
        if re.search(r"F\.\s*W\.|Frederick", n): c["surface_FW"] += 1; ex[n] += 1
        elif re.search(r"W(m|illiam)?\.?\s*H\.|William H", n): c["surface_WH"] += 1; ex[n] += 1
        else: c["surname_only_or_title"] += 1
        c["role_" + r["t"]] += 1
out = {"counts": dict(c), "distinguishing_surfaces": ex.most_common(10)}
json.dump(out, open("seward.json", "w"), indent=1); print(json.dumps(out, indent=1))
