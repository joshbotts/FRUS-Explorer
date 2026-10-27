import json, struct, heapq, random, hashlib, sys, os
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+"semantic-vectors-index.json"))
def numeric_part(doc_id):
    if not doc_id.startswith("d"): return None
    digits=doc_id[1:]
    if not digits or not digits.isdigit(): return None
    if len(digits)>1 and digits[0]=="0": return None
    return int(digits)
def decode_segments(segs):
    ids=[]
    for seg in segs:
        assert seg["s"]==len(ids)
        ids.append(seg["i"])
        if seg["n"]>1:
            base=numeric_part(seg["i"])
            ids.extend(f"d{base+k}" for k in range(1,seg["n"]))
    return ids
row_of={}; doc_of=[None]*idx["documentCount"]
vol_rows={}
ok=0
for v in idx["volumes"]:
    ids=decode_segments(v["seg"]); assert len(ids)==v["n"]; ok+=1
    vol_rows[v["v"]]=(v["r"],v["n"])
    for i,d in enumerate(ids):
        row_of[(v["v"],d)]=v["r"]+i; doc_of[v["r"]+i]=(v["v"],d)
blob=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bpr=dims//8
bin_digest=blob[20:52].hex()
def sign_int(row):
    o=64+row*bpr; return int.from_bytes(blob[o:o+bpr],"big")
_signs=None
def signs():
    global _signs
    if _signs is None: _signs=[sign_int(r) for r in range(docs)]
    return _signs
def knn(row,k=10):
    S=signs(); q=S[row]; best=[]
    for r in range(docs):
        if r==row: continue
        d=bin(q^S[r]).count("1")
        if len(best)<k: heapq.heappush(best,(-d,r))
        elif -best[0][0]>d: heapq.heapreplace(best,(-d,r))
    return sorted([(-a,b) for a,b in best])
def centroid(i):  # i-th centroid (volume order then subseries)
    o=64+docs*bpr+i*(dims+4)
    codes=struct.unpack(f"<{dims}b",blob[o:o+dims]); sc=struct.unpack("<f",blob[o+dims:o+dims+4])[0]
    return [c*sc for c in codes]
vol_order=[v["v"] for v in idx["volumes"]]
map_blob=open(R+"semantic-map.bin","rb").read()
def map_place(row):
    o=64+row*6; return struct.unpack("<hhH",map_blob[o:o+6])
