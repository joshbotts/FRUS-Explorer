import sqlite3,sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open("eap_core.txt")]
Q='("psychological warfare" OR "psychological strategy" OR USIA OR USIS OR "Voice of America" OR "cultural exchange" OR "information program" OR propaganda OR "Asian opinion" OR "hearts and minds" OR "United States Information")'
POS='"Department of State"'
NEG='ZZZ_IMPOSSIBLE_ZZZ'
sql="""SELECT d.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY d.volume_id"""
tot="SELECT volume_id,COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 GROUP BY volume_id"
T=dict(db.execute(tot).fetchall())
H=dict(db.execute(sql,(Q,)).fetchall())
P=dict(db.execute(sql,(POS,)).fetchall())
N=dict(db.execute(sql,(NEG,)).fetchall())
print("neg control total:",sum(N.values()),"; volumes with 0 positive among core:",[v for v in vols if v in T and P.get(v,0)==0])
rows=[]
for v in vols:
    if v not in T: print("MISSING",v); continue
    rows.append((H.get(v,0)/T[v],v,H.get(v,0),T[v]))
rows.sort(reverse=True)
for r in rows: print("%-20s %5d of %5d  rate %.3f"%(r[1],r[2],r[3],r[0]))
