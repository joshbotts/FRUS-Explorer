from h import *
c=conn()
Q='''(USIS OR USIA OR JUSPAO OR "Information Agency" OR "Information Service" OR "psychological warfare" OR "psychological operations" OR "psychological strategy" OR "information program" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "hearts and minds" OR "cultural program" OR "Asia Foundation" OR "leader grant" OR "information officer" OR "cultural affairs" OR "cultural relations" OR "public diplomacy" OR "information activities")'''
SQLC="SELECT f.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? GROUP BY 1 ORDER BY 2 DESC"
print(SQLC);print(Q)
tot=0
for v,n in c.execute(SQLC,(Q,)).fetchall():
    print(v,n); tot+=n
print('TOTAL',tot)
# G volumes
SQLG="SELECT f.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN G ON G.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? GROUP BY 1"
print(SQLG, c.execute(SQLG,('(Vietnam OR Korea OR Japan OR China OR Indonesia OR Philippines OR Thailand OR Laos OR Cambodia OR Asia OR Asian OR Taiwan OR Burma OR Malaysia OR Singapore)',)).fetchall())
