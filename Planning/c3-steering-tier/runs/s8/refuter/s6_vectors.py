# Independent re-run of the two neighbour lists from the bundle's binary: own decode of the index's run-length id segments
import json, struct, numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+"semantic-vectors-index.json")); blob=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); assert blob[20:52].hex()==idx["provenanceDigest"]
assert len(blob)==64+docs*(dims//8)+cents*(dims+4), (len(blob), 64+docs*(dims//8)+cents*(dims+4))
print("binary layout consistent: header 64 + %d rows x %d bytes + %d centroids x (%d int8 + f32 scale) = %d bytes"%(docs,dims//8,cents,dims,len(blob)))
# decode: for each volume, rows r..r+n-1; segments give the first id and a run length of consecutive numeric suffixes
rows={}; ids={}; expect_r=0; total=0
for v in idx["volumes"]:
    assert v["r"]==expect_r, (v["v"],v["r"],expect_r); expect_r+=v["n"]; total+=v["n"]
    out=[]
    for s in v["seg"]:
        assert s["s"]==len(out)
        first=s["i"]; out.append(first)
        if s["n"]>1:
            base=int(first[1:]); out.extend("d%d"%(base+k) for k in range(1,s["n"]))
    assert len(out)==v["n"], (v["v"],len(out),v["n"])
    for k,i in enumerate(out): rows[(v["v"],i)]=v["r"]+k; ids[v["r"]+k]=(v["v"],i)
assert total==docs==idx["documentCount"]; print("decoded rows:",total,"volumes:",len(idx["volumes"]))
S=np.frombuffer(blob,dtype=np.uint8,count=docs*(dims//8),offset=64).reshape(docs,dims//8)
def nn(v,d,k=15):
    q=rows[(v,d)]; h=np.unpackbits(np.bitwise_xor(S,S[q]),axis=1).sum(axis=1); h[q]=10**6
    o=np.argsort(h,kind="stable")[:k]; return [(ids[int(r)][0],ids[int(r)][1],int(h[r])) for r in o]
sess=json.load(open("/Users/jbotts/frus-analysis/c3s/runs/s8/raw/vec_nn.json"))
for a in ["frus1969-76ve09p2/d122","frus1947v07/d628"]:
    v,d=a.split("/"); mine=nn(v,d); theirs=[tuple(x) for x in sess[a]]
    print("\nNN of",a)
    for m,t in zip(mine,theirs): print("   mine",m," session",t," same" if m==t else " DIFF")
    print("  reproduced:", mine==theirs, "| same set:", set(mine)==set(theirs))
# near-duplicates of the two Ed2 pairs
for v,d in [("frus1969-76ve15p2","d292"),("frus1969-76ve15p2","d293")]:
    q=rows[(v,d)]; h=np.unpackbits(np.bitwise_xor(S,S[q]),axis=1).sum(axis=1); h[q]=10**6
    print("near-dup <=20 of",v,d,[(ids[int(r)],int(h[r])) for r in np.where(h<=20)[0]])
# is d155 in d122's top-15 by this decode, and at what rank?
L=nn("frus1969-76ve09p2","d122",30); r=[i for i,x in enumerate(L) if x[:2]==("frus1969-76ve09p2","d155")]
print("d155 rank in d122's list (0-based):",r, "distance:",[L[i][2] for i in r])
