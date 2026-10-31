# vec.py: semantic vector helpers (Appendix A). Identity only from index segments.
import json, struct, numpy as np, random, os
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
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
            ids.extend(f"d{b+k}" for k in range(1,sg["n"]))
    return ids
row_of={}; doc_of=[None]*idx["documentCount"]; vol_rows={}
for v in idx["volumes"]:
    ids=decode(v["seg"]); assert len(ids)==v["n"], v["v"]
    vol_rows[v["v"]]=(v["r"],v["n"])
    for k,d in enumerate(ids):
        row_of[(v["v"],d)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],d)
blob=np.fromfile(R+"semantic-vectors-binary.bin",dtype=np.uint8)
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20].tobytes())
digest_bin=blob[20:52].tobytes().hex()
bpr=dims//8
signs=blob[64:64+docs*bpr].reshape(docs,bpr)
def hamming_all(row):
    return np.bitwise_count(signs ^ signs[row]).sum(axis=1).astype(np.int32)
def cent_block():
    o=64+docs*bpr
    cb=blob[o:o+cents*(dims+4)].reshape(cents,dims+4)
    codes=cb[:,:dims].view(np.int8).astype(np.float32)
    scales=cb[:,dims:].copy().view(np.float32).reshape(-1)
    return codes*scales[:,None]
def shard(vol):
    b=np.fromfile(SH+vol+".vec",dtype=np.uint8)
    magic=b[:4].tobytes(); ver,d,n=struct.unpack("<III",b[4:16].tobytes())
    dig=b[16:48].tobytes().hex()
    codes=b[64:64+n*d].reshape(n,d).view(np.int8)
    scales=b[64+n*d:64+n*d+n*4].copy().view(np.float32)
    return dig,codes,scales
