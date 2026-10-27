import sqlite3,json,struct
from vec import *
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB,uri=True)
def info(v,d):
    r=c.execute("""SELECT dd.date_iso, substr(replace(d.header,char(10),' '),1,60), d.is_front_matter, d.is_editorial_note,
       d.rowid IN (SELECT rowid FROM frus_documents WHERE frus_documents MATCH 'cuba OR cuban')
       FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
       WHERE d.volume_id=? AND d.document_id=?""",(v,d)).fetchone()
    return r
anchors=[("frus1874","d552"),("frus1902","d273"),("frus1941v07","d134"),("frus1950v02","d440"),("frus1961-63v11","d21"),("frus1969-76ve10","d205"),("frus1977-80v23","d18"),("frus1977-80v01","d129")]
print("=== A.5 NEAREST NEIGHBOURS (Hamming over 512 sign bits; digest %s)"%digest_bin[:8])
for a in anchors:
    row=row_of[a]; print("ANCHOR",a[0]+"/"+a[1],info(*a))
    for d,r in neighbours(row,10):
        v,i=doc_of[r]; inf=info(v,i)
        print("  ham %3d  %s/%s  %s | %s | contains-Cuba=%s fm=%s ed=%s"%(d,v,i,inf[0],inf[1],inf[4],inf[2],inf[3]))
