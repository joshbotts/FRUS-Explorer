# Tier-1 sign-vector nearest neighbours, with digest check and two baselines. No SQL except the volume-presence check.
import json,struct,random,sys
import numpy as np
B="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(B+"semantic-vectors-index.json"))
blob=open(B+"semantic-vectors-binary.bin","rb").read()
mp=open(B+"semantic-map.bin","rb").read()
dig_idx=idx["provenanceDigest"].lower(); dig_bin=blob[20:52].hex(); dig_map=mp[20:52].hex()
shard=open("/Users/jbotts/frus-analysis/c3/SemanticVectors/frus1917-72PubDipv08.vec","rb").read(64)
dig_shard=shard[16:48].hex()
print("digests", dig_idx[:16], dig_bin[:16], dig_map[:16], dig_shard[:16], "ALL EQUAL" if len({dig_idx,dig_bin,dig_map,dig_shard})==1 else "MISMATCH")
if len({dig_idx,dig_bin,dig_map,dig_shard})!=1: sys.exit(1)
print("generated",idx.get("generated"),"harvestGenerated",idx.get("harvestGenerated"),"recall@10",idx.get("retrieval",{}).get("measuredRecallAt10"), "calib", idx.get("retrieval",{}).get("scoreCalibration"))
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bpr=dims//8
def numeric_part(x):
    if not x.startswith("d"): return None
    g=x[1:]
    if not g or not g.isdigit(): return None
    if len(g)>1 and g[0]=="0": return None
    return int(g)
row_of={}; doc_of={}
vols=idx["volumes"]; ok=0
for v in vols:
    ids=[]
    for seg in v["seg"]:
        assert seg["s"]==len(ids); ids.append(seg["i"])
        if seg["n"]>1:
            b=numeric_part(seg["i"]); ids.extend(f"d{b+k}" for k in range(1,seg["n"]))
    ok+= len(ids)==v["n"]
    for i,d in enumerate(ids): row_of[(v["v"],d)]=v["r"]+i; doc_of[v["r"]+i]=(v["v"],d)
print("round trip", ok, "of", len(vols))
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
def ham_all(r): return np.bitwise_count(np.bitwise_xor(S,S[r])).sum(axis=1)
rng=random.Random(1877); pairs=[(rng.randrange(docs),rng.randrange(docs)) for _ in range(20000)]
pd=np.array([int(np.bitwise_count(np.bitwise_xor(S[a],S[b])).sum()) for a,b in pairs if a!=b])
print("random pairs: n",len(pd),"mean %.1f sd %.1f p1 %d min %d"%(pd.mean(),pd.std(),np.percentile(pd,1),pd.min()))
rs=random.Random(7); samp=[rs.randrange(docs) for _ in range(200)]
k25=[];k1=[];k10=[]
for r in samp:
    h=np.sort(ham_all(r)); k1.append(h[1]); k10.append(h[10]); k25.append(h[25])
print("k-th neighbour over 200 docs: 1st median %d; 10th median %d (q1 %d q3 %d); 25th median %d"%(np.median(k1),np.median(k10),np.percentile(k10,25),np.percentile(k10,75),np.median(k25)))
for a in sys.argv[1:]:
    v,d=a.split("/"); r=row_of[(v,d)]; h=ham_all(r); order=np.argsort(h,kind="stable")
    print("ANCHOR",a)
    n=0
    for o in order:
        if o==r: continue
        print("   %3d  %s/%s"%(h[o],*doc_of[o])); n+=1
        if n==12: break
