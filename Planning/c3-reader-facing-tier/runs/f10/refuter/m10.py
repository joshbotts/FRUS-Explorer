import sqlite3,json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
eap=open(R+"eap_vols.txt").read().strip().split(",")
ph=lambda L: ",".join("?"*len(L))
print("M10 EAP99 totals:",db.execute(f"select count(*),count(distinct volume_id||'/'||document_id) from external_citations where volume_id in ({ph(eap)})",eap).fetchone(),"(memo 13,473 rows in 8,471 documents)")
for r in db.execute(f"select repository,collection,lot_file,count(*) n_rows,count(distinct volume_id||'/'||document_id) n_docs from external_citations where volume_id in ({ph(eap)}) group by 1,2,3 order by n_rows desc limit 12",eap): print("  ",r)
pd=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1977-80v30']
print("M10 4 PubDip totals:",db.execute(f"select count(*),count(distinct volume_id||'/'||document_id) from external_citations where volume_id in ({ph(pd)})",pd).fetchone(),"(memo 116 rows in 85 documents)")
for r in db.execute(f"select repository,collection,lot_file,count(*) n_rows,count(distinct volume_id||'/'||document_id) n_docs from external_citations where volume_id in ({ph(pd)}) group by 1,2,3 order by n_rows desc limit 5",pd): print("  ",r)
pairs=json.load(open(R+"refuter/pairs.json"))['docs']
print("M10 the 30 docs' external_citations rows:")
n=0
for v,d in pairs:
    for r in db.execute("select repository,collection,lot_file,anchor,substr(raw_text,1,90) from external_citations where volume_id=? and document_id=?",(v,d)):
        n+=1; print("  ",v+"/"+d,r)
print("  total rows:",n,"(memo 7)")
print("earliest external_citations volume prefix:",db.execute("select min(substr(volume_id,1,9)) from external_citations").fetchone())
print(".schema external_citations:"); 
for r in db.execute("select sql from sqlite_master where name='external_citations'"): print(r[0])
