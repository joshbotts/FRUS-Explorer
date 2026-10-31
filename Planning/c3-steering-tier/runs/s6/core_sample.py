import csv, sqlite3, re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
FAM=re.compile(r"\b(corrupt\w*|brib\w*|kickback\w*|embezzl\w*|malfeasance|peculat\w*|graft|venal\w*|nepotism|cronyism)\b",re.I)
rows=[r for r in csv.DictReader(open("scan2.csv")) if int(r["nfam"])>=3]
rows.sort(key=lambda r:(r["volume_id"],r["document_id"]))
N=len(rows); idx=[int(i*(N-1)/39) for i in range(40)]
with open("core_sample40.txt","w") as f:
  for i in idx:
    r=rows[i]
    b=re.sub(r"\s+"," ",con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(r["volume_id"],r["document_id"])).fetchone()[0])
    ms=list(FAM.finditer(b)); m=ms[1]
    f.write("%d %s/%s n=%s :: %s\n"%(i,r["volume_id"],r["document_id"],r["nfam"],b[max(0,m.start()-130):m.end()+130]))
print(N)
