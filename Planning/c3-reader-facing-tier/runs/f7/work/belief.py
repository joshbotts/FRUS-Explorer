import sqlite3,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open("work/ea_vols_list.txt")]+['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30']
ph=",".join("?"*len(vols))
q='"oriental mind" OR "asian mind" OR "asian psychology" OR "psychology of asians" OR "oriental psychology" OR "asiatic mind"'
sql=f"""SELECT d.volume_id,d.document_id,d.header,d.body_text,COALESCE(dd.date_iso,'') FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE frus_documents MATCH ? AND d.volume_id IN ({ph}) AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id,d.rowid"""
rx=re.compile(r"(?i)(oriental|asian|asiatic)\s+(mind|psycholog)|psycholog\w*\s+of\s+(the\s+)?(asian|oriental)s?")
n=0
for v,d,h,b,dt in db.execute(sql,[q]+vols):
    t=" ".join((h+" "+b).split())
    m=rx.search(t)
    n+=1
    print("##",v+"/"+d,dt[:10],"|",h[:90].replace("\n"," "),"| literal:",bool(m))
    if m: print("   ...",t[max(0,m.start()-260):m.end()+260])
print("N fts hits",n)
