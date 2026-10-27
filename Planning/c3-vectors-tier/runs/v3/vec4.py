from vec import *
import math, collections, sqlite3
m=json.load(open(R+"semantic-map-index.json")); cl={c["id"]:c for c in m["clusters"]}
# --- centroid similarity
C=[centroid(i) for i in range(553)]
def cos(a,b):
    na=math.sqrt(sum(x*x for x in a)); nb=math.sqrt(sum(x*x for x in b))
    return sum(x*y for x,y in zip(a,b))/(na*nb)
rnd=random.Random(1877); rp=[cos(C[rnd.randrange(553)],C[rnd.randrange(553)]) for _ in range(2000)]
rp.sort(); print("random volume-pair centroid cosine: median %.3f p5 %.3f p95 %.3f"%(rp[1000],rp[100],rp[1900]))
for v in ["frus1874","frus1898","frus1934v05","frus1944v07","frus1958-60v06","frus1961-63v11","frus1977-80v23"]:
    i=vol_order.index(v); sc=sorted(((cos(C[i],C[j]),vol_order[j]) for j in range(553) if j!=i),reverse=True)[:6]
    print("CENTROID",v,[(round(a,3),b) for a,b in sc])
# --- map
anch=[("frus1874","d552"),("frus1881","d405"),("frus1898","d498"),("frus1904","d207"),("frus1934v05","d127"),("frus1944v07","d878"),("frus1958-60v06","d499"),("frus1961-63v11","d21"),("frus1969-76ve10","d205"),("frus1977-80v23","d21"),("frus1981-88v03","d5"),("frus1958-60v05","d112"),("frus1961-63v10-12mSupp","d729")]
for a in anch:
    x,y,c=map_place(row_of[a])
    print("MAP",a,(x,y),"cluster",c if c!=0xFFFF else "unclustered", cl[c]["terms"] if c!=0xFFFF else "", cl[c]["documentCount"] if c!=0xFFFF else "")
# unclustered share for Cuba chapter docs (Set A) vs era baseline
setA=[l.rstrip("\n").split("\t") for l in open("setA.tsv")]
cnt=collections.Counter(); tot=collections.Counter()
for v,d,dt,t in setA:
    r=row_of.get((v,d))
    if r is None: continue
    dec=dt[:3]+"0s"; tot[dec]+=1; cnt[dec]+= (map_place(r)[2]==0xFFFF)
print("SetA unclustered by decade:",{k:f"{cnt[k]}/{tot[k]}" for k in sorted(tot)})
