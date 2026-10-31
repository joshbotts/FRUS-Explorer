import sqlite3,sys,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=open("/Users/jbotts/frus-analysis/c3f/runs/f10/eap_vols.txt").read().split(",")
ph=",".join("?"*len(vols))
match=sys.argv[1]
open("/Users/jbotts/frus-analysis/c3f/runs/f10/queries.log","a").write("python3 census.py %r  # per-decade count of EAP(99 vols) non-apparatus docs matching FTS; decade by document_dates.date_iso\n"%match)
den=collections.Counter(); 
for (dec,n) in db.execute(f"select substr(dd.date_iso,1,3)||'0s',count(*) from document_cache d join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where d.is_front_matter=0 and d.is_editorial_note=0 and d.volume_id in ({ph}) group by 1",vols): den[dec]=n
rows=db.execute(f"""select substr(dd.date_iso,1,3)||'0s',f.volume_id,count(*) from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id
 join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id
 where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0 and f.volume_id in ({ph}) group by 1,2""",[match]+vols).fetchall()
by=collections.defaultdict(collections.Counter)
for dec,v,n in rows: by[dec][v]+=n
print("decade  hits/dated_nonapparatus_EAP  per1000  top_volume(share)")
for dec in sorted(den,key=lambda x:str(x)):
    h=sum(by[dec].values()); 
    if h==0 and den[dec]<50: continue
    tv=by[dec].most_common(1)
    print(dec,f"{h} of {den[dec]}",round(1000*h/den[dec],1),(tv[0][0],tv[0][1]) if tv else "")
print("total hits",sum(sum(c.values()) for c in by.values()))
