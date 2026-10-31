import json,struct,random,sys,os
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json"))
print("index keys",list(idx.keys()))
dig=idx["provenanceDigest"]
blob=open(R+"semantic-vectors-binary.bin","rb").read()
mp=open(R+"semantic-map.bin","rb").read(64)
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
print("binary",blob[:4],ver,dims,docs,cents)
print("digest index",dig[:16])
print("digest binary",blob[20:52].hex()[:16], blob[20:52].hex()==dig)
print("digest map",mp[20:52].hex()==dig)
gen=open(SH+".generation").read().strip() if os.path.exists(SH+".generation") else None
print("shard .generation",gen[:16] if gen else None, gen==dig if gen else None)
def numeric_part(x):
    if not x.startswith("d"): return None
    g=x[1:]
    if not g or not g.isdigit(): return None
    if len(g)>1 and g[0]=="0": return None
    return int(g)
def decode(segs):
    ids=[]
    for s in segs:
        assert s["s"]==len(ids); ids.append(s["i"])
        if s["n"]>1:
            b=numeric_part(s["i"]); ids.extend("d%d"%(b+k) for k in range(1,s["n"]))
    return ids
row_of={}; doc_of={}; ok=0; vol_rows={}
for v in idx["volumes"]:
    ids=decode(v["seg"]); 
    if len(ids)==v["n"]: ok+=1
    vol_rows[v["id"] if "id" in v else v["v"]]=(v["r"],ids)
    for i,d in enumerate(ids):
        key=(v.get("id",v.get("v")),d); row_of[key]=v["r"]+i; doc_of[v["r"]+i]=key
print("round trip",ok,"of",len(idx["volumes"]))
bpr=dims//8
signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
def ham(r): return np.bitwise_count(np.bitwise_xor(signs,signs[r])).sum(axis=1)
# baselines
rng=random.Random(1877); pr=[(rng.randrange(docs),rng.randrange(docs)) for _ in range(20000)]
a=np.array([p[0] for p in pr]); b=np.array([p[1] for p in pr])
rp=np.bitwise_count(np.bitwise_xor(signs[a],signs[b])).sum(axis=1)
print("random pairs mean %.1f sd %.1f p1 %d min %d"%(rp.mean(),rp.std(),np.percentile(rp,1),rp.min()))
samp=[rng.randrange(docs) for _ in range(200)]
k1=[];k10=[];k25=[]
for r in samp:
    h=np.sort(ham(r)); k1.append(h[1]); k10.append(h[10]); k25.append(h[25])
print("200-sample: 1st-nbr median %d; 10th-nbr median %d q1 %d q3 %d; 25th median %d"%(np.median(k1),np.median(k10),np.percentile(k10,25),np.percentile(k10,75),np.median(k25)))
print("retrieval",json.dumps(idx.get("retrieval",{}))[:600])
import pickle; pickle.dump((row_of,doc_of,vol_rows,dims),open("vecmaps.pkl","wb"))
