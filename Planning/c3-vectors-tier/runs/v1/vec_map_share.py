import sqlite3,struct,csv,glob
from vec import *
m=open(R+"semantic-map.bin","rb").read()
def cl(row):
    o=64+row*6; return struct.unpack("<hhH",m[o:o+6])[2]
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
bands=[("1870-1899","1870","1900"),("1900-1939","1900","1940"),("1940-1957","1940","1958"),("1958-1989","1958","1990")]
# Cuba hit set from scan csvs
cub=[]
for f in glob.glob("scan_*.csv"):
    for r in csv.DictReader(open(f)): cub.append((r["volume_id"],r["document_id"],r["date"]))
print("band | all dated non-apparatus docs: N, unclustered, in cluster 42 | Cuba-hit docs: N, unclustered, in cluster 42, not in index")
for name,lo,hi in bands:
    N=U=C42=0
    for v,d in c.execute("""SELECT d.volume_id,d.document_id FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
        WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso>=? AND dd.date_iso<?""",(lo,hi)):
        r=row_of.get((v,d))
        if r is None: continue
        N+=1; k=cl(r); U+=(k==0xFFFF); C42+=(k==42)
    n=u=c42=miss=0
    for v,d,dt in cub:
        if lo<=dt<hi:
            r=row_of.get((v,d))
            if r is None: miss+=1; continue
            n+=1; k=cl(r); u+=(k==0xFFFF); c42+=(k==42)
    print("%s | %d, %d (%.1f%%), %d (%.1f%%) | %d, %d (%.1f%%), %d (%.1f%%), %d"%(name,N,U,100*U/N,C42,100*C42/N,n,u,100*u/max(n,1),c42,100*c42/max(n,1),miss),flush=True)
