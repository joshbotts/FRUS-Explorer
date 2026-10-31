import json,struct,os,re,sys
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"; SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json"))
print("index keys:",list(idx.keys())); print("documentCount:",idx.get("documentCount"),"| volumes:",len(idx["volumes"]))
v0=idx["volumes"][0]; print("volume entry keys:",list(v0.keys()),"| first entry (trunc):",json.dumps(v0,ensure_ascii=False)[:300])
print("schema:",json.dumps(idx.get("schema"),ensure_ascii=False)[:1200])
dig=idx["provenanceDigest"]; print("provenanceDigest:",dig)
blob=open(R+"semantic-vectors-binary.bin","rb").read()
print("binary size:",len(blob),"| magic:",blob[:4],"| header u32s 4..64:",struct.unpack("<15I",blob[4:64]))
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bdig=blob[20:52].hex()
print("ver",ver,"dims",dims,"docs",docs,"centroids",cents,"| binary digest == index digest:",bdig==dig)
mp=open(R+"semantic-map.bin","rb").read(64); print("map magic:",mp[:4],"| map digest == index:",mp[20:52].hex()==dig)
gen=open(SH+".generation").read().strip(); print(".generation == index digest:",gen==dig,"| shards present:",len([f for f in os.listdir(SH) if f.endswith(".vec")]))
# my own decode of the run-length segments
def decode(v):
    ids=[]
    for s in v["seg"]:
        assert s["s"]==len(ids),(v,s)
        m=re.fullmatch(r"d(\d+)",s["i"])
        if s["n"]>1:
            assert m and not (len(m.group(1))>1 and m.group(1)[0]=="0"), s
            base=int(m.group(1)); ids.extend("d%d"%(base+k) for k in range(s["n"]))
        else: ids.append(s["i"])
    assert len(ids)==v["n"],(v.get("id"),len(ids),v["n"])
    return ids
vk="id" if "id" in v0 else "v"
row_of={}; doc_of={}; vol_rows={}
for v in idx["volumes"]:
    ids=decode(v); vol_rows[v[vk]]=(v["r"],ids)
    for i,d in enumerate(ids): row_of[(v[vk],d)]=v["r"]+i; doc_of[v["r"]+i]=(v[vk],d)
print("decoded rows:",len(row_of),"== docs:",len(row_of)==docs,"| contiguous rows 0..docs-1:",sorted(doc_of)==list(range(docs)))
bpr=dims//8
signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
print("sign block ends at byte",64+docs*bpr,"of",len(blob))
POP=np.array([bin(i).count("1") for i in range(256)],dtype=np.uint8)
def ham(r): return POP[np.bitwise_xor(signs,signs[r])].sum(axis=1,dtype=np.int32)
ED2={v for v in vol_rows if v.endswith("Ed2")}; print("Ed2 volumes in index:",sorted(ED2))
cache={}
def shard(vol):
    if vol not in cache:
        b=open(SH+vol+".vec","rb").read(); assert b[:4]==b"FRSS",vol
        d=struct.unpack("<I",b[8:12])[0]; n=struct.unpack("<I",b[12:16])[0]; assert b[16:48].hex()==dig,("digest",vol)
        assert d==dims and n==len(vol_rows[vol][1]),(vol,d,n)
        codes=np.frombuffer(b,dtype=np.int8,count=n*d,offset=64).reshape(n,d).astype(np.int32)
        sc=np.frombuffer(b,dtype=np.float32,count=n,offset=64+n*d)
        cache[vol]=(codes,sc,len(b),64+n*d+4*n)
    return cache[vol]
def vec(key):
    vol,d=key; r0,ids=vol_rows[vol]; i=ids.index(d); c,s,_,_=shard(vol); return c[i],s[i]
for anchor in ["frus1917-72PubDipv08/d31","frus1969-76v38p2/d105"]:
    v,d=anchor.split("/"); ar=row_of[(v,d)]
    h=ham(ar); h[ar]=10**6
    pool=np.argsort(h,kind="stable")[:800]
    print("\nANCHOR",anchor,"row",ar,"| pure-Hamming top 10:",[(doc_of[int(r)][0]+"/"+doc_of[int(r)][1],int(h[r])) for r in pool[:10]])
    qa,qs=vec((v,d)); out=[]
    for r in pool:
        key=doc_of[int(r)]
        if key[0] in ED2: continue
        cc,ss=vec(key); out.append((float(qs*ss*np.dot(qa,cc)),key,int(h[r])))
    out.sort(reverse=True)
    sz=cache[v]; print("  anchor shard: file",sz[2],"bytes; 64+n*d+4n =",sz[3])
    print("  rerank top 10 (cos, hamming, calibrated):")
    for cos,key,hh in out[:10]: print("   %s/%s  ham %d  cos %.3f  cal %.3f"%(key[0],key[1],hh,cos,(cos-0.40)/0.60))
    print("  shards touched:",len(cache))
# baselines re-run (same seed) for comparison with vec.out
import random
rng=random.Random(1877); pr=[(rng.randrange(docs),rng.randrange(docs)) for _ in range(20000)]
a=np.array([p[0] for p in pr]); b=np.array([p[1] for p in pr])
rp=POP[np.bitwise_xor(signs[a],signs[b])].sum(axis=1,dtype=np.int32)
print("\nrandom pairs (seed 1877, 20000): mean %.1f sd %.1f p1 %d min %d"%(rp.mean(),rp.std(),np.percentile(rp,1),rp.min()))
print("retrieval block:",json.dumps(idx.get("retrieval"),ensure_ascii=False)[:400])
