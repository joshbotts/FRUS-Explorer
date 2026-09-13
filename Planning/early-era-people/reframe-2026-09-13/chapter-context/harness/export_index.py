#!/usr/bin/env python3
"""Dump the live index's Source Explorer inputs for every manifest volume whose coverage
starts before 1906. READ-ONLY (sqlite3 uri mode=ro). stdlib only.

Output: one JSON line per volume:
  {"volume", "earliest", "latest", "structure_json" (raw string or null),
   "docs": [{"d","header","dateline","front","editorial","date_iso"}]}
"""
import json, os, sqlite3, sys

REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
OUT = sys.argv[1]

manifest = json.load(open(os.path.join(REPO, "FRUSExplorer/Resources/manifest.json")))
vols = [v for v in manifest if int(v["dateRange"]["earliest"][:4]) < 1906]
con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
n_docs = 0
missing = []
with open(OUT, "w") as f:
    for v in sorted(vols, key=lambda v: v["volumeId"]):
        vid = v["volumeId"]
        row = con.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?", (vid,)).fetchone()
        docs = []
        for d, h, dl, fm, ed, iso in con.execute(
            """SELECT c.document_id, c.header, c.dateline, c.is_front_matter, c.is_editorial_note, dd.date_iso
               FROM document_cache c LEFT JOIN document_dates dd
               ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id
               WHERE c.volume_id=?""", (vid,)):
            docs.append({"d": d, "header": h, "dateline": dl, "front": fm, "editorial": ed, "date_iso": iso})
        if row is None and not docs:
            missing.append(vid)
        n_docs += len(docs)
        f.write(json.dumps({"volume": vid, "earliest": v["dateRange"]["earliest"], "latest": v["dateRange"]["latest"],
                            "structure_json": row[0] if row else None, "docs": docs}) + "\n")
print(json.dumps({"volumes": len(vols), "documents": n_docs, "not_in_index": missing}))
