#!/usr/bin/env python3
"""Dump the live index's Source Explorer inputs (structure_json; document_cache header/dateline;
document_dates date_iso) for the list-bearing volumes named in census*.json. READ-ONLY (mode=ro)."""
import json, sqlite3, sys
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
vols = [r[0] for f in ("census.json", "census-1926-1950.json") for r in json.load(open(f)) if r[5] > 0]
con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
n = 0
with open("export-list-volumes.jsonl", "w") as f:
    for vid in vols:
        row = con.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?", (vid,)).fetchone()
        docs = [{"d": d, "header": h, "dateline": dl, "date_iso": iso} for d, h, dl, iso in con.execute(
            """SELECT c.document_id, c.header, c.dateline, dd.date_iso FROM document_cache c LEFT JOIN document_dates dd
               ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=?""", (vid,))]
        n += len(docs)
        f.write(json.dumps({"volume": vid, "structure_json": row[0] if row else None, "docs": docs}) + "\n")
        print(vid, len(docs), "structure" if row else "NO STRUCTURE")
print("volumes", len(vols), "docs", n)
