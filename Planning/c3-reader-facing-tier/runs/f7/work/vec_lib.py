import json,struct,numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+"semantic-vectors-index.json"))
def numeric_part(d):
    if not d.startswith("d"): return None
    s=d[1:]
    if not s or not s.isdigit(): return None
    if len(s)>1 and s[0]=="0": return None
    return int(s)
def decode(segs):
    ids=[]
    for sg in segs:
        assert sg["s"]==len(ids)
        ids.append(sg["i"])
        if sg["n"]>1:
            b=numeric_part(sg["i"])
            ids.extend("d%d"%(b+k) for k in range(1,sg["n"]))
    return ids
vols=idx["volumes"]
row_of={};doc_of=[None]*idx["documentCount"];vol_off={}
for v in vols:
    ids=decode(v["seg"]); assert len(ids)==v["n"],v["v"]
    vol_off[v["v"]]=(v["r"],v["n"])
    for k,d in enumerate(ids):
        row_of[(v["v"],d)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],d)
blob=np.fromfile(R+"semantic-vectors-binary.bin",dtype=np.uint8)
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20].tobytes())
bpr=dims//8
signs=blob[64:64+docs*bpr].reshape(docs,bpr)
cstart=64+docs*bpr
cblock=blob[cstart:cstart+cents*(dims+4)].reshape(cents,dims+4)
ccodes=cblock[:,:dims].view(np.int8).astype(np.float32)
cscale=np.ascontiguousarray(cblock[:,dims:]).view(np.float32).reshape(-1)
cvec=ccodes*cscale[:,None]
def ham_all(row):
    return np.bitwise_count(np.bitwise_xor(signs,signs[row])).sum(axis=1).astype(np.int32)
def shard(vol):
    b=np.fromfile("/Users/jbotts/frus-analysis/c3/SemanticVectors/%s.vec"%vol,dtype=np.uint8)
    n=struct.unpack("<I",b[12:16].tobytes())[0]
    codes=b[64:64+n*dims].reshape(n,dims).view(np.int8)
    sc=b[64+n*dims:64+n*dims+n*4].view(np.float32)
    return codes,sc
_cache={}
def vec(row):
    # find volume
    for v in vols:
        if v["r"]<=row<v["r"]+v["n"]:
            vn=v["v"];k=row-v["r"];break
    if vn not in _cache: _cache[vn]=shard(vn)
    c,s=_cache[vn]
    return c[k].astype(np.float32)*s[k]
