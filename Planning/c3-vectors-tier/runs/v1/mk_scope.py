# builds scope.csv: Cuba-substantial documents (>=5 case-sensitive Cuba/Cuban/Cubans mentions) from scan_*.csv, date >=1870
import csv,glob
rows=[]
for f in glob.glob("scan_*.csv"):
    for r in csv.DictReader(open(f)):
        if r["date"]>="1870" and int(r["ncuba"])>=5: rows.append(r)
rows.sort(key=lambda r:(r["date"],r["volume_id"],r["document_id"]))
w=csv.writer(open("scope.csv","w",newline="")); w.writerow(["volume_id","document_id","date","ncuba"])
for r in rows: w.writerow([r["volume_id"],r["document_id"],r["date"],r["ncuba"]])
print(len(rows))
