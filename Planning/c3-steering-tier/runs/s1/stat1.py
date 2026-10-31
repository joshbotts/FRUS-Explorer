import sqlite3, re, collections
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
BASE="c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN "+ED2
HIT="SELECT c.volume_id,c.document_id,c.header,c.dateline,c.source_note,c.body_text FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt' AND "+BASE+" ORDER BY c.volume_id,c.document_id"
print("SQL hit list:",HIT.replace("c.body_text FROM","c.body_text FROM"))
rows=con.execute(HIT).fetchall()
N=len(rows); print("N hits (Ed2 suppressed, apparatus excluded):",N,"volumes:",len({r[0] for r in rows}))
step=N/40; sample=[rows[int(i*step)] for i in range(40)]
strict=re.compile(r"\b(?:corrupt|corruption)\b"); tol=re.compile(r"\bcorrupt\w*",re.I)
def full(r): return re.sub(r"\s+"," "," ".join(x or "" for x in r[2:6]))
s=sum(1 for r in sample if strict.search(full(r))); t=sum(1 for r in sample if tol.search(full(r)))
print("STRICT (whole words 'corrupt'|'corruption', case-sensitive-lower): %d of 40"%s)
print("TOLERANT (\\bcorrupt\\w*, case-insens): %d of 40"%t)
sn=open("stat1_sample.txt","w")
for i,r in enumerate(sample):
    tx=full(r); m=tol.search(tx)
    sn.write("%02d %s/%s | ...%s...\n"%(i+1,r[0],r[1],tx[max(0,m.start()-140):m.end()+140] if m else "NO MATCH"))
sn.close()
