import sqlite3,sys,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
q=sys.argv[1]; n=int(sys.argv[2]) if len(sys.argv)>2 else 15
vols=[l.strip() for l in open(sys.argv[3] if len(sys.argv)>3 else "scope_vols.txt")]
ph=",".join("?"*len(vols))
sql="""SELECT d.volume_id,d.document_id,substr(replace(d.header,char(10),' '),1,130),d.dateline,bm25(frus_documents),snippet(frus_documents,6,'[',']',' ... ',22)
FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY bm25(frus_documents) LIMIT ?"""%ph
tot=db.execute("SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND d.is_front_matter=0 AND d.is_editorial_note=0"%ph,[q]+vols).fetchone()[0]
print("TOTAL",tot,"for",q)
for r in db.execute(sql,[q]+vols+[n]):
    print(r[0],r[1],re.sub(r"\s+"," ",r[2]),"|",(r[3] or "")[:40],"|%.1f"%r[4]);print("    ",re.sub(r"\s+"," ",r[5]))
