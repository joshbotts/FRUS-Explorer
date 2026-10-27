import random,statistics
from vec import *
S=signs()
rnd=random.Random(1877)
ds=[]
for _ in range(20000):
    a=rnd.randrange(docs); b=rnd.randrange(docs)
    if a!=b: ds.append(bin(S[a]^S[b]).count("1"))
ds.sort()
print("random pairs n=%d mean=%.1f sd=%.1f p1=%d min=%d"%(len(ds),statistics.mean(ds),statistics.pstdev(ds),ds[len(ds)//100],ds[0]),flush=True)
r2=random.Random(2026); k25=[]; k1=[]
for _ in range(100):
    a=r2.randrange(docs); nb=neighbours(a,25)
    k1.append(nb[0][0]); k25.append(nb[-1][0])
k25.sort(); k1.sort()
q=lambda L,p:L[int(p*(len(L)-1))]
print("100 random docs: nearest-neighbour median %d (q1 %d q3 %d); 25th-neighbour median %d (q1 %d q3 %d)"%(q(k1,.5),q(k1,.25),q(k1,.75),q(k25,.5),q(k25,.25),q(k25,.75)),flush=True)
