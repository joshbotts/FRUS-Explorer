import sys;sys.path.insert(0,"work")
from vec_lib import *
import random
print("ids decoded round-trip: volumes",len(vols),"docs",len(doc_of),"missing",sum(1 for x in doc_of if x is None))
print("dims",dims,"docs",docs,"cents",cents, "recall@10",idx["retrieval"]["measuredRecallAt10"], "calib",idx["retrieval"]["scoreCalibration"])
# random pair baseline
rng=random.Random(1877)
ds=[]
for _ in range(20000):
    a=rng.randrange(docs);b=rng.randrange(docs)
    ds.append(int(np.bitwise_count(np.bitwise_xor(signs[a],signs[b])).sum()))
ds=np.array(ds);print("RANDOM PAIRS n=20000 mean %.1f sd %.1f p1 %.0f min %d"%(ds.mean(),ds.std(),np.percentile(ds,1),ds.min()))
# k-th neighbour baseline, 200 docs
rng=random.Random(1877+1)
k25=[];k1=[]
for _ in range(200):
    r=rng.randrange(docs);h=ham_all(r);h[r]=9999;s=np.sort(h);k1.append(s[0]);k25.append(s[24])
k25=np.array(k25);k1=np.array(k1)
print("200-doc sample: 1st-NN median %.0f; 25th-NN median %.0f quartiles %.0f %.0f"%(np.median(k1),np.median(k25),np.percentile(k25,25),np.percentile(k25,75)))
