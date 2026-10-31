import sqlite3, re, csv, sys
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB,uri=True)
FAM=re.compile(r"\b(corrupt\w*|brib\w*|kickback\w*|embezzl\w*|malfeasance|peculat\w*|graft|venal\w*|nepotism|cronyism|payoffs?)\b",re.I)
sql="""SELECT d.volume_id,d.document_id,d.header,length(d.body_text),d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH 'corrupt OR bribe OR bribery OR kickback OR embezzle OR malfeasance OR peculation OR graft OR venal OR nepotism OR cronyism OR payoff' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY d.volume_id,d.document_id"""
w=csv.writer(open("scan1.csv","w",newline=""))
w.writerow(["volume_id","document_id","len","nfam","ncorrupt","header"])
n=0
for v,d,h,L,b in con.execute(sql):
    ms=[m.group(1).lower() for m in FAM.finditer(b)]
    nc=sum(1 for m in ms if m.startswith("corrupt"))
    w.writerow([v,d,L,len(ms),nc,(h or "")[:150]]); n+=1
print(n)
