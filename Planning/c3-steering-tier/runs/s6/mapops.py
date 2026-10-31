import sys; sys.path.insert(0,".")
import vec, json, struct, numpy as np, csv, collections
R=vec.R
mb=open(R+"/semantic-map.bin","rb").read()
ndoc=struct.unpack("<I",mb[8:12])[0]
pl=np.frombuffer(mb,dtype=np.dtype([("x","<i2"),("y","<i2"),("c","<u2")]),count=ndoc,offset=64)
mi=json.load(open(R+"/semantic-map-index.json")); cl={c["id"]:c for c in mi["clusters"]}
print("map docs",ndoc,"unclustered",int((pl["c"]==0xFFFF).sum()),"of",ndoc, "clusters",len(cl))
anchors=["frus1958-60v01/d111","frus1969-76ve09p2/d122","frus1943China/d202","frus1969-76ve15p2/d292","frus1964-68v05/d197","frus1894app2/d255","frus1961-63v22/d249"]
for a in anchors:
    k=tuple(a.split("/")); r=vec.row_of[k]; c=int(pl[r]["c"])
    if c==0xFFFF: print(a,"UNCLUSTERED"); continue
    print(a,"cluster",c,cl[c]["terms"],"docs",cl[c]["documentCount"],"era",cl[c]["eraCounts"])
# which clusters hold the core set (scan2 nfam>=3)? 
rows=[r for r in csv.DictReader(open("scan2.csv")) if int(r["nfam"])>=3]
cnt=collections.Counter(); un=0; tot=0
for r in rows:
    k=(r["volume_id"],r["document_id"])
    if k not in vec.row_of: continue
    tot+=1; c=int(pl[vec.row_of[k]]["c"])
    if c==0xFFFF: un+=1
    else: cnt[c]+=1
print("core set placed",tot,"unclustered",un,"of",tot)
for c,n in cnt.most_common(12): print(" cluster",c,cl[c]["terms"],"core docs",n,"of cluster",cl[c]["documentCount"], "-> core share of cluster %.4f"%(n/cl[c]["documentCount"]))
# corpus-wide unclustered share baseline
print("corpus unclustered share %.3f"%((pl["c"]==0xFFFF).mean()))
# centroids
cb=64+vec.docs*vec.bpr
vols=[v["v"] for v in vec.ix["volumes"]]
cc=np.frombuffer(vec.blob,dtype=np.int8,count=vec.cents*512,offset=cb).reshape(vec.cents,512).astype(np.float32)
sc=np.frombuffer(vec.blob,dtype=np.float32,count=vec.cents,offset=cb+vec.cents*512)
# layout check: codes then scale per centroid? spec: centroids x (dims+4) bytes (int8 codes, then Float32 scale)
rec=512+4
raw=np.frombuffer(vec.blob,dtype=np.uint8,count=vec.cents*rec,offset=cb).reshape(vec.cents,rec)
cc=raw[:,:512].view(np.int8).astype(np.float32); sc=np.ascontiguousarray(raw[:,512:]).view("<f4").reshape(-1)
V=cc*sc[:,None]; V/=np.linalg.norm(V,axis=1,keepdims=True)
for v in ["frus1958-60v01","frus1969-76ve09p2","frus1943China"]:
    i=vols.index(v); s=V[:553]@V[i]; o=np.argsort(-s)[1:6]
    print("centroid nearest to",v,[(vols[j],round(float(s[j]),3)) for j in o])
# near-duplicate check among finalists later
