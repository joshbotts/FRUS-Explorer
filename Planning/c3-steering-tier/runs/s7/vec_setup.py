import json,struct,random,numpy as np,os,pickle
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ix=json.load(open(R+"semantic-vectors-index.json"))
print("index keys:",list(ix.keys()))
print("digest:",ix["provenanceDigest"]); print("generated:",ix.get("generated"),"harvestGenerated:",ix.get("harvestGenerated"))
print("retrieval:",json.dumps(ix.get("retrieval"))[:800])
blob=open(R+"semantic-vectors-binary.bin","rb").read()
print("bin magic",blob[:4],struct.unpack("<IIIII",blob[4:24]), "digest", blob[20:52].hex())
mp=open(R+"semantic-map.bin","rb").read(64); print("map magic",mp[:4],"digest",mp[20:52].hex())
sm=json.load(open(R+"semantic-shards-manifest.json")); print("shards manifest keys",list(sm.keys()) if isinstance(sm,dict) else type(sm))
gen=open("/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation").read().strip(); print(".generation:",gen)
mi=json.load(open(R+"semantic-map-index.json")); print("map index keys",list(mi.keys())); print("map index digest", mi.get("provenanceDigest"))
def numeric_part(i):
    if not i.startswith("d"): return None
    g=i[1:]
    if not g or not g.isdigit(): return None
    if len(g)>1 and g[0]=="0": return None
    return int(g)
row_of={}; doc_of={}; vols=ix["volumes"]; ok=0
for vol in vols:
    ids=[]
    for seg in vol["seg"]:
        assert seg["s"]==len(ids); ids.append(seg["i"])
        if seg["n"]>1:
            b=numeric_part(seg["i"]); ids.extend("d%d"%(b+k) for k in range(1,seg["n"]))
    ok+= len(ids)==vol["n"]
    vid=vol.get("v") or vol.get("id") or vol.get("volumeId")
    for k,d in enumerate(ids): row_of[(vid,d)]=vol["r"]+k; doc_of[vol["r"]+k]=(vid,d)
print("round trip",ok,"of",len(vols)," rows",len(doc_of))
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bpr=dims//8
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
np.save("signs.npy",S); pickle.dump((row_of,doc_of),open("idmap.pkl","wb"))
rnd=random.Random(1877); P=[(rnd.randrange(docs),rnd.randrange(docs)) for _ in range(20000)]
a=np.array([p[0] for p in P]); b=np.array([p[1] for p in P])
d=np.bitwise_count(S[a]^S[b]).sum(1)
print("random pairs: mean %.1f sd %.1f p1 %d min %d"%(d.mean(),d.std(),np.percentile(d,1),d.min()))
smp=random.Random(1877).sample(range(docs),200); k25=[]; k1=[]
for r in smp:
    dd=np.bitwise_count(S^S[r]).sum(1); dd[r]=9999; srt=np.sort(dd); k25.append(srt[24]); k1.append(srt[0])
print("25th-neighbour over 200 docs: median %d q1 %d q3 %d; 1st-neighbour median %d"%(np.median(k25),np.percentile(k25,25),np.percentile(k25,75),np.median(k1)))
