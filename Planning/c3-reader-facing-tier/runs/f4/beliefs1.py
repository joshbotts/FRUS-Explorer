from h import *
c=conn()
qs=['NEAR(Asians propaganda, 12)','NEAR(Asians psychology, 12)','NEAR("oriental mind", propaganda, 30)','"Asian mind"','"Asiatic mind"','NEAR(oriental psychology, 12)','NEAR(Asian "mentality", 10)','NEAR(Asians "respect", 10)','NEAR(Vietnamese "psychology", 10)','NEAR(Japanese "psychology", 10)','NEAR(Chinese "psychology", 10)','NEAR(Asians "weakness", 8)','NEAR(Asians "strength", 8)','NEAR("Asian" "face", 6)','"loss of face"','"save face"','"saving face"','NEAR("Asians" "impressed", 12)','"Asian peoples"','NEAR("Asians" "propaganda" "United States", 20)']
SQLB="SELECT f.volume_id, f.document_id, substr(replace(d.header,char(10),' '),1,90), d.dateline FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? ORDER BY bm25(frus_documents) LIMIT 8"
SQLC="SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ?"
print(SQLB);print(SQLC)
for q in qs:
    try:
        n=c.execute(SQLC,(q,)).fetchone()[0]
        print('##',q,n)
        for r in c.execute(SQLB,(q,)).fetchall(): print('  ',r[0],r[1],'|',r[2],'|',(r[3] or '')[:40])
    except Exception as e: print('ERR',q,e)
