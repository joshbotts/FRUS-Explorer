import json,struct,random,numpy as np,sqlite3,sys
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SV="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json"))
D=idx['provenanceDigest']
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
            b=numeric_part(s["i"]); ids.extend(f"d{b+k}" for k in range(1,s["n"]))
    return ids
row_of={};doc_of=[];vol_rows={}
ok=0
for v in idx['volumes']:
    ids=decode(v['seg']); ok+= len(ids)==v['n']
    for k,i in enumerate(ids): row_of[(v['v'],i)]=v['r']+k
    vol_rows[v['v']]=(v['r'],v['n'],ids)
doc_of=[None]*idx['documentCount']
for k,r in row_of.items(): doc_of[r]=k
print("round trip:",ok,"of",len(idx['volumes']),"volumes decode to n")
blob=open(R+"semantic-vectors-binary.bin","rb").read()
assert blob[:4]==b"FRSV"; ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
dbin=blob[20:52].hex(); mp=open(R+"semantic-map.bin","rb").read(); dmap=mp[20:52].hex()
print("digest index",D[:16],"binary",dbin[:16],"map",dmap[:16],"match:",D==dbin==dmap, "dims",dims,"docs",docs)
bpr=dims//8
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
def ham(q): return np.bitwise_count(np.bitwise_xor(S,S[q])).sum(axis=1)
# baselines
rng=random.Random(1877); pairs=[(rng.randrange(docs),rng.randrange(docs)) for _ in range(20000)]
a=np.array([p[0] for p in pairs]);b=np.array([p[1] for p in pairs])
rp=np.bitwise_count(np.bitwise_xor(S[a],S[b])).sum(axis=1)
print("random pairs (20,000, Random(1877)): mean %.1f sd %.1f p1 %d min %d"%(rp.mean(),rp.std(),np.percentile(rp,1),rp.min()))
rng2=random.Random(1878); samp=[rng2.randrange(docs) for _ in range(200)]
k25=[]; k1=[]
for q in samp:
    h=ham(q); h[q]=9999; s=np.sort(h); k1.append(s[0]); k25.append(s[24])
print("k-th neighbour over 200 random docs: nearest median %d (q1 %d q3 %d); 25th median %d (q1 %d q3 %d)"%(np.median(k1),np.percentile(k1,25),np.percentile(k1,75),np.median(k25),np.percentile(k25,25),np.percentile(k25,75)))
def shard(vol):
    f=open(SV+vol+".vec","rb").read(); assert f[:4]==b"FRSS"
    _,dd,n=struct.unpack("<III",f[4:16]); dg=f[16:48].hex()
    codes=np.frombuffer(f,dtype=np.int8,count=n*dd,offset=64).reshape(n,dd).astype(np.int32)
    sc=np.frombuffer(f,dtype=np.float32,count=n,offset=64+n*dd)
    return dg,codes,sc
def cos(p,q):
    (v1,i1),(v2,i2)=p,q
    g1,c1,s1=shard(v1); g2,c2,s2=shard(v2); assert g1==D and g2==D
    r1=row_of[p]-vol_rows[v1][0]; r2=row_of[q]-vol_rows[v2][0]
    return float(s1[r1]*s2[r2]*np.dot(c1[r1],c2[r2]))
mode=sys.argv[1]
if mode=="dups":
    for line in open(sys.argv[2]):
        p=tuple(line.strip().split('/'));
        if p not in row_of: print("NOT IN VECTORS",p); continue
        h=ham(row_of[p]); h[row_of[p]]=9999; o=np.argsort(h)[:3]
        print("/".join(p), [( "/".join(doc_of[x]), int(h[x])) for x in o])
elif mode=="nn":
    p=tuple(sys.argv[2].split('/')); q=row_of[p]; h=ham(q); h[q]=9999
    pool=np.argsort(h)[:800]
    # rerank by int8 cosine
    res=[]
    for x in pool[:800]:
        res.append((cos(p,doc_of[x]),int(h[x]),doc_of[x]))
    res.sort(reverse=True)
    for c,hh,dd in res[:int(sys.argv[3])]:
        print("%s/%s hamming %d raw-cos %.3f calibrated %.0f%%"%(dd[0],dd[1],hh,c,100*(c-0.40)/0.60))
