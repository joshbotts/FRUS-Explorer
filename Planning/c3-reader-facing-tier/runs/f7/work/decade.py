import sqlite3,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ont=set(l.strip() for l in open("work/ea_vols_list.txt"))|{'frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30'}
ph=",".join("?"*len(ont));L=sorted(ont)
den=collections.Counter()
for (y,n) in db.execute(f"select substr(dd.date_iso,1,3)||'0s',count(*) from document_cache d join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where d.is_front_matter=0 and d.is_editorial_note=0 and d.volume_id in ({ph}) group by 1",L):
    if y: den[y]=n
print("dated non-apparatus docs by decade (on-topic volumes):",dict(sorted(den.items())))
q='"information agency" OR usis OR usia OR "information service" OR "voice of america" OR "information program"'
hit=collections.Counter();byvol=collections.defaultdict(collections.Counter)
for v,y in db.execute(f"select d.volume_id,substr(dd.date_iso,1,3)||'0s' from frus_documents f join document_cache d on d.rowid=f.rowid join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0 and d.volume_id in ({ph})",[q]+L):
    if y: hit[y]+=1;byvol[y][v]+=1
for y in sorted(den):
    h=hit[y];top=byvol[y].most_common(1)
    print("%s hits %4d of %5d dated docs = %.1f per 1000 | top volume %s %s of %d (%.0f%%)"%(y,h,den[y],1000*h/den[y],top[0][0] if top else "-",top[0][1] if top else 0,h,100*(top[0][1]/h if h else 0)))
