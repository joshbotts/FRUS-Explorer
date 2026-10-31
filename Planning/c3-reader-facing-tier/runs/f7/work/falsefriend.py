import sqlite3,json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
man=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
yr={v["volumeId"]:int(v["dateRange"]["earliest"][:4]) for v in man}
ont=set(l.strip() for l in open("work/ea_vols_list.txt"))|{'frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30'}
ctrl=set(v for v in yr if yr[v]>=1946 and v not in ont and not v.endswith("Ed2") and "mSupp" not in v)
den={}
for v,n in db.execute("select volume_id,count(*) from document_cache where is_front_matter=0 and is_editorial_note=0 group by 1"): den[v]=n
dOn=sum(den[v] for v in ont if v in den); dC=sum(den[v] for v in ctrl if v in den)
print("ON-TOPIC volumes",len(ont),"docs",dOn,"| CONTROL (post-1945 other volumes, Ed2 and microfiche supplements dropped)",len(ctrl),"docs",dC)
for t in ["ZZZ_IMPOSSIBLE_ZZZ","department of state","soft power","public diplomacy","usis","prestige","image","psychological","propaganda","information program","oriental"]:
    c={}
    for v,n in db.execute("select d.volume_id,count(*) from frus_documents f join document_cache d on d.rowid=f.rowid where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0 group by 1",['"%s"'%t]): c[v]=n
    a=sum(n for v,n in c.items() if v in ont); b=sum(n for v,n in c.items() if v in ctrl)
    print("%-22s on-topic %6d of %d (%.1f per 1000) | control %6d of %d (%.1f per 1000)"%(t,a,dOn,1000*a/dOn,b,dC,1000*b/dC))
