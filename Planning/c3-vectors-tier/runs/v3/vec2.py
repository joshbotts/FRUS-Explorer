from vec import *
import sqlite3, statistics, time
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
S=signs()
rnd=random.Random(1877)
ds=[]
for _ in range(20000):
    a=rnd.randrange(docs); b=rnd.randrange(docs)
    if a!=b: ds.append(bin(S[a]^S[b]).count("1"))
ds.sort()
print("random pairs mean %.1f sd %.1f p1 %d min %d"%(statistics.mean(ds),statistics.pstdev(ds),ds[len(ds)//100],ds[0]))
# k-th neighbour distribution over 30 random docs (seed 2026)
rnd2=random.Random(2026); k25=[]; k1=[]
t=time.time()
for _ in range(30):
    r=rnd2.randrange(docs); nn=knn(r,25); k1.append(nn[0][0]); k25.append(nn[-1][0])
k25.sort(); k1.sort()
print("30-doc sample: 1st-neighbour median %d; 25th-neighbour median %d quartiles %d %d (%.0fs)"%(k1[15],k25[15],k25[7],k25[22],time.time()-t))
