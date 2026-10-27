# usage: python3 dump.py vol/doc [vol/doc ...]  -> raw/<vol>__<doc>.txt ; reading SELECT:
# SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?
import sqlite3, sys
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
for a in sys.argv[1:]:
    v, d = a.split("/")
    r = db.execute("SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if not r: print(a, "MISSING"); continue
    open(f"raw/{v}__{d}.txt", "w").write(f"HEADER: {r[0]}\nDATELINE: {r[1]}\nSOURCE: {r[2]}\nBODY:\n{r[3]}")
    print(a, "len(body_text)=", r[4], "captured=", len(r[3]))
