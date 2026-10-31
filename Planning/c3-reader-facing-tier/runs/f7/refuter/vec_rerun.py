# Independent decode of the bundle (layout read from the file headers and the index's segments), no import of the session's code.
import json,struct,numpy as np,hashlib,os
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json"))
# A.3 decode: each segment {"s": start offset within the volume, "i": first document id, "n": run length}; ids after the first are d<N+k>
def decode_volume(v):
    ids=[]
    for sg in v["seg"]:
        assert sg["s"]==len(ids),(v["v"],sg)
        first=sg["i"]; ids.append(first)
        if sg["n"]>1:
            assert first.startswith("d") and first[1:].isdigit(),(v["v"],first)
            base=int(first[1:])
            ids+=[f"d{base+k}" for k in range(1,sg["n"])]
    assert len(ids)==v["n"],(v["v"],len(ids),v["n"])
    return ids
row_of={};doc_of={}
for v in idx["volumes"]:
    for k,d in enumerate(decode_volume(v)):
        row_of[(v["v"],d)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],d)
print("decoded rows:",len(doc_of),"index documentCount:",idx["documentCount"],"volumes:",len(idx["volumes"]))
raw=open(R+"semantic-vectors-binary.bin","rb").read()
magic=raw[:4]; ver,dims,ndocs,ncents=struct.unpack("<IIII",raw[4:20]); digest=raw[20:52].hex()
print("binary:",magic,ver,dims,ndocs,ncents,"digest==index:",digest==idx["provenanceDigest"])
mp=open(R+"semantic-map.bin","rb").read(64); print("map digest==index:",mp[20:52].hex()==idx["provenanceDigest"])
mism=0
for f in os.listdir(SH):
    if f.endswith(".vec"):
        h=open(SH+f,"rb").read(48)
        if h[16:48].hex()!=idx["provenanceDigest"]: mism+=1
print("shards:",len([f for f in os.listdir(SH) if f.endswith('.vec')]),"digest mismatches:",mism)
bpr=dims//8
signs=np.frombuffer(raw,dtype=np.uint8,count=ndocs*bpr,offset=64).reshape(ndocs,bpr)
def hamming_all(r): return np.unpackbits(np.bitwise_xor(signs,signs[r]),axis=1).sum(axis=1)
shcache={}
def shard_vec(vol,k):
    if vol not in shcache:
        b=open(SH+vol+".vec","rb").read()
        m,ver,d,n=b[:4],*struct.unpack("<III",b[4:16])
        assert m==b"FRSS" and d==dims
        codes=np.frombuffer(b,dtype=np.int8,count=n*dims,offset=64).reshape(n,dims)
        scales=np.frombuffer(b,dtype=np.float32,count=n,offset=64+n*dims)
        shcache[vol]=(codes,scales)
    codes,scales=shcache[vol]
    return codes[k].astype(np.float32)*scales[k]
vol_r={v["v"]:(v["r"],v["n"]) for v in idx["volumes"]}
def vec_of_row(r):
    v,d=doc_of[r]; r0,n=vol_r[v]; return shard_vec(v,r-r0)
def neighbours(anchor,k=12,pool=800):
    v,d=anchor.split("/"); r=row_of[(v,d)]
    h=hamming_all(r).astype(np.int64); h[r]=10**6
    cand=np.argsort(h,kind="stable")[:pool]
    qa=vec_of_row(r); qa=qa/np.linalg.norm(qa)
    sc=[]
    for c in cand:
        cv=vec_of_row(int(c)); sc.append(float(np.dot(qa,cv/np.linalg.norm(cv))))
    sc=np.array(sc); order=np.argsort(-sc,kind="stable")[:k]
    out=[]
    for o in order:
        c=int(cand[o]); out.append((doc_of[c],int(h[c]),round(sc[o],3),round((sc[o]-0.40)/0.60,3)))
    return out
for a in ["frus1917-72PubDipv08/d31","frus1964-68v29p2/d123"]:
    print("ANCHOR",a)
    for (vd,h,c,cal) in neighbours(a): print(f"   ham {h:3d} cos {c:.3f} cal {cal:.3f}  {vd[0]}/{vd[1]}")
# raw (un-normalised) dot like the session's vec2.py, for the first anchor, to see whether their numbers depend on it
v,d="frus1917-72PubDipv08","d31"; r=row_of[(v,d)]
h=hamming_all(r).astype(np.int64); h[r]=10**6; cand=np.argsort(h,kind="stable")[:800]
qa=vec_of_row(r); sc=np.array([float(np.dot(qa,vec_of_row(int(c)))) for c in cand]); order=np.argsort(-sc,kind="stable")[:12]
print("ANCHOR frus1917-72PubDipv08/d31 with RAW int8 dot (session's method):")
for o in order: c=int(cand[o]); print(f"   ham {h[c]:3d} dot {sc[o]:.3f} cal {(sc[o]-0.40)/0.60:.3f}  {doc_of[c][0]}/{doc_of[c][1]}")
print("norm of anchor vec:",float(np.linalg.norm(qa)))
