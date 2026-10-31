import sqlite3,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open("work/ea_vols_list.txt")]+['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30']
ph=",".join("?"*len(vols))
q='"oriental mind" OR "asian mind" OR "asian psychology" OR "psychology of asians" OR "oriental psychology" OR "asiatic mind"'
sql=f"""SELECT d.volume_id,d.document_id,d.header,d.dateline,d.source_note,d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH ? AND d.volume_id IN ({ph}) AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id,d.document_id"""
rows=db.execute(sql,[q]+vols).fetchall()
strict=re.compile(r"(?i)\b(oriental mind|asian mind|asiatic mind|oriental psychology|asian psychology|psychology of asians)\b")
tol=re.compile(r"(?i)\b(oriental|asian|asiatic)s?[\s,\-\(\)\.]*(mind|minds|psycholog\w*|mentality)\b|\bpsycholog\w*[\s,\-\(\)\.]*of[\s,\-\(\)\.]*(the[\s,\-\(\)\.]*)?(asian|oriental|asiatic)\w*")
ns=nt=0
for v,d,h,dl,sn,b in rows:
    t=" ".join((h+" "+dl+" "+sn+" "+b).split())
    s=bool(strict.search(t));o=bool(tol.search(t));ns+=s;nt+=o
    print(v+"/"+d,"strict",int(s),"tolerant",int(o))
print("CENSUS of FTS hits: N=%d  STRICT literal %d of %d  TOLERANT literal %d of %d"%(len(rows),ns,len(rows),nt,len(rows)))
