import csv,sys,glob
lo,hi,k=sys.argv[1],sys.argv[2],int(sys.argv[3])
rows=[]
for f in glob.glob("scan_*.csv"):
    for r in csv.DictReader(open(f)):
        if lo<=r["date"]<hi: rows.append(r)
rows.sort(key=lambda r:-int(r["nboth"]))
for r in rows[:k]:
    print(r["volume_id"],r["document_id"],r["date"],r["header"][:70],"len",r["len"],"cuba",r["ncuba"],"sec",r["nsec"],"pro",r["npro"],"both",r["nboth"],sep=" | ")
