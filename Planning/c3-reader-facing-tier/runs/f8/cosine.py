import json,struct,numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"; SD="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json")); D=idx["provenanceDigest"]
def num(i):
    g=i[1:] if i.startswith("d") else ""
    return int(g) if g.isdigit() and not (len(g)>1 and g[0]=="0") else None
def ids(v):
    out=[]
    for s in v["seg"]:
        out.append(s["i"])
        if s["n"]>1: out.extend(f"d{num(s['i'])+k}" for k in range(1,s["n"]))
    return out
vol={v["v"]:v for v in idx["volumes"]}
def vec(v,d):
    b=open(SD+v+".vec","rb").read(); assert b[:4]==b"FRSS" and b[16:48].hex()==D
    ver,dims,n=struct.unpack("<III",b[4:16]); k=ids(vol[v]).index(d); assert n==vol[v]["n"]
    codes=np.frombuffer(b,dtype=np.int8,count=dims,offset=64+k*dims).astype(np.float64)
    scale=struct.unpack("<f",b[64+n*dims+4*k:64+n*dims+4*k+4])[0]
    return codes*scale
off=idx["retrieval"]["scoreCalibration"]["documentOffset"]
for a,b in [("frus1917-72PubDipv08/d31","frus1952-54v13p1/d116"),("frus1917-72PubDipv08/d31","frus1955-57v22/d275"),("frus1969-76v38p2/d105","frus1969-76ve12/d10")]:
    x=vec(*a.split("/")); y=vec(*b.split("/")); cos=float(x@y)
    print(a,b,"raw cosine %.3f calibrated (cos-%.2f)/%.2f = %.3f"%(cos,off,1-off,(cos-off)/(1-off)))
