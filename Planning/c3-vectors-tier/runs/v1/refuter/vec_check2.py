import json, struct, re, random, statistics, time
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ix=json.load(open(R+"semantic-vectors-index.json"))
def decode(volume):
    ids=[]
    for seg in volume["seg"]:
        first=seg["i"]; ids.append(first)
        if seg["n"]>1:
            base=int(re.fullmatch(r"d([1-9][0-9]*)",first).group(1)); ids.extend("d%d"%(base+k) for k in range(1,seg["n"]))
    return ids
row_of={}; doc_of={}
for vol in ix["volumes"]:
    for k,i in enumerate(decode(vol)): row_of[(vol["v"],i)]=vol["r"]+k; doc_of[vol["r"]+k]=(vol["v"],i)
b=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",b[4:20]); bpr=dims//8
S=[int.from_bytes(b[64+r*bpr:64+(r+1)*bpr],"big") for r in range(docs)]
def ham(a,bb): return bin(S[row_of[a]]^S[row_of[bb]]).count("1")
# the tie at the tenth entry
for anchor,cands,bd in [(("frus1874","d552"),[("frus1897","d581"),("frus1866p1","d422")],81),(("frus1950v02","d440"),[("frus1958-60v06","d527"),("frus1948v09","d425")],77)]:
    q=S[row_of[anchor]]
    at=[doc_of[r] for r in range(docs) if r!=row_of[anchor] and bin(q^S[r]).count("1")==bd]
    below=sum(1 for r in range(docs) if r!=row_of[anchor] and bin(q^S[r]).count("1")<bd)
    print("anchor",anchor,"rows strictly nearer than",bd,":",below,"; rows at exactly",bd,":",at)
    for cnd in cands: print("   ",cnd,"distance",ham(anchor,cnd),"row",row_of[cnd])
# k-th neighbour distribution, seed 2026, 100 random docs (distances are tie-independent)
t=time.time(); r2=random.Random(2026); k1=[]; k25=[]
for _ in range(100):
    a=r2.randrange(docs); q=S[a]
    ds=sorted(bin(q^S[r]).count("1") for r in range(docs) if r!=a)[:25]
    k1.append(ds[0]); k25.append(ds[24])
k1.sort(); k25.sort(); qq=lambda L,p:L[int(p*(len(L)-1))]
print("100 random docs (seed 2026): NN median %d (q1 %d q3 %d); 25th median %d (q1 %d q3 %d)  [%.0fs]"%(qq(k1,.5),qq(k1,.25),qq(k1,.75),qq(k25,.5),qq(k25,.25),qq(k25,.75),time.time()-t))
# centroids: which layout? test the trailing float32 vs the leading float32
base=64+docs*bpr
tail=[struct.unpack("<f",b[base+i*(dims+4)+dims:base+i*(dims+4)+dims+4])[0] for i in range(cents)]
head=[struct.unpack("<f",b[base+i*(dims+4):base+i*(dims+4)+4])[0] for i in range(cents)]
print("centroid trailing float32: min %.6g max %.6g"%(min(tail),max(tail)),"| leading float32: min %.6g max %.6g"%(min(head),max(head)))
def centroid(i):
    o=base+i*(dims+4); return struct.unpack("<%db"%dims,b[o:o+dims])
def cos(x,y):
    import math
    return sum(p*q for p,q in zip(x,y))/math.sqrt(sum(p*p for p in x)*sum(q*q for q in y))
vols=[v["v"] for v in ix["volumes"]]; vi={v:i for i,v in enumerate(vols)}
C=[centroid(i) for i in range(len(vols))]
for v in ["frus1874","frus1958-60v06","frus1977-80v23"]:
    sims=sorted(((cos(C[vi[v]],C[j]),vols[j]) for j in range(len(vols)) if j!=vi[v]),reverse=True)[:3]
    print("centroid",v,"->"," ".join("%s %.3f"%(n,s) for s,n in sims))
rr=random.Random(1877); rp=[cos(C[x],C[y]) for x,y in ((rr.randrange(553),rr.randrange(553)) for _ in range(3000)) if x!=y]
print("random volume pairs (seed 1877): mean %.3f sd %.3f"%(statistics.mean(rp),statistics.pstdev(rp)))
# int8 magnitude sanity: a unit vector's int8 codes should include +-127 (scale = max|x|/127)
print("max |code| over the first 5 centroids:",[max(abs(x) for x in C[i]) for i in range(5)])
