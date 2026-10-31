from vecsetup import *
import random, statistics, json
# Baseline 1: random pairs, standard-library Random(1877), 20,000 pairs
rng=random.Random(1877); ds=[]
for _ in range(20000):
    a=rng.randrange(docs); b=rng.randrange(docs)
    if a==b: continue
    ds.append(int(np.bitwise_count(np.bitwise_xor(signs[a],signs[b])).sum()))
ds.sort()
print("RANDOM PAIRS n=%d mean=%.1f sd=%.1f p1=%d min=%d"%(len(ds),statistics.mean(ds),statistics.pstdev(ds),ds[len(ds)//100],ds[0]))
# Baseline 2: k-th neighbour distribution, 200 random documents (Random(1877)), k=1,10,25
rng=random.Random(1877); sample=[rng.randrange(docs) for _ in range(200)]
k1=[];k10=[];k25=[]
for r in sample:
    h=hamming_all(r).astype(np.int32); h[r]=10**6
    s=np.partition(h,25)[:25]; s.sort()
    k1.append(int(s[0]));k10.append(int(s[9]));k25.append(int(s[24]))
q=lambda x:(statistics.median(x),statistics.quantiles(x,n=4)[0],statistics.quantiles(x,n=4)[2])
print("KTH NEIGHBOUR (200-doc sample): 1st median/q1/q3",q(k1)," 10th",q(k10)," 25th",q(k25))
json.dump({"random_mean":statistics.mean(ds),"random_sd":statistics.pstdev(ds),"p1":ds[len(ds)//100],"k25_median":q(k25)[0]},open("vec_baselines.json","w"))
