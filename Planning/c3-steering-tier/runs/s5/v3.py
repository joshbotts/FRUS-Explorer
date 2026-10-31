from vecsetup import *
import json, sqlite3, random, statistics
from docs_list import SECTIONS
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
mi=json.load(open(R+"semantic-map-index.json")); clusters={c["id"]:c for c in mi["clusters"]}
coll=[tuple(a.split("/")) for s,l in SECTIONS for a in l]
# --- centroid similarity: 553 volume centroids in index order
vnames=[v["v"] for v in ix["volumes"]]
cent=cent_raw[:553]
codes=cent[:,:dims].view(np.int8).astype(np.float32); scl=cent[:,dims:dims+4].copy().view(np.float32).reshape(-1)
V=codes*scl[:,None]; V=V.astype(np.float64); V/= np.linalg.norm(V,axis=1,keepdims=True)
print("CENTROID SIMILARITY (volume centroid cosine, RAW, not calibrated; centroid-to-centroid, not document-to-query)")
for vol in ("frus1964-68v05","frus1922v01","frus1977-80v03","frus1947v07"):
    i=vnames.index(vol); s=V@V[i]; o=np.argsort(-s)
    print(f" {vol}: "+", ".join(f"{vnames[j]} {s[j]:.3f}" for j in o[1:6]))
# --- baseline for centroid cosine: random volume pairs
rng=random.Random(1877); cs=[float(V[a]@V[b]) for a,b in ((rng.randrange(553),rng.randrange(553)) for _ in range(5000)) if a!=b]
print(f" baseline random volume-pair centroid cosine: mean {statistics.mean(cs):.3f} sd {statistics.pstdev(cs):.3f} max {max(cs):.3f}")
# --- map: clusters of the collection documents
print("\nMAP placements of the 38 collection documents")
cnt={}; unc=0
for v,d in coll:
    r=row_of[(v,d)]; x,y,c=struct.unpack("<hhH",mp[64+r*6:64+r*6+6])
    if c==0xFFFF: unc+=1; cnt.setdefault("unclustered",[]).append(f"{v}/{d}")
    else: cnt.setdefault(c,[]).append(f"{v}/{d}")
print(f" unclustered: {unc} of {len(coll)}")
for c,l in sorted(cnt.items(),key=lambda kv:-len(kv[1])):
    if c=="unclustered": continue
    cl=clusters[c]; print(f" cluster {c} ({len(l)} docs) terms={cl['terms']} documentCount={cl['documentCount']} eraCounts={cl['eraCounts']}")
# baseline: unclustered share among ALL documents of the same 27 volumes
S=sorted({v for v,_ in coll}); tot=0; un=0
for v in S:
    r0,ids=vol_rows[v]
    arr=np.frombuffer(mp,dtype=np.uint8,count=len(ids)*6,offset=64+r0*6).reshape(len(ids),6)
    cl=arr[:,4:6].copy().view(np.uint16).reshape(-1)
    tot+=len(ids); un+=int((cl==0xFFFF).sum())
print(f" volume-matched baseline: {un} of {tot} documents in the same {len(S)} volumes are unclustered ({un/tot:.3f}); corpus-wide 88059 of 314616 (0.280)")
# --- near-duplicate check inside the collection and for each collection doc vs the whole corpus
print("\nNEAR-DUPLICATE CHECK (sign-bit Hamming): nearest OTHER document in the whole corpus to each collection document; flag <=40")
rows=[row_of[p] for p in coll]
mins=[]
for p,r in zip(coll,rows):
    h=hamming_all(r).astype(np.int32); h[r]=10**6; j=int(np.argmin(h)); mins.append((int(h[j]),p,doc_of[j]))
mins.sort()
for m in mins[:8]: print(" ",m[0],m[1],"<->",m[2])
print(" collection docs with nearest other document at <=40 bits:",sum(1 for m in mins if m[0]<=40),"of",len(mins),"; min",mins[0][0],"median",statistics.median(m[0] for m in mins))
# pairwise within the collection
import itertools
pd=[(int(np.bitwise_count(np.bitwise_xor(signs[a],signs[b])).sum()),i,j) for (a,i),(b,j) in itertools.combinations(zip(rows,range(len(rows))),2)]
pd.sort(); print(" closest pairs inside the collection:",[(d,f'{coll[i][0]}/{coll[i][1]}',f'{coll[j][0]}/{coll[j][1]}') for d,i,j in pd[:4]])
print(" mean within-collection pair distance %.1f (random-pair baseline 167.1, sd 14.8)"%statistics.mean(d for d,_,_ in pd))
