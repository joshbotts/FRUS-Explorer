#!/usr/bin/env python3
"""Positive control for agreement.document_regions on three volumes: R-0 length parity and where the
editors' typed from/to marks fall. Writes region-probe.json."""
import json, os, sys, time, collections
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import agreement as A
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import ner_store
out = {}
for v in ["frus1861", "frus1932v04", "frus1946v01"]:
    t0 = time.time()
    xml = open("/Users/jbotts/Development/frus/volumes/%s.xml" % v, encoding="utf-8").read()
    reg = A.document_regions(xml)
    t1 = time.time()
    texts = ner_store.volume_text(os.path.expanduser("~/frus-semantic-raw/text"), v)
    mism = [d for d in texts if d not in reg or reg[d][0] != len(texts[d])]
    extra = [d for d in reg if d not in texts]
    rows = ner_store.volume_layer(os.path.expanduser("~/frus-ner-raw"), "marked", v)
    c = collections.Counter()
    for r in rows:
        c[(r["t"] if r["t"] in ("from", "to") else "untyped", A.region_of(r["s"], reg[r["d"]]))] += 1
    out[v] = {"docs_text_layer": len(texts), "docs_regions": len(reg), "length_mismatch": len(mism),
              "mismatch_first": mism[:5], "regions_not_in_text_layer": len(extra),
              "secs_regions": round(t1 - t0, 2), "marked_by_type_region": {"%s/%s" % k: n for k, n in sorted(c.items())}}
    print(v, json.dumps(out[v]))
json.dump(out, open(os.path.join(HERE, "region-probe.json"), "w"), indent=1)
