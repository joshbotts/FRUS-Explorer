import json,struct,sys,random,os
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json"))
def numeric_part(d):
    if not d.startswith("d"): return None
    x=d[1:]
    if not x or not x.isdigit(): return None
    if len(x)>1 and x[0]=="0": return None
    return int(x)
def decode(segs):
    ids=[]
    for s in segs:
        assert s["s"]==len(ids)
        ids.append(s["i"])
        if s["n"]>1:
            b=numeric_part(s["i"]); ids.extend(f"d{b+k}" for k in range(1,s["n"]))
    return ids
row_of={}; doc_of=[None]*idx["documentCount"]; vol_rows={}
for v in idx["volumes"]:
    ids=decode(v["seg"]); assert len(ids)==v["n"],(v["v"],len(ids),v["n"])
    vol_rows[v["v"]]=(v["r"],v["n"],ids)
    for k,i in enumerate(ids):
        row_of[(v["v"],i)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],i)
blob=np.fromfile(R+"semantic-vectors-binary.bin",dtype=np.uint8)
ver,dims,docs,cents=struct.unpack("<IIII",bytes(blob[4:20])); bpr=dims//8
signs=blob[64:64+docs*bpr].reshape(docs,bpr)
def ham_all(row):
    x=np.bitwise_xor(signs,signs[row]); return np.bitwise_count(x).sum(axis=1).astype(int)
_shards={}
def shard(v):
    if v not in _shards:
        b=np.fromfile(SH+v+".vec",dtype=np.uint8)
        _,sd,n=struct.unpack("<III",bytes(b[4:16])); codes=b[64:64+n*sd].view(np.int8).reshape(n,sd)
        sc=b[64+n*sd:64+n*sd+n*4].view(np.float32); _shards[v]=(codes,sc)
    return _shards[v]
def vecof(row):
    v,i=doc_of[row]; r0,n,ids=vol_rows[v]; codes,sc=shard(v); k=row-r0
    return codes[k].astype(np.float32)*sc[k]
def neighbours(anchor,topn=15,pool=800):
    r=row_of[anchor]; h=ham_all(r); h[r]=10**6
    cand=np.argsort(h,kind="stable")[:pool]
    q=vecof(r); res=[]
    for c in cand:
        c=int(c); cs=float(np.dot(q,vecof(c))); res.append((cs,int(h[c]),doc_of[c]))
    res.sort(reverse=True); return res[:topn], sorted([(int(h[c]),doc_of[int(c)]) for c in cand[:topn]])
if __name__=="__main__":
    print("dims",dims,"docs",docs,"cents",cents)
    # baselines
    rnd=random.Random(1877); ds=[]
    for _ in range(20000):
        a=rnd.randrange(docs); b=rnd.randrange(docs)
        ds.append(int(np.bitwise_count(np.bitwise_xor(signs[a],signs[b])).sum()))
    ds=np.array(ds); print("random pairs: mean %.1f sd %.1f p1 %.0f min %d"%(ds.mean(),ds.std(),np.percentile(ds,1),ds.min()))
    rs=random.Random(2026); k25=[]
    for _ in range(200):
        r=rs.randrange(docs); h=ham_all(r); h[r]=10**6; k25.append(int(np.sort(h)[24]))
    k25=np.array(k25); print("25th neighbour over 200 random docs: median %d q1 %d q3 %d"%(np.median(k25),np.percentile(k25,25),np.percentile(k25,75)))
