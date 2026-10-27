# k-th neighbour baseline at this digest: 25th-nearest Hamming distance for 40 documents drawn with random.Random(1877) over all rows; plus map clusters for anchors.
import json,struct,heapq,random
exec(open('s15_vectors.py').read().split('# baseline')[0].replace('print(','(lambda *a,**k:None)('))
rnd=random.Random(1877); sample=[rnd.randrange(docs) for _ in range(40)]
k25=[]
for a in sample:
    q=rows[a]; best=[]
    for r in range(docs):
        if r==a: continue
        d=bin(q^rows[r]).count('1')
        if len(best)<25: heapq.heappush(best,-d)
        elif -best[0]>d: heapq.heapreplace(best,-d)
    k25.append(-best[0])
k25.sort(); print("25th-neighbour distances (40 docs):",k25); print("median",(k25[19]+k25[20])/2,"q1",k25[10],"q3",k25[30])
cl=mapi['clusters']; print("cluster entry keys:",list(cl[0]) if isinstance(cl,list) else type(cl))
byid={x.get('id',n):x for n,x in enumerate(cl)} if isinstance(cl,list) else cl
for a in [('frus1898','d490'),('frus1958-60v06','d517'),('frus1933v05','d241'),('frus1961-63v10','d202'),('frus1877-80v23','d19'),('frus1977-80v23','d19'),('frus1874','d552'),('frus1969-76ve11p1','d278')]:
    if a not in row_of: print(a,'absent'); continue
    o=64+row_of[a]*6; x,y,cid=struct.unpack('<hhH',mapb[o:o+6])
    if cid==0xFFFF: print('/'.join(a),'unclustered'); continue
    e=byid.get(cid); print('/'.join(a),'cluster',cid,{k:e[k] for k in e if k in ('terms','label','count','documentCount','eras','eraHistogram')} if e else None)
