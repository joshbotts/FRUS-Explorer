import json,struct,heapq
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SV="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
ix=json.load(open(R+"semantic-vectors-index.json"))
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
row_of={}; doc_of=[None]*ix["documentCount"]; vol_rows={}
for v in ix["volumes"]:
    ids=decode_segments(v["seg"]); assert len(ids)==v["n"]
    vol_rows[v["v"]]=(v["r"],v["n"])
    for k,i in enumerate(ids):
        row_of[(v["v"],i)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],i)
blob=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
digest_bin=blob[20:52].hex()
bpr=dims//8
def sign_row(row):
    o=64+row*bpr; return int.from_bytes(blob[o:o+bpr],"big")
SIGNS=None
def signs():
    global SIGNS
    if SIGNS is None: SIGNS=[sign_row(r) for r in range(docs)]
    return SIGNS
def hamming(a,b): return bin(a^b).count("1")
def neighbours(anchor,k=10):
    S=signs(); q=S[anchor]; best=[]
    for r in range(docs):
        if r==anchor: continue
        d=bin(q^S[r]).count("1")
        if len(best)<k: heapq.heappush(best,(-d,r))
        elif -best[0][0]>d: heapq.heapreplace(best,(-d,r))
    return sorted((-d,r) for d,r in best)
# centroids
def centroid(idx):
    o=64+docs*bpr+idx*(dims+4)
    codes=struct.unpack("<%db"%dims,blob[o:o+dims]); sc=struct.unpack("<f",blob[o+dims:o+dims+4])[0]
    return [c*sc for c in codes]
def cos(a,b):
    na=sum(x*x for x in a)**.5; nb=sum(x*x for x in b)**.5
    return sum(x*y for x,y in zip(a,b))/(na*nb)
