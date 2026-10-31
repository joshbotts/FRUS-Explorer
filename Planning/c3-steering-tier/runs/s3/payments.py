import sqlite3, re
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
SQL="""SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
WHERE frus_documents MATCH '"improper payment" OR "illicit payment" OR "questionable payment"' AND c.is_front_matter=0 AND c.is_editorial_note=0
AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY f.volume_id, f.document_id"""
hits=con.execute(SQL).fetchall()
S=re.compile(r"\b(improper|illicit|questionable) payments?\b")
T=re.compile(r"\b(improper|illicit|questionable)[\s\-,().]+pay(ment|ments|ing|ed)?\b", re.I)
s=t=0; inbrib=0
for v,d in hits:
    h,dl,sn,b=con.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    x=re.sub(r"\s+"," "," ".join([h or "",dl or "",sn or "",b or ""]))
    a=bool(S.search(x)); bb=bool(T.search(x)); s+=a; t+=bb
    fam=bool(re.search(r"corrupt\w*|brib\w*|graft\w*|kickback\w*|embezzl\w*",x,re.I)); inbrib+=fam
    print(v,d,int(a),int(bb),int(fam))
print("census M",len(hits),"STRICT",s,"TOLERANT",t,"also carry the corruption family words",inbrib)
