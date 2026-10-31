import sqlite3, re, csv, sys
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB,uri=True)
FTS="corrupt OR bribe OR briberi OR graft OR embezzl* OR venal OR kickback OR malfeas* OR nepot* OR cronyism OR misappropri*"
sql="""SELECT c.volume_id,c.document_id,c.header,length(c.body_text),t.date_iso,c.body_text
FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id
WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 ORDER BY c.volume_id,c.document_id"""
rx=re.compile(r"\b(corrupt\w*|brib\w*|graft(?:ers?|ing)?|kick-?backs?|embezzl\w*|venal\w*|malfeasance|peculat\w+|nepotism|cronyism|misappropriat\w*|payoffs?|pay-offs?)\b",re.I)
rxc=re.compile(r"\bcorrupt\w*",re.I)
w=csv.writer(open("scan1.csv","w"))
w.writerow(["volume_id","document_id","date","len","fam","corrupt","header"])
n=0
for v,d,h,L,dt,b in con.execute(sql,(FTS,)):
    t=(h or "")+" "+b
    fam=len(rx.findall(t)); c=len(rxc.findall(t))
    w.writerow([v,d,dt,L,fam,c,(h or "")[:160].replace("\n"," ")])
    n+=1
print(n)
