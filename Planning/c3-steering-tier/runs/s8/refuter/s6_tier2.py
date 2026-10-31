import json, struct, numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"; SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json")); dig=idx["provenanceDigest"]; off=idx["retrieval"]["scoreCalibration"]["documentOffset"]
vols={v["v"]:v for v in idx["volumes"]}
def ids_of(v):
    out=[]
    for s in v["seg"]:
        out.append(s["i"])
        if s["n"]>1: out.extend("d%d"%(int(s["i"][1:])+k) for k in range(1,s["n"]))
    return out
def load(vid):
    b=open(SH+vid+".vec","rb").read(); assert b[:4]==b"FRSS", b[:4]; dims,n=struct.unpack("<II",b[8:16]); assert b[16:48].hex()==dig
    assert len(b)==64+n*dims+4*n, (len(b),64+n*dims+4*n)
    codes=np.frombuffer(b,dtype=np.int8,count=n*dims,offset=64).reshape(n,dims).astype(np.float32)
    sc=np.frombuffer(b,dtype=np.float32,count=n,offset=64+n*dims)
    return {d:i for i,d in enumerate(ids_of(vols[vid]))}, codes*sc[:,None], n, dims
for vid,a,b in [("frus1969-76ve09p2","d122","d155"),("frus1969-76ve09p2","d122","d107"),("frus1947v07","d628","d617"),("frus1947v07","d628","d582")]:
    m,X,n,dims=load(vid); assert n==vols[vid]["n"]
    c=float(X[m[a]]@X[m[b]]); print(vid,a,b,"n=%d dims=%d raw cosine %.3f calibrated %.3f"%(n,dims,c,(c-off)/(1-off)), "| norms %.3f %.3f"%(np.linalg.norm(X[m[a]]),np.linalg.norm(X[m[b]])))
