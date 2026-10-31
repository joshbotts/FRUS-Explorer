# Appendix A operations: digest check, id decode, NN of anchors, baselines, near-duplicates over the set
import json, struct, random, numpy as np, os, sys
R="/Applications/FRUS Explorer.app/Contents/Resources/"; SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json"))
blob=open(R+"semantic-vectors-binary.bin","rb").read(); mp=open(R+"semantic-map.bin","rb").read()
dig=idx["provenanceDigest"]; print("index digest",dig)
print("binary digest",blob[20:52].hex()); print("map digest",mp[20:52].hex())
gen=open(SH+".generation").read().strip() if os.path.exists(SH+".generation") else "NONE"; print(".generation",gen)
assert blob[20:52].hex()==dig and mp[20:52].hex()==dig
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); print("dims",dims,"docs",docs,"centroids",cents)
print("retrieval",json.dumps(idx.get("retrieval"))[:600]); print("generated",idx.get("generated"),"harvestGenerated",idx.get("harvestGenerated"))
def numeric_part(d):
    if not d.startswith("d"): return None
    g=d[1:]
    if not g or not g.isdigit(): return None
    if len(g)>1 and g[0]=="0": return None
    return int(g)
row_of={}; doc_of={}; bad=0
for v in idx["volumes"]:
    ids=[]
    for s in v["seg"]:
        assert s["s"]==len(ids); ids.append(s["i"])
        if s["n"]>1:
            b=numeric_part(s["i"]); ids.extend(f"d{b+k}" for k in range(1,s["n"]))
    if len(ids)!=v["n"]: bad+=1
    vid=v.get("id") or v.get("v")
    for k,i in enumerate(ids): row_of[(vid,i)]=v["r"]+k; doc_of[v["r"]+k]=(vid,i)
print("round trip mismatches",bad,"of",len(idx["volumes"]))
bpr=dims//8
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
def ham(q): return np.bitwise_count(np.bitwise_xor(S,S[q])).sum(axis=1)
rng=random.Random(1877); pr=[(rng.randrange(docs),rng.randrange(docs)) for _ in range(20000)]
rd=np.array([int(np.bitwise_count(np.bitwise_xor(S[a],S[b])).sum()) for a,b in pr if a!=b])
print("random pairs: n",len(rd),"mean %.1f sd %.1f p1 %d min %d"%(rd.mean(),rd.std(),np.percentile(rd,1),rd.min()))
rng2=random.Random(1877); samp=[rng2.randrange(docs) for _ in range(200)]
k25=[]; k1=[]; k10=[]
for q in samp:
    h=ham(q); h[q]=9999; hs=np.sort(h); k1.append(hs[0]); k10.append(hs[9]); k25.append(hs[24])
print("200-doc sample: 1st-NN median %d; 10th-NN median %d quartiles %d %d; 25th-NN median %d quartiles %d %d"%(np.median(k1),np.median(k10),np.percentile(k10,25),np.percentile(k10,75),np.median(k25),np.percentile(k25,25),np.percentile(k25,75)))
setp=[tuple(l.strip().split("|")) for l in open("raw/set.txt")]
rows=[row_of[p] for p in setp]
print("set rows resolved",len(rows),"of",len(setp))
out={}
for a in sys.argv[1:]:
    v,d=a.split("/"); q=row_of[(v,d)]; h=ham(q); h[q]=9999; o=np.argsort(h)[:15]
    out[a]=[(doc_of[int(r)][0],doc_of[int(r)][1],int(h[r])) for r in o]
    print("NN of",a); [print("   ",x) for x in out[a]]
# near-duplicates within set and set vs corpus (<=20 bits)
print("near-dup scan (hamming<=20) for each set member against full corpus:")
for p,r in zip(setp,rows):
    h=ham(r); h[r]=9999; c=np.where(h<=20)[0]
    if len(c): print("   ",p,[(doc_of[int(x)],int(h[x])) for x in c])
# within-set pairwise
M=np.array([[int(np.bitwise_count(np.bitwise_xor(S[a],S[b])).sum()) for b in rows] for a in rows])
iu=np.triu_indices(len(rows),1); print("within-set pairwise hamming: mean %.1f min %d"%(M[iu].mean(),M[iu].min()))
json.dump(out,open("raw/vec_nn.json","w"))
