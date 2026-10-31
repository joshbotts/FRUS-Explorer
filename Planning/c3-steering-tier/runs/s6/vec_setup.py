import sys; sys.path.insert(0,".")
import vec, json, random, numpy as np
print(json.dumps(vec.checks(),indent=1))
print("docs",vec.docs,"dims",vec.dims,"cents",vec.cents,"volumes",len(vec.vol_rows),"recall",vec.ix["retrieval"]["measuredRecallAt10"])
print(json.dumps(vec.ix["retrieval"]["scoreCalibration"])[:600])
rnd=random.Random(1877); ds=[]
for _ in range(20000):
    a=rnd.randrange(vec.docs); b=rnd.randrange(vec.docs)
    if a==b: continue
    ds.append(bin(int.from_bytes(vec.signs[a].tobytes(),"big")^int.from_bytes(vec.signs[b].tobytes(),"big")).count("1"))
ds=np.array(ds); print("random pairs n",len(ds),"mean",ds.mean().round(1),"sd",ds.std().round(1),"p1",np.percentile(ds,1),"min",ds.min())
rr=random.Random(7); sample=[rr.randrange(vec.docs) for _ in range(200)]
k25=[];k1=[];k10=[]
for r in sample:
    d=vec.ham_to(r); d[r]=9999; s=np.sort(d)[:25]; k1.append(s[0]); k10.append(s[9]); k25.append(s[24])
for nm,a in(("1st",k1),("10th",k10),("25th",k25)): print(nm,"neighbour over 200 docs: median",np.median(a),"quartiles",np.percentile(a,25),np.percentile(a,75))
