import json, struct, heapq, hashlib, os
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+"semantic-vectors-index.json"))
man=json.load(open(R+"semantic-shards-manifest.json"))
gen=open("/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation").read().strip()
out=[]
def p(*a):
    s=" ".join(str(x) for x in a); print(s); out.append(s)
def find_digest(o):
    if isinstance(o,dict):
        for k,v in o.items():
            if "igest" in k and isinstance(v,str) and len(v)==64: return k,v
        for v in o.values():
            r=find_digest(v)
            if r: return r
    return None
p("index top keys:", list(idx.keys()))
p("index provenanceDigest:", idx.get("provenanceDigest") or find_digest(idx))
p("manifest top keys:", list(man.keys()) if isinstance(man,dict) else type(man))
p("manifest digest:", find_digest(man))
p(".generation:", gen)
blob=open(R+"semantic-vectors-binary.bin","rb").read()
magic=blob[0:4]; ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bdig=blob[20:52].hex()
p("binary magic",magic,"version",ver,"dims",dims,"docs",docs,"centroids",cents,"digest",bdig)
def numeric_part(d):
    if not d.startswith("d"): return None
    g=d[1:]
    if not g or not g.isdigit(): return None
    if len(g)>1 and g[0]=="0": return None
    return int(g)
def decode_segments(segs):
    ids=[]
    for s in segs:
        assert s["s"]==len(ids)
        ids.append(s["i"])
        if s["n"]>1:
            b=numeric_part(s["i"]); ids.extend(f"d{b+k}" for k in range(1,s["n"]))
    return ids
vols=idx["volumes"]
row_of={}; doc_of={}; ok=0
items = vols.items() if isinstance(vols,dict) else [(v.get("id") or v.get("v"),v) for v in vols]
for vid,v in items:
    ids=decode_segments(v["seg"])
    if len(ids)==v["n"]: ok+=1
    for i,d in enumerate(ids):
        row_of[(vid,d)]=v["r"]+i; doc_of[v["r"]+i]=(vid,d)
p("volumes decoded to n:",ok,"of",len(vols))
anchor=row_of[("frus1861","d111")]; p("row of frus1861/d111:",anchor)
bpr=dims//8
def sr(r):
    o=64+r*bpr; return int.from_bytes(blob[o:o+bpr],"big")
q=sr(anchor); best=[]
for r in range(docs):
    if r==anchor: continue
    d=bin(q^sr(r)).count("1")
    if len(best)<10: heapq.heappush(best,(-d,r))
    elif -best[0][0]>d: heapq.heapreplace(best,(-d,r))
for nd,r in sorted(best,key=lambda t:(-t[0],t[1])):
    p("hamming",-nd,"%s/%s"%doc_of[r])
sp="/Users/jbotts/frus-analysis/c3/SemanticVectors/frus1861.vec"
sb=open(sp,"rb").read()
sv,sd,sn=struct.unpack("<III",sb[4:16])
p("shard magic",sb[0:4],"version",sv,"dims",sd,"docs",sn,"digest",sb[16:48].hex())
sha=hashlib.sha256(sb).hexdigest(); size=len(sb)
rows = man.get("shards") or man.get("volumes") if isinstance(man,dict) else man
row=None
if isinstance(rows,dict): row=rows.get("frus1861")
else:
    for x in rows:
        if "frus1861" in (x.get("volume"),x.get("id"),x.get("v")): row=x
p("manifest row frus1861:",row)
p("shard sha256",sha,"size",size)
vals=json.dumps(row)
p("sha matches:",sha in vals,"size matches:",str(size) in vals)
open("/Users/jbotts/frus-analysis/c3v/runs/canary/canary_py.out","w").write("\n".join(out)+"\n")
