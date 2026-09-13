#!/usr/bin/env python3
"""Role 5 sizing (read-only, stdlib): how many chapters a per-chapter / per-volume correspondents guide would cover.
Two populations, reported SEPARATELY and never combined in one figure:
  APP VIEW  - live index (index version 50) volume_structures + document_cache, restricted to the 267 scope volume ids:
              sections that directly list >=1 document id; header + dateline characters per section.
  TEI RULE  - ~/frus-ner-raw marked layer: distinct from/to surface keys (grains.surface_key) per volume and per
              document; section membership is NOT joined to it (the two populations differ).
Writes synthesis-size.json beside this file."""
import os, sys, json, sqlite3, collections
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, REPO + "/tools/semantic-harvest")
sys.path.insert(0, REPO + "/Planning/early-era-people/feasibility-2026-09-12/measure-grains")
import grains as G
import ner_store as st
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
vols = st.scope_volumes(os.path.expanduser("~/frus-ner-raw"))
VS = set(vols)
con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
hdr = {}
for v, d, h, dl in con.execute("select volume_id, document_id, length(header), coalesce(length(dateline),0) from document_cache"):
    if v in VS: hdr[(v, d)] = h + dl
q = lambda xs, p: sorted(xs)[min(len(xs) - 1, int(p * len(xs)))] if xs else None
sec_docs, sec_chars, per_vol_secs = [], [], collections.Counter()
band_secs = collections.Counter(); band_docs = collections.Counter(); band_chars = collections.Counter()
missing_struct = []
for v in vols:
    r = con.execute("select structure_json from volume_structures where volume_id=?", (v,)).fetchone()
    if not r: missing_struct.append(v); continue
    def walk(nodes):
        for n in nodes:
            ids = [i for i in n.get("documentIds", []) if (v, i) in hdr]
            if ids:
                sec_docs.append(len(ids)); c = sum(hdr[(v, i)] for i in ids); sec_chars.append(c)
                per_vol_secs[v] += 1; b = st.band_of(v); band_secs[b] += 1; band_docs[b] += len(ids); band_chars[b] += c
            walk(n.get("subsections", []))
    walk(json.loads(r[0]).get("sections", []))
app = {"volumes": len(vols) - len(missing_struct), "volumes_without_structure": missing_struct,
       "documents_in_document_cache_for_scope_ids": len(hdr),
       "sections_listing_documents": len(sec_docs), "documents_under_sections": sum(sec_docs),
       "docs_per_section": {"p50": q(sec_docs, .5), "p90": q(sec_docs, .9), "max": max(sec_docs)},
       "header_plus_dateline_chars_total": sum(sec_chars),
       "header_plus_dateline_chars_per_section": {"p50": q(sec_chars, .5), "p90": q(sec_chars, .9), "max": max(sec_chars)},
       "sections_per_volume": {"p50": q(list(per_vol_secs.values()), .5), "max": max(per_vol_secs.values())},
       "by_band": {b: {"sections": band_secs[b], "documents": band_docs[b], "header_dateline_chars": band_chars[b]} for b in band_secs}}
tei = {"volumes": 0, "fromto_rows": 0, "distinct_fromto_keys_per_volume_sum": 0, "by_band": {}}
for v in vols:
    keys = set(); rows = 0
    for x in st.volume_layer(os.path.expanduser("~/frus-ner-raw"), "marked", v):
        if x.get("t") in ("from", "to"):
            rows += 1; keys.add(G.surface_key(x["n"]))
    b = st.band_of(v); B = tei["by_band"].setdefault(b, {"volumes": 0, "fromto_rows": 0, "distinct_fromto_keys_per_volume_sum": 0})
    tei["volumes"] += 1; tei["fromto_rows"] += rows; tei["distinct_fromto_keys_per_volume_sum"] += len(keys)
    B["volumes"] += 1; B["fromto_rows"] += rows; B["distinct_fromto_keys_per_volume_sum"] += len(keys)
out = {"method": __doc__, "app_view": app, "tei_rule": tei}
json.dump(out, open(os.path.join(HERE, "synthesis-size.json"), "w"), indent=1)
print(json.dumps(out, indent=1)[:4000])
