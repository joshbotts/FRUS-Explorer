import sqlite3,re,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
vols=open(R+"eap_vols.txt").read().split(",")+"frus1917-72PubDipv06 frus1917-72PubDipv07 frus1917-72PubDipv08 frus1977-80v30 frus1955-57v09 frus1961-63v25".split()
ph=",".join("?"*len(vols))
tol=re.compile(r"(U\.?\s?S\.?|United\s+States)[\s-]+Information[\s,.-]+(Agenc|Servic)\w*|USIA|USIS|U\.S\.I\.[AS]\.",re.I)
rows=db.execute(f"select f.volume_id,f.document_id,d.header,d.dateline,d.source_note,d.body_text,dd.date_iso from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id left join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0 and f.volume_id in ({ph}) order by f.volume_id,f.document_id",['"United States Information Agency" OR "United States Information Service" OR USIA OR USIS']+vols)
out=open(R+"famA_literal.tsv","w"); n=0;fts=0
dec=collections.Counter(); byvol=collections.defaultdict(collections.Counter)
for v,d,h,dl,sn,b,di in rows:
    fts+=1
    t=" ".join(((h or '')+" "+(dl or '')+" "+(sn or '')+" "+b).split())
    if tol.search(t):
        n+=1; de=(di or "none")[:3]+"0s" if di else "none"; dec[de]+=1; byvol[de][v]+=1
        out.write("%s\t%s\t%s\n"%(v,d,di))
print("FTS hits",fts,"literal-confirmed",n)
den=collections.Counter()
for de,c in db.execute(f"select substr(dd.date_iso,1,3)||'0s',count(*) from document_cache d join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where d.is_front_matter=0 and d.is_editorial_note=0 and d.volume_id in ({ph}) group by 1",vols): den[de]=c
for de in sorted(dec):
    tv=byvol[de].most_common(1)[0]
    print(de,"%d of %d"%(dec[de],den[de]),round(1000*dec[de]/den[de],1),"per1000; top volume",tv[0],"%d of %d (%.0f%%)"%(tv[1],dec[de],100*tv[1]/dec[de]))
