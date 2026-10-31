from h import *
c=conn()
Q='''(USIS OR USIA OR JUSPAO OR "Information Agency" OR "Information Service" OR "psychological warfare" OR "psychological operations" OR "psychological strategy" OR "information program" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "hearts and minds" OR "cultural program" OR "Asia Foundation" OR "leader grant" OR "information officer" OR "cultural affairs" OR "cultural relations" OR "public diplomacy" OR "information activities" OR "propaganda")'''
SQL="SELECT f.volume_id, f.document_id, bm25(frus_documents) s, substr(replace(d.header,char(10),' '),1,110), d.dateline FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? ORDER BY s LIMIT 200"
print(SQL); print(Q)
rows=c.execute(SQL,(Q,)).fetchall()
for r in rows: print(r[0],r[1],round(r[2],1),'|',r[3],'|',(r[4] or '')[:60])
SQLC="SELECT COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ?"
print(SQLC, c.execute(SQLC,(Q,)).fetchone())
