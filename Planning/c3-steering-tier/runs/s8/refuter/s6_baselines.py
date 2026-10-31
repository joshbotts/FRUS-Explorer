import json, struct, random, numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+"semantic-vectors-index.json")); blob=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
rows={}; ids={}
for v in idx["volumes"]:
    out=[]
    for s in v["seg"]:
        out.append(s["i"])
        if s["n"]>1: out.extend("d%d"%(int(s["i"][1:])+k) for k in range(1,s["n"]))
    for k,i in enumerate(out): rows[(v["v"],i)]=v["r"]+k; ids[v["r"]+k]=(v["v"],i)
S=np.frombuffer(blob,dtype=np.uint8,count=docs*(dims//8),offset=64).reshape(docs,dims//8)
POP=np.unpackbits(np.arange(256,dtype=np.uint8)[:,None],axis=1).sum(axis=1)
def ham(q): return POP[np.bitwise_xor(S,S[q])].sum(axis=1)
# ties at the cutoff of the two 15-lists
for v,d in [("frus1969-76ve09p2","d122"),("frus1947v07","d628")]:
    h=ham(rows[(v,d)]); h[rows[(v,d)]]=10**6; hs=np.sort(h); cut=hs[14]
    print(f"{v}/{d}: 15th-nearest distance {cut}; documents at exactly that distance: {(h==cut).sum()}; within <= {cut}: {(h<=cut).sum()}")
rng=random.Random(1877); pr=[(rng.randrange(docs),rng.randrange(docs)) for _ in range(20000)]
rd=np.array([int(POP[np.bitwise_xor(S[a],S[b])].sum()) for a,b in pr if a!=b])
print("random pairs: n",len(rd),"mean %.1f sd %.1f p1 %d min %d"%(rd.mean(),rd.std(),np.percentile(rd,1),rd.min()))
rng2=random.Random(1877); samp=[rng2.randrange(docs) for _ in range(200)]
k1=[];k10=[];k25=[]
for q in samp:
    h=ham(q); h[q]=10**6; hs=np.sort(h); k1.append(hs[0]); k10.append(hs[9]); k25.append(hs[24])
print("200-doc sample: 1st-NN median %d; 10th-NN median %d quartiles %d %d; 25th-NN median %d quartiles %d %d"%(np.median(k1),np.median(k10),np.percentile(k10,25),np.percentile(k10,75),np.median(k25),np.percentile(k25,25),np.percentile(k25,75)))
# within-set pairwise
setp=[tuple(l.strip().split("|")) for l in open("/Users/jbotts/frus-analysis/c3s/runs/s8/raw/set.txt") if l.strip()]
rr=[rows[p] for p in setp]
M=np.array([[int(POP[np.bitwise_xor(S[a],S[b])].sum()) for b in rr] for a in rr]); iu=np.triu_indices(len(rr),1)
print("within-set pairwise hamming: n pairs",len(iu[0]),"mean %.1f min %d"%(M[iu].mean(),M[iu].min()))
