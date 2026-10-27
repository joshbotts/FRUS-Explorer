# stats4.py: from scope.csv + scan_*.csv: share of Cuba-substantial documents (>=5 Cuba mentions) with Cuba-centred windows holding security or prosperity vocabulary
import csv,glob,collections
rows=[]
for f in glob.glob("scan_*.csv"):
    for r in csv.DictReader(open(f)):
        if r["date"]>="1870" and int(r["ncuba"])>=5: rows.append(r)
def band(d):
    y=int(d[:4]); return "1870-1899" if y<1900 else "1900-1939" if y<1940 else "1940-1957" if y<1958 else "1958-1989"
B=collections.defaultdict(lambda:[0,0,0,0,0,0])
for r in rows:
    b=band(r["date"]); x=B[b]; x[0]+=1
    s=int(r["nsec"])>0; p=int(r["npro"])>0; both=int(r["nboth"])>0
    x[1]+=s; x[2]+=p; x[3]+=both
    # windows share: windows with sec / windows with pro among all cuba windows
    x[4]+=int(r["nsec"]); x[5]+=int(r["ncuba"])
print("band | Cuba-substantial docs (M) | with a security-vocabulary window | with a prosperity-vocabulary window | with both in one window")
for b in ["1870-1899","1900-1939","1940-1957","1958-1989"]:
    x=B[b]; print("%s | %d | %d of %d (%.3f) | %d of %d (%.3f) | %d of %d (%.3f)"%(b,x[0],x[1],x[0],x[1]/x[0],x[2],x[0],x[2]/x[0],x[3],x[0],x[3]/x[0]))
tp=0
for b in B: pass
