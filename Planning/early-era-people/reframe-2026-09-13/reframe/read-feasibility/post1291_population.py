#!/usr/bin/env python3
"""App-view population after #1291 (index v51) is applied: the four volumes that gain persons rows leave the
'no persons rows' set. Read-only over the live index (still v50). Stdlib only."""
import json, os, sqlite3
P = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "post1291_population.json")
con = sqlite3.connect("file:" + P + "?mode=ro", uri=True)
docs = dict(con.execute("SELECT volume_id, COUNT(*) FROM document_revisions GROUP BY volume_id").fetchall())
with_persons = {r[0] for r in con.execute("SELECT DISTINCT volume_id FROM persons")}
no_list = sorted(v for v in docs if v not in with_persons)
leaving = ["frus1873p1v2", "frus1932v04", "frus1918Supp01v02", "frus1917Supp02v02"]
out = {"app_view_v50": {"volumes": len(no_list), "documents": sum(docs[v] for v in no_list)},
       "leaving_at_v51": {v: docs.get(v) for v in leaving},
       "app_view_after_v51_inferred": {"volumes": len([v for v in no_list if v not in leaving]),
                                       "documents": sum(docs[v] for v in no_list if v not in leaving)}}
json.dump(out, open(OUT, "w"), indent=1); print(json.dumps(out, indent=1))
