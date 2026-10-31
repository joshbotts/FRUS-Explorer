import sqlite3,time,json,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
eap=open(R+"eap_vols.txt").read().split(",")
info="frus1917-72PubDipv06 frus1917-72PubDipv07 frus1917-72PubDipv08 frus1977-80v30 frus1955-57v09 frus1961-63v25".split()
scope=eap+info
den=dict(db.execute("select volume_id,count(*) from document_cache where is_front_matter=0 and is_editorial_note=0 group by 1"))
Q={"POS":'"Department of State"',"NEG":'ZZZ_IMPOSSIBLE_ZZZ',"FAMILY_A":'"United States Information Agency" OR "United States Information Service" OR USIA OR USIS',"propaganda":'propaganda',"prestige":'prestige'}
out={}
for k,m in Q.items():
    t=time.time()
    rows=db.execute("select f.volume_id,count(*) from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0 group by 1",(m,)).fetchall()
    out[k]=dict(rows); print(k,"vols with hit",len(rows),"total",sum(r[1] for r in rows),round(time.time()-t,1),"s",flush=True)
json.dump({"den":den,"hits":out,"scope":scope},open(R+"scan1.json","w"))
sc=set(scope)
print("scope vols",len(sc),"all vols",len(den))
print("POS: scope vols with zero hits:",[v for v in scope if out["POS"].get(v,0)==0])
print("NEG total in scope:",sum(out["NEG"].get(v,0) for v in scope))
dS=sum(den.get(v,0) for v in sc); dO=sum(n for v,n in den.items() if v not in sc)
for k in ["FAMILY_A","propaganda","prestige"]:
    hs=sum(out[k].get(v,0) for v in sc); ho=sum(n for v,n in out[k].items() if v not in sc)
    print(k,"scope",hs,"of",dS,round(1000*hs/dS,1),"per1000 | rest-of-corpus",ho,"of",dO,round(1000*ho/dO,1),"per1000")
