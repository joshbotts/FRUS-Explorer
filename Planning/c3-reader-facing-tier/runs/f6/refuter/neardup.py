import json,re
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+"semantic-vectors-index.json"))
def expand(seg):
    out=[]
    for s in seg:
        out.append(s["i"])
        if s["n"]>1:
            b=int(re.fullmatch(r"d([1-9]\d*)",s["i"]).group(1)); out+=[f"d{b+k}" for k in range(1,s["n"])]
    return out
row_of={}
for v in idx["volumes"]:
    for k,i in enumerate(expand(v["seg"])): row_of[(v["v"],i)]=v["r"]+k
signs=np.fromfile(R+"semantic-vectors-binary.bin",dtype=np.uint8,offset=64,count=314616*64).reshape(314616,64)
pairs=[tuple(p) for p in json.load(open("cited_pairs.json"))]
rows=[row_of[p] for p in pairs]
out=[]
for a in range(len(rows)):
    for b in range(a+1,len(rows)):
        out.append((int(np.unpackbits(signs[rows[a]]^signs[rows[b]]).sum()),pairs[a],pairs[b]))
out.sort(); print("pairs",len(out)); [print(o) for o in out[:6]]
