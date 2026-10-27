import sqlite3,json,struct
from vec import *
vols=[v["v"] for v in ix["volumes"]]
C=[centroid(i) for i in range(len(vols))]
vi={v:i for i,v in enumerate(vols)}
print("=== CENTROID SIMILARITY (cosine of int8 centroid x scale; 553 volume centroids)")
for v in ["frus1874","frus1898","frus1941v07","frus1958-60v06","frus1961-63v11","frus1977-80v23"]:
    sims=sorted(((cos(C[vi[v]],C[j]),vols[j]) for j in range(len(vols)) if j!=vi[v]),reverse=True)[:6]
    print(v,"->"," ".join("%s %.3f"%(n,s) for s,n in sims))
# baseline: cosine distribution between random volume pairs and nearest-volume cosines for all volumes
import random,statistics
r=random.Random(1877); rp=[cos(C[a],C[b]) for a,b in ((r.randrange(553),r.randrange(553)) for _ in range(3000)) if a!=b]
print("random volume pairs: mean %.3f sd %.3f"%(statistics.mean(rp),statistics.pstdev(rp)))
# map
m=open(R+"semantic-map.bin","rb").read()
mdocs,mclus,ext=struct.unpack("<III",m[8:20])
mi=json.load(open(R+"semantic-map-index.json"))
print("map docs",mdocs,"clusters",mclus,"keys",list(mi.keys()))
cl=mi.get("clusters")
lab={}
if isinstance(cl,list):
    for x in cl: lab[x.get("id",x.get("cluster"))]=x
def place(row):
    o=64+row*6; x,y,c=struct.unpack("<hhH",m[o:o+6]); return x,y,c
print("=== MAP placements of anchor and chapter documents")
sel=[("frus1874","d552"),("frus1898","d498"),("frus1902","d273"),("frus1941v07","d134"),("frus1948v09","d420"),("frus1950v02","d440"),("frus1958-60v06","d535"),("frus1961-63v11","d21"),("frus1969-76ve10","d205"),("frus1977-80v23","d18"),("frus1977-80v01","d129"),("frus1981-88v03","d10")]
for a in sel:
    x,y,c=place(row_of[a])
    desc=""
    if c!=0xFFFF and c in lab: 
        e=lab[c]; desc=json.dumps({k:e[k] for k in e if k in("terms","label","docCount","count","n")})[:200]
    print(a[0]+"/"+a[1],"cluster",("unclustered" if c==0xFFFF else c),desc)
