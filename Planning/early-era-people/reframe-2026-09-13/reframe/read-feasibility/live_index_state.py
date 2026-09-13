#!/usr/bin/env python3
"""Read-only confirmation of the live index state the reframe inherits (index version; the #1291 volumes)."""
import json, os, sqlite3
P = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "live_index_state.json")
con = sqlite3.connect("file:" + P + "?mode=ro", uri=True)
q = lambda sql, *a: con.execute(sql, a).fetchall()
out = {}
cols = [r[1] for r in q("PRAGMA table_info(document_revisions)")]
out["document_revisions_columns"] = cols
vc = next((c for c in cols if "version" in c), None)
if vc: out["index_versions"] = q("SELECT %s, COUNT(*) FROM document_revisions GROUP BY 1" % vc)
out["persons_rows"] = q("SELECT COUNT(*) FROM persons")[0][0]
out["person_mentions_rows"] = q("SELECT COUNT(*) FROM person_mentions")[0][0]
out["persons_rows_in_1291_volumes"] = {v: q("SELECT COUNT(*) FROM persons WHERE volume_id=?", v)[0][0]
    for v in ["frus1873p1v2", "frus1932v04", "frus1918Supp01v02", "frus1917Supp02v02"]}
tabs = [r[0] for r in q("SELECT name FROM sqlite_master WHERE type='table'")]
out["has_person_list_sources"] = "person_list_sources" in tabs
json.dump(out, open(OUT, "w"), indent=1); print(json.dumps(out, indent=1))
