import json,struct,glob,os
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
ix=json.load(open(RES+"semantic-vectors-index.json"))
print("index keys:",list(ix.keys()))
for k in ix:
    if k not in("volumes",): print(" ",k,"=",json.dumps(ix[k])[:300])
idx_digest=ix.get("provenanceDigest") or ix.get("digest")
b=open(RES+"semantic-vectors-binary.bin","rb").read(64)
print("binary magic",b[:4],"ver,dims,docs,cents",struct.unpack("<IIII",b[4:20]),"digest",b[20:52].hex())
m=open(RES+"semantic-map.bin","rb").read(64)
print("map magic",m[:4],"hdr",struct.unpack("<IIII",m[4:20]),"digest",m[20:52].hex())
shd=set(); n=0
for p in glob.glob(SH+"*.vec"):
    h=open(p,"rb").read(64); shd.add(h[20:52].hex()); n+=1
print("shards",n,"distinct shard digests",len(shd),list(shd)[:3])
g=glob.glob(SH+"*.generation")+glob.glob(SH+".generation")
for p in g: print("generation file",os.path.basename(p),open(p).read().strip()[:120])
print("index digest",idx_digest)
print("ALL EQUAL:", len(shd)==1 and list(shd)[0]==b[20:52].hex()==m[20:52].hex()==idx_digest)
mi=json.load(open(RES+"semantic-map-index.json"))
print("map-index provenanceDigest",mi.get("provenanceDigest"),"documentCount",mi.get("documentCount"),"clusters",len(mi.get("clusters",[])))
