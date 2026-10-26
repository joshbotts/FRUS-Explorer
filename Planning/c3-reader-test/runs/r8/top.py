# usage: top.py VOL dA dB 'FTS QUERY' N [prefix] -> top-N documents in id range by bm25 for the query
import sqlite3,sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vol,a,b,q,n=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),sys.argv[4],int(sys.argv[5]); pre=sys.argv[6] if len(sys.argv)>6 else "d"
sql="""SELECT d.document_id, dd.date_iso, length(d.body_text), bm25(frus_documents) AS s, d.header FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE frus_documents MATCH ? AND d.volume_id=? AND d.is_front_matter=0 AND d.is_editorial_note=0"""
rows=[r for r in db.execute(sql,(q,vol)).fetchall() if r[0].startswith(pre) and r[0][len(pre):].isdigit() and a<=int(r[0][len(pre):])<=b]
rows.sort(key=lambda r:r[3])
print(f"# {vol} {pre}{a}-{pre}{b} MATCH {q!r}: {len(rows)} hits in range")
for r in rows[:n]: print(vol,r[0],r[1],r[2],f"{r[3]:.1f}"," ".join((r[4] or "").split())[:100],sep="\t")
