import sqlite3,re,sys,json
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
name,fts,strict,tol,invol=sys.argv[1:6]
con=sqlite3.connect(DB,uri=True)
IN=open(invol).read().strip()
rows=con.execute(f"""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
 WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ({IN}) ORDER BY d.volume_id,d.document_id""",(fts,)).fetchall()
n=len(rows); k=40 if n>=40 else n
idx=sorted(set(int(i*n/k) for i in range(k))) if n>=300 or n>40 else list(range(n))
if n<300 and n>40: idx=sorted(set(int(i*n/k) for i in range(k)))
sample=[rows[i] for i in idx]
S=re.compile(strict,re.I); T=re.compile(tol,re.I)
s_hit=t_hit=0; miss=[]
for v,d in sample:
    h,dl,sn,b=con.execute("SELECT header,ifnull(dateline,''),ifnull(source_note,''),body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    txt=re.sub(r'\s+',' ',' '.join([h,dl,sn,b]))
    s=bool(S.search(txt)); t=bool(T.search(txt)); s_hit+=s; t_hit+=t
    if not t: miss.append(f"{v}/{d}")
out=f"{name}: hits={n} sample={len(sample)} STRICT={s_hit} of {len(sample)} TOLERANT={t_hit} of {len(sample)} (regex case-insensitive, Python re) misses_tolerant={miss}"
print(out); open("share_results.txt","a").write(out+"\n")
