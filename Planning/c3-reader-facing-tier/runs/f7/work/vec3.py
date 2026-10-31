import sys;sys.path.insert(0,"work")
from vec_lib import *
import json
# centroid similarity: volumes 0..552 in index order
names=[v["v"] for v in vols]
cn=cvec/np.linalg.norm(cvec,axis=1,keepdims=True)
for target in ["frus1917-72PubDipv08","frus1977-80v30","frus1917-72PubDipv06"]:
    i=names.index(target);s=cn[:553]@cn[i]
    o=np.argsort(-s)[1:9]
    print("CENTROID cosine (raw, unfloored) nearest volumes to",target,":",[(names[j],round(float(s[j]),3)) for j in o])
# random volume pair baseline
import random
rng=random.Random(1877);bs=[]
for _ in range(2000):
    a=rng.randrange(553);b=rng.randrange(553)
    if a!=b: bs.append(float(cn[a]@cn[b]))
bs=np.array(bs);print("random volume-pair centroid cosine: mean %.3f sd %.3f p99 %.3f"%(bs.mean(),bs.std(),np.percentile(bs,99)))
# map
mp=np.fromfile(R+"semantic-map.bin",dtype=np.uint8)
pl=mp[64:64+docs*6].reshape(docs,6)
x=pl[:,0:2].copy().view(np.int16).reshape(-1);y=pl[:,2:4].copy().view(np.int16).reshape(-1);cl=pl[:,4:6].copy().view(np.uint16).reshape(-1)
print("map unclustered overall %d of %d (%.1f%%)"%((cl==0xFFFF).sum(),docs,100*(cl==0xFFFF).mean()))
mi=json.load(open(R+"semantic-map-index.json"))
print("map index keys",list(mi.keys()))
cls=mi.get("clusters") or mi.get("labels")
print(type(cls), str(cls[0])[:300] if isinstance(cls,list) else str(list(cls.items())[0])[:300])
anchors=["frus1917-72PubDipv08/d31","frus1964-68v29p2/d123","frus1950v06/d32","frus1917-72PubDipv08/d149","frus1969-76v38p2/d105","frus1977-80v30/d83"]
for a in anchors:
    v,d=a.split("/");r=row_of[(v,d)];c=int(cl[r])
    lab=None
    if c!=0xFFFF and isinstance(cls,list):
        for e in cls:
            if e.get("id",e.get("cluster"))==c: lab=e;break
    print("MAP",a,"cluster",c if c!=0xFFFF else "unclustered",str(lab)[:260])
# unclustered share of on-topic volumes vs era-matched baseline
def share(vs):
    n=u=0
    for v in vs:
        o,k=vol_off[v]; n+=k; u+=int((cl[o:o+k]==0xFFFF).sum())
    return u,n
ont=[l.strip() for l in open("work/ea_vols_list.txt")]+['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30']
u,n=share(ont);print("unclustered in the 79 on-topic volumes: %d of %d (%.1f%%)"%(u,n,100*u/n))
man=json.load(open(R+"manifest.json"))
yr={m["volumeId"]:(int(m["dateRange"]["earliest"][:4])+int(m["dateRange"]["latest"][:4]))//2 for m in man}
base=[v for v in names if 1945<=yr.get(v,0)<=1980 and v not in ont and not v.endswith("Ed2")]
u2,n2=share(base);print("era-matched baseline (volumes dated 1945-1980 by mean of first/last year, not on-topic): %d of %d (%.1f%%) over %d volumes"%(u2,n2,100*u2/n2,len(base)))
