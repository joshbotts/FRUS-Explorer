import json, struct, numpy as np, os, glob, random
R="/Applications/FRUS Explorer.app/Contents/Resources"
SV="/Users/jbotts/frus-analysis/c3/SemanticVectors"
ix=json.load(open(R+"/semantic-vectors-index.json"))
def numeric_part(i):
    if not i.startswith("d"): return None
    dg=i[1:]
    if not dg or not dg.isdigit(): return None
    if len(dg)>1 and dg[0]=="0": return None
    return int(dg)
def decode(segs):
    ids=[]
    for s in segs:
        assert s["s"]==len(ids)
        ids.append(s["i"])
        if s["n"]>1:
            b=numeric_part(s["i"])
            ids.extend("d%d"%(b+k) for k in range(1,s["n"]))
    return ids
row_of={}; doc_of=[None]*ix["documentCount"]; vol_rows={}
for v in ix["volumes"]:
    ids=decode(v["seg"]); assert len(ids)==v["n"]
    vol_rows[v["v"]]=(v["r"],v["n"],ids)
    for k,i in enumerate(ids):
        row_of[(v["v"],i)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],i)
blob=open(R+"/semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
digest_bin=blob[20:52].hex()
bpr=dims//8
signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
def ham_to(row):
    x=np.bitwise_xor(signs,signs[row])
    return np.bitwise_count(x).sum(axis=1).astype(np.int32)
def neighbours(row,k=10):
    d=ham_to(row); d[row]=9999
    idx=np.argpartition(d,k)[:k]
    idx=idx[np.argsort(d[idx],kind="stable")]
    return [(int(d[i]),doc_of[i]) for i in idx]
def checks():
    out={}
    out["index_digest"]=ix["provenanceDigest"]; out["bin_digest"]=digest_bin
    m=open(R+"/semantic-map.bin","rb").read(); out["map_digest"]=m[20:52].hex()
    out["generation_file"]=open(SV+"/.generation").read().strip()
    sh=set(); n=0
    for f in glob.glob(SV+"/*.vec"):
        with open(f,"rb") as fh: h=fh.read(64)
        sh.add(h[16:48].hex()); n+=1
    out["shard_digests"]=sorted(sh); out["shards"]=n
    return out
