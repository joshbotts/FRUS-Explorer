import json,struct,random,pickle,glob,os
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ix=json.load(open(R+"semantic-vectors-index.json"))
dg=ix["provenanceDigest"]
blob=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
bd=blob[20:52].hex()
mp=open(R+"semantic-map.bin","rb").read()
md=mp[20:52].hex()
print("index digest",dg); print("binary digest",bd,"dims",dims,"docs",docs,"cents",cents); print("map digest",md)
gen=open("/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation").read().strip()
print("shard .generation",gen)
sm=json.load(open(R+"semantic-shards-manifest.json")); print("shard manifest keys",list(sm.keys())[:8]); 
for k,v in sm.items():
    if k!="shards" and not isinstance(v,(list,dict)): print(" ",k,v)
# shard header digests
bad=0;n=0
for f in glob.glob("/Users/jbotts/frus-analysis/c3/SemanticVectors/*.vec"):
    h=open(f,"rb").read(64); n+=1
    if h[16:48].hex()!=dg: bad+=1
print("shards checked",n,"digest mismatches",bad)
assert bd==dg==md==gen or print("MISMATCH (some artifact)")
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
            b=numeric_part(s["i"])
            ids.extend("d%d"%(b+k) for k in range(1,s["n"]))
    return ids
row_of={}; doc_of=[None]*docs; ok=0
for v in ix["volumes"]:
    ids=decode(v["seg"]); assert len(ids)==v["n"]; ok+=1
    for j,d in enumerate(ids):
        row_of[(v["v"],d)]=v["r"]+j; doc_of[v["r"]+j]=(v["v"],d)
print("volumes round-trip ok",ok,"of",len(ix["volumes"]),"rows",len(row_of))
bpr=dims//8
bits=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
pickle.dump((row_of,doc_of),open("vec_rows.pkl","wb"))
np.save("vec_bits.npy",bits)
# baseline: 20000 random pairs, seed 1877
rnd=random.Random(1877)
d=[]
for _ in range(20000):
    a=rnd.randrange(docs); b=rnd.randrange(docs)
    while b==a: b=rnd.randrange(docs)
    d.append(int(np.bitwise_count(bits[a]^bits[b]).sum()))
d=np.array(d); print("random pairs: mean %.1f sd %.1f p1 %.0f min %d"%(d.mean(),d.std(),np.percentile(d,1),d.min()))
print("scoreCalibration",ix["retrieval"]["scoreCalibration"])
print("measuredRecallAt10",ix["retrieval"]["measuredRecallAt10"],"generated",ix["generated"],"harvestGenerated",ix["harvestGenerated"])
