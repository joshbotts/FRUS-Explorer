import json, struct, hashlib, os
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SV="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
out=[]
def p(s): out.append(str(s)); print(s, flush=True)
idx=json.load(open(R+"semantic-vectors-index.json"))
man=json.load(open(R+"semantic-shards-manifest.json"))
gen=open(SV+".generation").read().strip()
def find(o,key):
    if isinstance(o,dict):
        for k,v in o.items():
            if k==key: return v
            r=find(v,key)
            if r is not None: return r
    return None
d_idx=find(idx,"provenanceDigest"); d_man=find(man,"provenanceDigest") or find(man,"digest")
p("index provenanceDigest: %s"%d_idx)
p("manifest provenanceDigest: %s"%d_man)
p(".generation: %s"%gen)
blob=open(R+"semantic-vectors-binary.bin","rb").read()
magic=blob[:4].decode(); ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bd=blob[20:52].hex()
p("binary: magic=%s version=%d dims=%d docs=%d centroids=%d digest@20=%s"%(magic,ver,dims,docs,cents,bd))
def numeric_part(doc_id):
    if not doc_id.startswith("d"): return None
    digits=doc_id[1:]
    if not digits or not digits.isdigit(): return None
    if len(digits)>1 and digits[0]=="0": return None
    return int(digits)
def decode_segments(segments):
    ids=[]
    for seg in segments:
        assert seg["s"]==len(ids)
        ids.append(seg["i"])
        if seg["n"]>1:
            base=numeric_part(seg["i"])
            ids.extend("d%d"%(base+k) for k in range(1,seg["n"]))
    return ids
vols=idx["volumes"]
ok=0; row_of={}; doc_of={}
for v in vols:
    vid=v.get("id") or v.get("v") or v.get("volumeId")
    ids=decode_segments(v["seg"])
    if len(ids)==v["n"]: ok+=1
    for i,d in enumerate(ids):
        row_of[(vid,d)]=v["r"]+i; doc_of[v["r"]+i]=(vid,d)
p("volumes decoded to n: %d of %d"%(ok,len(vols)))
anchor=row_of[("frus1861","d111")]
p("row of frus1861/d111: %d"%anchor)
bpr=dims//8
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
dist=np.bitwise_count(S^S[anchor]).sum(axis=1).astype(np.int64)
dist[anchor]=10**9
order=np.lexsort((np.arange(docs),dist))[:10]
p("ten nearest neighbours of frus1861/d111:")
for r in order: p("hamming %d %s/%s"%(dist[r],*doc_of[int(r)]))
sh=open(SV+"frus1861.vec","rb").read()
smag=sh[:4].decode(); sver,sdims,sdocs=struct.unpack("<III",sh[4:16]); sdig=sh[16:48].hex()
p("frus1861.vec: magic=%s version=%d dims=%d docs=%d digest@16=%s"%(smag,sver,sdims,sdocs,sdig))
rows=man.get("shards") or man.get("volumes") or find(man,"shards")
row=[x for x in rows if "frus1861" in (x.get("volume"),x.get("id"),x.get("v"),x.get("volumeId"),x.get("volumeID"))]
p("manifest row: %s"%json.dumps(row[0] if row else None))
sha=hashlib.sha256(sh).hexdigest(); size=len(sh)
r0=row[0] if row else {}
msha=r0.get("sha256"); msize=r0.get("size") or r0.get("bytes") or r0.get("byteCount")
p("frus1861.vec sha256=%s size=%d; matches manifest sha256: %s, size: %s"%(sha,size,sha==msha,size==msize))
p("digests agree (index/binary/shard/generation): %s"%(len({d_idx,bd,sdig})==1 and gen.startswith(d_idx[:8])))
open("/Users/jbotts/frus-analysis/c3f/runs/canary/canary.txt","a").write("\n".join(out)+"\n")
