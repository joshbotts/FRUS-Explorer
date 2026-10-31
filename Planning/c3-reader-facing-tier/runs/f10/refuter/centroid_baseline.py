import json,struct,random,numpy as np,sys
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3f/runs/f10/refuter")
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
ix=json.load(open(RES+"semantic-vectors-index.json")); names=[v["v"] for v in ix["volumes"]]
blob=open(RES+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bpr=dims//8; off=64+docs*bpr
C=[]
for c in range(cents):
    o=off+c*(dims+4); codes=np.frombuffer(blob,dtype=np.int8,count=dims,offset=o).astype(np.float64); sc=struct.unpack("<f",blob[o+dims:o+dims+4])[0]; C.append(codes*sc)
C=np.array(C)[:553]; nrm=np.linalg.norm(C,axis=1); print("zero-norm centroids among first 553:",int((nrm==0).sum()),"| min norm",nrm.min())
Cn=C/nrm[:,None]
i=names.index("frus1917-72PubDipv07"); s=Cn@Cn[i]; o=np.argsort(-s)
print("V3 float64 centroid neighbours of PubDipv07:",[(names[j],round(float(s[j]),3)) for j in o[1:6]],"(memo v06 0.987, v08 0.981, 1977-80v30 0.973, 64-68v33 0.965, 61-63v25 0.965)")
oth=[s[k] for k in range(553) if k!=i]; print("  baseline mean %.3f sd %.3f min %.3f (memo 0.906/0.023/0.802)"%(np.mean(oth),np.std(oth),np.min(oth)))
# baselines: random pairs with the session's seeds
signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
POP=np.array([bin(k).count("1") for k in range(256)],dtype=np.uint8)
rng=random.Random(1877); d=[]
for _ in range(20000):
    a=rng.randrange(docs); b=rng.randrange(docs)
    if a==b: continue
    d.append(int(POP[np.bitwise_xor(signs[a],signs[b])].sum()))
d=np.array(d); print("random pairs n=%d mean %.1f sd %.1f p1 %.0f min %d (memo 167.1, 14.8, 132, 95)"%(len(d),d.mean(),d.std(),np.percentile(d,1),d.min()))
rng=random.Random(2026); rows=[rng.randrange(docs) for _ in range(200)]; k25=[];k1=[]
for r in rows:
    h=POP[np.bitwise_xor(signs,signs[r])].sum(axis=1,dtype=np.int32); h[r]=99999; s2=np.sort(h)[:25]; k25.append(s2[24]); k1.append(s2[0])
print("25th-NN median %.0f q1 %.0f q3 %.0f ; 1st-NN median %.0f q1 %.0f q3 %.0f (memo 106/100/113; 83/75/91)"%(np.median(k25),np.percentile(k25,25),np.percentile(k25,75),np.median(k1),np.percentile(k1,25),np.percentile(k1,75)))
