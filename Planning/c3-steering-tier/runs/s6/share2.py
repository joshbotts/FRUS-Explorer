import sqlite3, re, csv
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
TOL=re.compile(r"\b(corrupt\w*|brib\w*|kickback\w*|embezzl\w*|malfeasance|peculat\w*|graft|venal\w*|nepotism|cronyism)\b",re.I)
STR=re.compile(r"\b(corruption|corrupt|bribery|bribe|graft)\b")
core=sorted((r["volume_id"],r["document_id"]) for r in csv.DictReader(open("scan2.csv")) if int(r["nfam"])>=3)
N=len(core); idx=[int(i*(N-1)/39) for i in range(40)]
t=s=0; st=ss=0
for n,(v,d) in enumerate(core):
    h,dl,sn,b=con.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    txt=re.sub(r"\s+"," "," ".join([h or "",dl or "",sn or "",b or ""]))
    a=bool(TOL.search(txt)); c=bool(STR.search(txt)); t+=a; s+=c
    if n in idx: st+=a; ss+=c
print("core census N",N,"tolerant",t,"strict",s,"| sample40 (same idx as core_sample40.txt) tolerant",st,"strict",ss)
# >=1 set: final-family census
rows=[r for r in csv.DictReader(open("scan2.csv")) if int(r["nfam"])>=1]
print(">=1 set N",len(rows))
