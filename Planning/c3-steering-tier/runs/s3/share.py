import sqlite3, re, json
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
SQL="""SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
WHERE frus_documents MATCH 'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl' AND c.is_front_matter=0 AND c.is_editorial_note=0
AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY f.volume_id, f.document_id"""
hits=con.execute(SQL).fetchall()
M=len(hits); step=M/40.0
sample=[hits[int(i*step)] for i in range(40)]
STRICT=re.compile(r"\b(corrupt|corruption|bribe|bribery|graft|kickback|embezzlement)\b")   # case-sensitive lower forms only
TOL=re.compile(r"\b(corrupt\w*|brib(e|es|ed|ing|ery|eries)\b|graft\w*|kick[\s\-]?backs?|embezzl\w*)", re.I)
GARBLE=re.compile(r"corrupt(ed)?\s+(group|text|in transmission)|text\s+corrupt|corrupt\s+(and|or)\s+garbl|garbled\s+(and|or)\s+corrupt", re.I)
out=[]; s=t=g=0
for v,d in sample:
    h,dl,sn,b=con.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    txt=re.sub(r"\s+"," "," ".join([h or "",dl or "",sn or "",b or ""]))
    a=bool(STRICT.search(txt)); bb=bool(TOL.search(txt)); gg=bool(GARBLE.search(txt))
    s+=a; t+=bb; g+=gg
    m=TOL.search(txt); ctx=txt[max(0,m.start()-90):m.end()+90] if m else ""
    out.append((v,d,a,bb,gg,ctx))
json.dump({"M":M,"sample":out},open("share_sample.json","w"),indent=1)
print("hit list M =",M,"sample",len(sample),"STRICT",s,"TOLERANT",t,"garble-sense",g)
for r in out: print(r[0],r[1],int(r[2]),int(r[3]),int(r[4]),"|",r[5][:200])
