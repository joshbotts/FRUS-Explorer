import sqlite3,json,sys,time
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
Q={
 "POS_dept_of_state":'"department of state"',
 "NEG_impossible":'ZZZ_IMPOSSIBLE_ZZZ',
 "recogn_near_gov":'NEAR(recogn* government, 6) OR NEAR(recogn* regime, 6) OR NEAR(recogn* junta, 6)',
 "de_facto_gov":'"de facto government"',
 "withhold_recognition":'NEAR(withhold recognition, 4) OR NEAR(withheld recognition, 4) OR NEAR(withholding recognition, 4)',
 "nonrecognition":'nonrecognition OR "non recognition"',
 "provisional_gov":'"provisional government"',
 "revolutionary_gov":'"revolutionary government" OR "revolutionary junta"',
 "military_junta":'"military junta"',
 "coup":'"coup d etat" OR coup OR golpe',
 "free_elections":'"free elections" OR "free election"',
 "tobar":'tobar',
 "estrada_doctrine":'"estrada doctrine"',
 "constitutional_gov":'"constitutional government"',
 "recognition_policy":'"recognition policy" OR "policy of recognition"',
}
sql="SELECT d.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY d.volume_id"
res={}
for k,q in Q.items():
    t=time.time()
    rows=db.execute(sql,(q,)).fetchall()
    res[k]={v:c for v,c in rows}
    print(k, "volumes_hit=",len(rows),"docs=",sum(c for _,c in rows), f"{time.time()-t:.1f}s", flush=True)
json.dump(res,open("scan1_counts.json","w"))
