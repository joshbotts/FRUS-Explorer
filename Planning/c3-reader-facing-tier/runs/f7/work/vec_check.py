import json,struct,glob,os
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+"semantic-vectors-index.json"))
print(list(idx.keys()))
for k,v in idx.items():
    if k not in("volumes","subseries"): print(k, str(v)[:400])
print("volumes type",type(idx["volumes"]), len(idx["volumes"]))
v=idx["volumes"]
first=v[0] if isinstance(v,list) else list(v.items())[0]
print(str(first)[:400])
dig=idx["provenanceDigest"]
b=open(R+"semantic-vectors-binary.bin","rb").read(64)
print("bin magic",b[:4],struct.unpack("<IIII",b[4:20]),b[20:52].hex()==dig)
m=open(R+"semantic-map.bin","rb").read(64)
print("map magic",m[:4],struct.unpack("<IIII",m[4:20]),m[20:52].hex()==dig)
bad=0;n=0
for f in sorted(glob.glob("/Users/jbotts/frus-analysis/c3/SemanticVectors/*.vec")):
    h=open(f,"rb").read(64); n+=1
    if h[16:48].hex()!=dig: bad+=1
print("shards",n,"digest mismatches",bad)
print("generation file",open("/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation").read() if os.path.exists("/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation") else "none")
