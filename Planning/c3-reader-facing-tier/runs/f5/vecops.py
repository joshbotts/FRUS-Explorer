# vecops.py: centroid similarity, map clusters, near-duplicate pairs among the collection set, semantic join
import sys,json,collections; sys.path.insert(0,'/Users/jbotts/frus-analysis/c3f/runs/f5')
import vec, numpy as np
from h import *
from nn import nn, info
SET=[l.strip().split('/') for l in open('collection_set.txt') if l.strip()]
c=conn()
# 1. centroid similarity
cm=vec.cent_block()   # 660 x 512 dequantized
vols=[v["v"] for v in vec.idx["volumes"]]
def cos(a,b): return float(a@b/np.linalg.norm(a)/np.linalg.norm(b))
print("== CENTROIDS (volume centroids rows 0..552 in index order)")
for target in ["frus1917-72PubDipv07","frus1977-80v30","frus1955-57v09"]:
    i=vols.index(target)
    sims=sorted(((cos(cm[i],cm[j]),vols[j]) for j in range(553) if j!=i),reverse=True)[:6]
    print(target, [(round(s,3),v) for s,v in sims])
# 2. map
m=np.fromfile(vec.R+"semantic-map.bin",dtype=np.uint8)
pl=m[64:64+vec.docs*6].reshape(vec.docs,6)
x=pl[:,0:2].copy().view(np.int16).reshape(-1); y=pl[:,2:4].copy().view(np.int16).reshape(-1); cl=pl[:,4:6].copy().view(np.uint16).reshape(-1)
mi=json.load(open(vec.R+"semantic-map-index.json"))
print("== MAP keys",list(mi.keys())[:8])
clusters=mi.get("clusters") or mi.get("c") or []
def label(cid):
    for k in clusters:
        if k.get("id",k.get("c"))==cid: return k
    return None
ct=collections.Counter(); unc=0
rows=[]
for v,d in SET:
    r=vec.row_of[(v,d)]; cid=int(cl[r])
    if cid==0xFFFF: unc+=1
    ct[cid]+=1; rows.append((v,d,cid))
print("set size",len(SET),"unclustered",unc)
for cid,n in ct.most_common(8):
    lab=label(cid)
    print("cluster",cid,"n_in_set",n,"label",(lab.get("terms") or lab.get("label") or str(lab)[:120]) if lab else None, "docs",lab.get("n") if lab else None)
print("overall unclustered share:",int((cl==0xFFFF).sum()),"of",vec.docs)
# baseline: volumes of same era
# 3. near-duplicate pairs within set (Hamming)
rowsS=[vec.row_of[(v,d)] for v,d in SET]
print("== NEAR-DUPLICATE SCAN within set (Hamming <=70), plus nearest in corpus <=40 for each")
for i in range(len(SET)):
    for j in range(i+1,len(SET)):
        h=int(np.bitwise_count(vec.signs[rowsS[i]]^vec.signs[rowsS[j]]).sum())
        if h<=70: print("pair",SET[i],SET[j],"hamming",h)
for (v,d),r in zip(SET,rowsS):
    h=vec.hamming_all(r); h[r]=9999
    idx=np.argsort(h)[:3]
    close=[(vec.doc_of[int(k)],int(h[k])) for k in idx if h[k]<=60]
    if close: print("close to",(v,d),close)
