# Tier-2 int8 cosine (raw and calibrated with documentOffset) for same-volume pairs; ids from index segments
import json, struct, numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"; SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json")); dig=idx["provenanceDigest"]; off=idx["retrieval"]["scoreCalibration"]["documentOffset"]
def ids_of(v):
    ids=[]
    for s in v["seg"]:
        ids.append(s["i"])
        if s["n"]>1: ids.extend(f"d{int(s['i'][1:])+k}" for k in range(1,s["n"]))
    return ids
vols={(v.get("id") or v.get("v")):v for v in idx["volumes"]}
def load(vid):
    b=open(SH+vid+".vec","rb").read(); assert b[:4]==b"FRSS"; dims,n=struct.unpack("<II",b[8:16]); assert b[16:48].hex()==dig, "digest mismatch "+vid
    codes=np.frombuffer(b,dtype=np.int8,count=n*dims,offset=64).reshape(n,dims).astype(np.float32)
    sc=np.frombuffer(b,dtype=np.float32,count=n,offset=64+n*dims)
    return {d:i for i,d in enumerate(ids_of(vols[vid]))}, codes*sc[:,None]
for vid,a,b in [("frus1969-76ve09p2","d122","d155"),("frus1969-76ve09p2","d122","d107"),("frus1947v07","d628","d617"),("frus1947v07","d628","d582")]:
    m,X=load(vid); c=float(X[m[a]]@X[m[b]]); print(vid,a,b,"raw cosine %.3f calibrated %.3f"%(c,(c-off)/(1-off)))
