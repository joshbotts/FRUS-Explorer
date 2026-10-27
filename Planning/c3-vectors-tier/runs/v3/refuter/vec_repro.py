# Independent re-implementation: decode §A.3 run-length ids from the index, read the sign block, recompute k=15 Hamming neighbours.
import json, struct, heapq, time, sys
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ix=json.load(open(R+"semantic-vectors-index.json"))
blob=open(R+"semantic-vectors-binary.bin","rb").read()
magic=blob[:4]; ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); digest=blob[20:52].hex()
print("magic",magic,"ver",ver,"dims",dims,"docs",docs,"centroids",cents)
print("binary digest == index provenanceDigest:", digest==ix["provenanceDigest"], digest[:16])
mapb=open(R+"semantic-map.bin","rb").read()
print("map digest == index:", mapb[20:52].hex()==ix["provenanceDigest"], "map header docs/clusters", struct.unpack("<II",mapb[8:16]))
# shards
import os
sd="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
n=0; bad=0
for f in os.listdir(sd):
    if f.endswith(".vec"):
        n+=1
        with open(sd+f,"rb") as fh: h=fh.read(64)
        if h[16:48].hex()!=ix["provenanceDigest"]: bad+=1
print("shards:",n,"with a different digest:",bad, "| .generation:", open(sd+".generation").read().strip()[:64] if os.path.exists(sd+".generation") else "absent")
# A.3 decode: each volume has rows r..r+n-1; seg = [{s: start offset within volume, i: first id, n: run length}], ids within a run are d<base+k>
def decode(vol):
    ids=[]
    for seg in vol["seg"]:
        if seg["s"]!=len(ids): raise ValueError(("segment start mismatch",vol["v"],seg))
        first=seg["i"]; ids.append(first)
        if seg["n"]>1:
            base=int(first[1:])
            ids.extend("d%d"%(base+k) for k in range(1,seg["n"]))
    return ids
row_of={}; doc_of={}
okvols=0
for v in ix["volumes"]:
    ids=decode(v)
    if len(ids)!=v["n"]: print("LENGTH MISMATCH",v["v"],len(ids),v["n"]); continue
    okvols+=1
    for i,d in enumerate(ids):
        row_of[(v["v"],d)]=v["r"]+i; doc_of[v["r"]+i]=(v["v"],d)
print("volumes decoded with length == n:",okvols,"of",len(ix["volumes"]),"rows mapped:",len(row_of), "documentCount", ix["documentCount"])
bpr=dims//8; base=64
assert base+docs*bpr <= len(blob)
S=[int.from_bytes(blob[base+r*bpr:base+(r+1)*bpr],"big") for r in range(docs)]
def knn(row,k):
    q=S[row]; best=[]
    for r,s in enumerate(S):
        if r==row: continue
        d=bin(q^s).count("1")
        if len(best)<k: heapq.heappush(best,(-d,-r))
        elif -best[0][0]>d: heapq.heapreplace(best,(-d,-r))
    return sorted([(-a,-b) for a,b in best])
for anchor in [("frus1969-76ve10","d205"),("frus1958-60v06","d499")]:
    t=time.time(); nn=knn(row_of[anchor],15)
    print(f"ANCHOR {anchor[0]}/{anchor[1]} ({time.time()-t:.1f}s)")
    for d,r in nn: print(f"  ham {d:3d} {doc_of[r][0]}/{doc_of[r][1]}")
a=row_of[("frus1881","d405")]; b=row_of[("frus1894app2","d394")]
print("Hamming frus1881/d405 vs frus1894app2/d394:", bin(S[a]^S[b]).count("1"))
a=row_of[("frus1961-63v10-12mSupp","d729")]; b=row_of[("frus1969-76ve10","d205")]
print("Hamming d729 vs d205:", bin(S[a]^S[b]).count("1"))
print("frus1898/ch83 in index:", ("frus1898","ch83") in row_of, "| frus1898 ids sample:", [d for (v,d) in row_of if v=="frus1898" and not d.startswith("d")][:5])
