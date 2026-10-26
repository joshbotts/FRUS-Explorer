# usage: hdr.py VOL dStart dEnd [prefix]  -> header/date/length for documents in range (numeric part)
import sqlite3,sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vol,a,b=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]); pre=sys.argv[4] if len(sys.argv)>4 else "d"
sql="""SELECT d.document_id, dd.date_iso, d.is_editorial_note, length(d.body_text), d.header FROM document_cache d
LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE d.volume_id=? AND d.document_id LIKE ? AND d.is_front_matter=0"""
rows=db.execute(sql,(vol,pre+"%")).fetchall()
rows=[r for r in rows if r[0][len(pre):].isdigit() and a<=int(r[0][len(pre):])<=b]
rows.sort(key=lambda r:int(r[0][len(pre):]))
for r in rows: print(vol,r[0],r[1],"EDNOTE" if r[2] else "",r[3]," ".join((r[4] or "").split())[:110],sep="\t")
