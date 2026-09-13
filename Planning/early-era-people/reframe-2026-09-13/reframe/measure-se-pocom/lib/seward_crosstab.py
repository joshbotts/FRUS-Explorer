#!/usr/bin/env python3
"""Seward rows 1861-1869: grain x side x first signature in the document x initials in the row name.
Reuses measure_chapter_rule's head location and arm-B hypothesis; signature = first of
'F. W. SEWARD' / 'WILLIAM H. SEWARD' (or 'W. H. SEWARD') in the R-0 text (the main body precedes
enclosures, so the first signature is the document's own unless the document opens with a copy)."""
import json, gzip, re, os, sys, collections, datetime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_chapter_rule as M, ner_store, measure_pocom as MP
vols = [v for v in ner_store.scope_volumes(M.MARKED) if 1861 <= int(v[4:8]) <= 1869]
H = {}
for line in open(M.HARNESS):
    r = json.loads(line)
    if r["volume"] in vols: H[(r["volume"], r["d"])] = r
SIG = re.compile(r"(F\.\s*W\.\s*SEWARD|FREDERICK W\.\s*SEWARD|WILLIAM H\.\s*SEWARD|W\.\s*H\.\s*SEWARD)")
X = collections.Counter(); ACT = collections.Counter(); EX = collections.defaultdict(list)
for v in vols:
    texts = {json.loads(l)["d"]: json.loads(l)["t"] for l in gzip.open(os.path.join(M.TEXT, v + ".jsonl.gz"), "rt")}
    for x in ner_store.volume_layer(M.MARKED, "marked", v):
        if x["t"] not in ("from", "to") or MP.surname_of(MP.text_of(x["n"])) != "Seward": continue
        r = H.get((v, x["d"]))
        if not r: X["no-harness"] += 1; continue
        date, _ = M.parse_date(r)
        if not date or not (datetime.date(1861, 1, 1) <= date <= datetime.date(1869, 12, 31)): X["out-of-dates"] += 1; continue
        t = texts.get(x["d"], "")
        hn = " ".join((r.get("header") or "").split())
        pos = t.find(hn, 0, 80 + len(hn)) if hn else -1
        grain = "head" if pos >= 0 and x["s"] >= pos and x["e"] <= pos + len(hn) else "enclosure"
        m = SIG.search(t)
        first = "none" if not m else ("F.W." if "F" in m.group(1)[:9] else "W.H.")
        init = "F.W." if re.search(r"\bF\.\s*W\.|Frederick", x["n"]) else ("W.H." if re.search(r"\bW(?:m|illiam)?\.?\s*H\.|William", x["n"]) else "bare")
        acting = bool(re.search(r"F\.\s*W\.\s*SEWARD,?\s*Acting Secretary", t))
        X[(grain, x["t"], "first-sig=" + first, "name=" + init)] += 1
        if grain == "head" and x["t"] == "from":
            ACT["head-from rows"] += 1
            ACT["head-from rows, doc carries 'F. W. SEWARD, Acting Secretary'"] += acting
            if first == "F.W." and init == "bare" and len(EX["bare-name-FW-signed"]) < 10:
                EX["bare-name-FW-signed"].append((v + "/" + x["d"], str(date), " ".join(hn.split()[:14]), t[m.start():m.start() + 40]))
for k, n in sorted(X.items(), key=lambda kv: str(kv[0])): print(k, n)
print(dict(ACT)); print(json.dumps(EX, indent=0))
