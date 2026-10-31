import sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=['frus1941v04','frus1942China','frus1942v01','frus1943China','frus1943v03','frus1944v05','frus1944v06','frus1945v06','frus1945v07']
ph=",".join("?"*len(vols))
den=db.execute(f"select count(*) from document_cache where volume_id in ({ph}) and is_front_matter=0 and is_editorial_note=0",vols).fetchone()[0]
print("wartime Far East volumes",len(vols),"non-apparatus docs",den)
for t in ["ZZZ_IMPOSSIBLE_ZZZ","department of state","office of war information","owi","propaganda","psychological warfare","information program","cultural relations","educational exchange","american prestige","prestige"]:
    n=db.execute(f"select count(*) from frus_documents f join document_cache d on d.rowid=f.rowid where frus_documents match ? and d.volume_id in ({ph}) and d.is_front_matter=0 and d.is_editorial_note=0",['"%s"'%t]+vols).fetchone()[0]
    print("%-28s %5d of %d docs"%(t,n,den))
