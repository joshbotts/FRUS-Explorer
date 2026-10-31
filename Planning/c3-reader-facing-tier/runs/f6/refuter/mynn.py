# Independent re-run of one neighbour list from the bundle's binary (A.3 decode of the index's id segments)
import json,struct,sys
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json"))
print("index keys:",list(idx.keys()))
print("sample volume entry:",idx["volumes"][0])
print("segment keys of a multi-segment volume:",[v for v in idx["volumes"] if len(v["seg"])>1][0])
def expand(seg):
    out=[]
    for s in seg:
        assert s["s"]==len(out), (s, len(out))
        first=s["i"]; out.append(first)
        if s["n"]>1:
            m=__import__("re").fullmatch(r"d([1-9]\d*)",first)
            assert m, ("run on a non-numeric id", s)
            b=int(m.group(1)); out+= [f"d{b+k}" for k in range(1,s["n"])]
    return out
row_of={}; doc_of={}
for v in idx["volumes"]:
    ids=expand(v["seg"]); assert len(ids)==v["n"], (v["v"],len(ids),v["n"])
    for k,i in enumerate(ids):
        row_of[(v["v"],i)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],i)
assert len(doc_of)==idx["documentCount"]
hdr=open(R+"semantic-vectors-binary.bin","rb").read(64)
ver,dims,docs,cents=struct.unpack("<IIII",hdr[4:20]); assert hdr[20:52].hex()==idx["provenanceDigest"]
bpr=dims//8
signs=np.fromfile(R+"semantic-vectors-binary.bin",dtype=np.uint8,offset=64,count=docs*bpr).reshape(docs,bpr)
anchor=tuple(sys.argv[1].split("/"))
r=row_of[anchor]
ham=np.unpackbits(np.bitwise_xor(signs,signs[r]),axis=1).sum(axis=1)
ham[r]=1<<30
order=np.argsort(ham,kind="stable")[:800]
print("anchor",anchor,"row",r,"Hamming top-800 cutoff",int(ham[order[-1]]),"min",int(ham[order[0]]))
# shard rerank: int8 codes + float32 scale per row
_cache={}
def shard(v):
    if v not in _cache:
        b=np.fromfile(SH+v+".vec",dtype=np.uint8)
        magic=bytes(b[:4]); sd,n=struct.unpack("<II",bytes(b[8:16]))
        dig=bytes(b[16:48]).hex(); assert dig==idx["provenanceDigest"],(v,dig)
        codes=b[64:64+n*sd].view(np.int8).reshape(n,sd); sc=b[64+n*sd:64+n*sd+4*n].view(np.float32)
        _cache[v]=(codes,sc,magic)
    return _cache[v]
vol_r={v["v"]:v["r"] for v in idx["volumes"]}
def vec(row):
    v,i=doc_of[row]; codes,sc,_=shard(v); k=row-vol_r[v]; return codes[k].astype(np.float32)*sc[k]
q=vec(r); res=[]
for c in order:
    c=int(c); res.append((float(np.dot(q,vec(c))),int(ham[c]),doc_of[c]))
res.sort(key=lambda t:-t[0])
print("shard magic:",shard(anchor[0])[2], "dims", shard(anchor[0])[0].shape)
print("TOP 15 by int8 cosine (cos, ham, calibrated (cos-0.40)/0.60, pair):")
for cs,h,p in res[:15]:
    print(f"  cos {cs:.3f} ham {h:3d} cal {100*(cs-0.40)/0.60:.0f}% {p[0]}/{p[1]}")
json.dump([[cs,h,p[0],p[1]] for cs,h,p in res[:15]],open("mynn_"+anchor[0]+"_"+anchor[1]+".json","w"))
