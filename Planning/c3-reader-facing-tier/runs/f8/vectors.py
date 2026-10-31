import json,struct,random,numpy as np,sys,os,sqlite3
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+"semantic-vectors-index.json"))
print("index keys",list(idx.keys()))
dig_idx=idx["provenanceDigest"]
blob=open(R+"semantic-vectors-binary.bin","rb").read()
assert blob[:4]==b"FRSV"
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); dig_bin=blob[20:52].hex()
mp=open(R+"semantic-map.bin","rb").read(); dig_map=mp[20:52].hex()
gen=open("/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation").read().strip()
print("digest index",dig_idx); print("digest bin  ",dig_bin); print("digest map  ",dig_map); print(".generation",gen)
sh=open("/Users/jbotts/frus-analysis/c3/SemanticVectors/frus1969-76v38p2.vec","rb").read(52); print("digest shard",sh[16:48].hex(), sh[:4])
assert dig_idx==dig_bin==dig_map==sh[16:48].hex(), "DIGEST MISMATCH"
print("ver dims docs cents",ver,dims,docs,cents, "generated",idx.get("generated"),"harvestGenerated",idx.get("harvestGenerated"))
print("retrieval",json.dumps(idx.get("retrieval"))[:600])
def numeric_part(i):
    if not i.startswith("d"): return None
    g=i[1:]
    if not g or not g.isdigit(): return None
    if len(g)>1 and g[0]=="0": return None
    return int(g)
row_of={};doc_of={}
bad=0
for v in idx["volumes"]:
    ids=[]
    for s in v["seg"]:
        assert s["s"]==len(ids); ids.append(s["i"])
        if s["n"]>1:
            b=numeric_part(s["i"]); ids.extend(f"d{b+k}" for k in range(1,s["n"]))
    if len(ids)!=v["n"]: bad+=1
    for k,i in enumerate(ids):
        row_of[(v["v"],i)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],i)
print("roundtrip volumes",len(idx["volumes"]),"bad",bad)
bpr=dims//8
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
def ham(row): return np.bitwise_count(np.bitwise_xor(S,S[row])).sum(axis=1)
rnd=random.Random(1877); pr=[(rnd.randrange(docs),rnd.randrange(docs)) for _ in range(20000)]
d=np.array([int(np.bitwise_count(S[a]^S[b]).sum()) for a,b in pr if a!=b])
print("random pairs: mean %.1f sd %.1f p1 %d min %d n %d"%(d.mean(),d.std(),np.percentile(d,1),d.min(),len(d)))
rnd2=random.Random(1877); samp=[rnd2.randrange(docs) for _ in range(200)]
k25=[np.sort(ham(r))[25] for r in samp]  # index 0 is self
print("25th-neighbour distance over 200 docs: median %d q1 %d q3 %d"%(np.median(k25),np.percentile(k25,25),np.percentile(k25,75)))
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for anchor in sys.argv[1:]:
    v,dd=anchor.split("/"); r=row_of[(v,dd)]
    h=ham(r); order=np.argsort(h,kind="stable")
    print("== anchor",anchor)
    n=0
    for o in order:
        if o==r: continue
        vv,di=doc_of[int(o)]
        hd=c.execute("SELECT substr(header,1,110), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(vv,di)).fetchone()
        print(int(h[o]), f"{vv}/{di}", hd if hd else "ABSENT FROM INDEX https://history.state.gov/historicaldocuments/%s/%s"%(vv,di))
        n+=1
        if n>=12: break
