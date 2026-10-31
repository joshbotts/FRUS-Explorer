import json,struct,os,numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"; SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
ix=json.load(open(R+"semantic-vectors-index.json"))
print("index keys:",[k for k in ix if k!="volumes"]); print("schema:",json.dumps(ix.get("schema"))[:1500])
print("documentCount:",ix.get("documentCount"),"digest:",ix["provenanceDigest"])
v0=ix["volumes"][0]; print("volumes[0] keys:",list(v0.keys()),"| r,n,v:",v0.get("r"),v0.get("n"),v0.get("v"),"| seg[:3]:",v0["seg"][:3])
blob=open(R+"semantic-vectors-binary.bin","rb").read()
magic=blob[:4]; ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); dig=blob[20:52].hex()
print("binary: magic",magic,"version",ver,"dims",dims,"docs",docs,"centroids",cents,"digest",dig,"size",len(blob),"expected rows end",64+docs*(dims//8),"trailer",len(blob)-(64+docs*(dims//8)))
assert dig==ix["provenanceDigest"]
# §A.3-style decode of the run-length document ids from the index's own segments
def numeric_part(i):
    g=i[1:] if i.startswith("d") else ""
    return int(g) if g.isdigit() and not (len(g)>1 and g[0]=="0") else None
row_of={}; doc_of={}; ok=0
for vol in ix["volumes"]:
    ids=[]
    for seg in vol["seg"]:
        assert seg["s"]==len(ids), (vol["v"],seg); ids.append(seg["i"])
        if seg["n"]>1:
            b=numeric_part(seg["i"]); assert b is not None
            ids.extend("d%d"%(b+k) for k in range(1,seg["n"]))
    assert len(ids)==vol["n"]; ok+=1
    for k,d in enumerate(ids): row_of[(vol["v"],d)]=vol["r"]+k; doc_of[vol["r"]+k]=(vol["v"],d)
print("decode round trip volumes",ok,"rows",len(doc_of),"== documentCount",len(doc_of)==docs)
bpr=dims//8
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
def shard(vid):
    b=open(SH+vid+".vec","rb").read(); assert b[:4]==b"FRSS"
    f4=struct.unpack("<I",b[4:8])[0]; sd,n=struct.unpack("<II",b[8:16]); dg=b[16:48].hex(); assert dg==ix["provenanceDigest"],vid
    codes=np.frombuffer(b,np.int8,n*sd,64).reshape(n,sd).astype(np.int32); sc=np.frombuffer(b,np.float32,n,64+n*sd)
    return codes,sc,(f4,sd,n,len(b),64+n*sd+4*n)
codes,sc,hdr=shard("frus1961-63v22"); print("shard frus1961-63v22 header: field4",hdr[0],"dims",hdr[1],"n",hdr[2],"size",hdr[3],"expected 64+n*dims+4n",hdr[4])
# layout cross-check: sign bits of the shard's int8 codes vs the binary's rows for this volume, both bit orders
vol=[v for v in ix["volumes"] if v["v"]=="frus1961-63v22"][0]; r0=vol["r"]
signs=(codes>=0).astype(np.uint8)
for order,name in ((None,"MSB-first"),("little","LSB-first")):
    packed=np.packbits(signs,axis=1,bitorder="big" if order is None else "little")
    agree=(packed==S[r0:r0+vol["n"]]).all(axis=1).mean()
    print("sign-bit agreement shard vs binary rows,",name,": %.4f"%agree)
def neighbours(anchor,k=10):
    v,d=anchor.split("/"); r=row_of[(v,d)]
    dd=np.bitwise_count(S^S[r]).sum(1).astype(np.int64); dd[r]=99999
    pool=np.argsort(dd,kind="stable")[:800]
    cq,sq,_=shard(v); kq=r-r0 if v=="frus1961-63v22" else r-[x for x in ix["volumes"] if x["v"]==v][0]["r"]
    cache={}
    def vec(row):
        vv,dd_=doc_of[row]
        if vv not in cache: cache[vv]=shard(vv)[:2]
        c,s=cache[vv]; kk=row-[x for x in ix["volumes"] if x["v"]==vv][0]["r"]; return c[kk],s[kk]
    qv=vec(r); res=[]
    for c in pool:
        x=vec(int(c)); cos=float(qv[1]*x[1]*np.dot(qv[0],x[0])); res.append((cos,int(dd[c]),int(c)))
    res.sort(key=lambda t:(-t[0],t[1]))
    print("== anchor",anchor,"min hamming",int(dd.min()),"| pure-Hamming top10:",[("%s/%s"%doc_of[int(c)],int(dd[c])) for c in pool[:10]])
    for cos,h,c in res[:k]: print("   ham %3d cos_raw %.3f cal %.3f %s/%s"%(h,cos,(cos-0.4)/0.6,*doc_of[c]))
    return res[:k]
for a in ["frus1961-63v22/d202","frus1964-68v05/d258","frus1969-76ve15p2/d292"]: neighbours(a)
print("== near-duplicate minima (min Hamming to any other row)")
for p in "frus1875v01/d199 frus1875v02/d393 frus1947v07/d582 frus1948v07/d43 frus1961-63v22/d202 frus1961-63v22/d204 frus1964-68v04/d215 frus1964-68v05/d258 frus1969-76ve12/d218 frus1969-76ve15p2/d292 frus1977-80v03/d152".split():
    v,d=p.split("/"); r=row_of[(v,d)]; dd=np.bitwise_count(S^S[r]).sum(1); dd[r]=9999; m=int(dd.argmin()); print("  ",p,int(dd[m]),doc_of[m])
# baseline: random pairs with the same seed as the memo, and 25th-neighbour over the same 200-sample
import random
rnd=random.Random(1877); P=[(rnd.randrange(docs),rnd.randrange(docs)) for _ in range(20000)]
a=np.array([p[0] for p in P]); b=np.array([p[1] for p in P]); dd=np.bitwise_count(S[a]^S[b]).sum(1)
print("random pairs: mean %.1f sd %.1f p1 %d min %d"%(dd.mean(),dd.std(),np.percentile(dd,1),dd.min()))
smp=random.Random(1877).sample(range(docs),200); k25=[]; k1=[]
for r in smp:
    e=np.bitwise_count(S^S[r]).sum(1); e[r]=9999; s=np.sort(e); k25.append(s[24]); k1.append(s[0])
print("25th-neighbour over 200: median %d q1 %d q3 %d; 1st median %d"%(np.median(k25),np.percentile(k25,25),np.percentile(k25,75),np.median(k1)))
