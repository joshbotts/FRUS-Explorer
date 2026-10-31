import sqlite3,sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open("work/ea_vols_list.txt")]+['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1955-57v09','frus1961-63v25','frus1952-54v02p2']
ph=",".join("?"*len(vols))
q=sys.argv[1]; lim=int(sys.argv[2]) if len(sys.argv)>2 else 60
sql=f"""SELECT d.volume_id||'/'||d.document_id, substr(COALESCE(dd.date_iso,''),1,10), replace(substr(d.header,1,150),char(10),' '), length(d.body_text), round(bm25(frus_documents),1)
FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE frus_documents MATCH ? AND d.volume_id IN ({ph}) AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY bm25(frus_documents) LIMIT {lim}"""
for r in db.execute(sql,[q]+vols): print(" | ".join(map(str,r)))
