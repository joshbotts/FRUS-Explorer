import sqlite3, re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
TOL=re.compile(r"\b(corrupt\w*|brib\w*|kickback\w*|embezzl\w*|malfeasance|peculat\w*|graft|venal\w*|nepotism|cronyism|payoffs?)\b",re.I)
STR=re.compile(r"\b(corruption|corrupt|bribery|bribe|graft)\b")
sql="""SELECT d.volume_id,d.document_id,d.header,d.dateline,d.source_note,d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH 'corrupt OR bribe OR bribery OR kickback OR embezzle OR malfeasance OR peculation OR graft OR venal OR nepotism OR cronyism OR payoff' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY d.volume_id,d.document_id"""
rows=[]; t=s=0
for v,d,h,dl,sn,b in con.execute(sql):
    txt=re.sub(r"\s+"," "," ".join([h or "",dl or "",sn or "",b or ""]))
    mt=TOL.search(txt); ms=STR.search(txt)
    t+= 1 if mt else 0; s+= 1 if ms else 0
    rows.append((v,d,txt,mt,ms))
N=len(rows); print("census N",N,"tolerant",t,"strict",s)
idx=[int(i*(N-1)/39) for i in range(40)]
st=sum(1 for i in idx if rows[i][3]); ss=sum(1 for i in idx if rows[i][4])
print("sample40 tolerant",st,"of 40; strict",ss,"of 40")
with open("sample40.txt","w") as f:
    for i in idx:
        v,d,txt,mt,ms=rows[i]
        if mt: c=txt[max(0,mt.start()-110):mt.end()+110]
        else: c="(no regex match)"
        f.write("%d %s/%s :: %s\n"%(i,v,d,c))
