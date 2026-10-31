import json,struct,numpy as np
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
ix=json.load(open(RES+"semantic-vectors-index.json"))
def np_(i):
    s=i[1:]; return int(s) if i.startswith("d") and s.isdigit() and not (len(s)>1 and s[0]=="0") else None
row_of={}
for v in ix["volumes"]:
    ids=[]
    for seg in v["seg"]:
        ids.append(seg["i"])
        if seg["n"]>1: b=np_(seg["i"]); ids+=["d%d"%(b+k) for k in range(1,seg["n"])]
    for k,i in enumerate(ids): row_of[(v["v"],i)]=v["r"]+k
mp=open(RES+"semantic-map.bin","rb").read()
n=struct.unpack("<I",mp[8:12])[0]
pl=np.frombuffer(mp,dtype=np.dtype([("x","<i2"),("y","<i2"),("c","<u2")]),count=n,offset=64)
mi=json.load(open(RES+"semantic-map-index.json")); cl={c["id"]:c for c in mi["clusters"]}
unc=(pl["c"]==0xFFFF).sum(); print("unclustered",unc,"of",n,"(%.1f%%) (memo 88,059 of 314,616, 28.0%%)"%(100*unc/n))
coll=json.load(open("/Users/jbotts/frus-analysis/c3f/runs/f10/refuter/pairs.json"))["docs"]
import collections; cc=collections.Counter()
for v,d in coll:
    c=int(pl["c"][row_of[(v,d)]]); cc["UNCL" if c==0xFFFF else c]+=1
    if (v,d) in [("frus1917-72PubDipv07","d73"),("frus1964-68v26","d106"),("frus1950v06","d32"),("frus1917-72PubDipv08","d31"),("frus1952-54v13p1","d116"),("frus1917-72PubDipv07","d32"),("frus1977-80v30","d79"),("frus1917-72PubDipv06","d107"),("frus1917-72PubDipv08","d34"),("frus1917-72PubDipv06","d127")]:
        print(" ",v+"/"+d,"cluster",("UNCLUSTERED" if c==0xFFFF else c),(cl[c]["terms"] if c!=0xFFFF else ""))
print("30 docs clusters:",dict(cc),"(memo: 6 unclustered; 29:10, 138:5, 32:4, 3:3, 31:1, 7:1)")
print("cluster 138 size:",cl[138]["documentCount"],cl[138]["terms"],"(memo 2,189)")
