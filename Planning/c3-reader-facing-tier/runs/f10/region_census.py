import sqlite3,re,collections,json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
vols="frus1917-72PubDipv06 frus1917-72PubDipv07 frus1917-72PubDipv08 frus1977-80v30 frus1955-57v09 frus1961-63v25".split()
rx=re.compile(r"\b(East(ern)? Asia\w*|Far East\w*|Asia\w*|Vietnam\w*|Viet-Nam\w*|Japan\w*|Korea\w*|China|Chinese|Philippine\w*|Filipino\w*|Indonesia\w*|Thai\w*|Taiwan\w*|Formosa\w*|Laos|Lao|Laotian|Cambodia\w*|Pacific|Singapore\w*|Malaysia\w*|Malaya\w*|Burma|Burmese|Hong Kong|Okinawa\w*|Southeast Asia\w*)\b")
res={}
out=open(R+"region_docs.tsv","w")
for v in vols:
    n=m=0
    for d,h,dl,sn,b in db.execute("select document_id,header,dateline,source_note,body_text from document_cache where volume_id=? and is_front_matter=0 and is_editorial_note=0 order by document_id",(v,)):
        n+=1
        t=" ".join(((h or '')+" "+(dl or '')+" "+(sn or '')+" "+b).split())
        if rx.search(t): m+=1; out.write("%s\t%s\n"%(v,d))
    res[v]=(m,n); print(v,"%d of %d"%(m,n))
print("total","%d of %d"%(sum(a for a,b in res.values()),sum(b for a,b in res.values())))
