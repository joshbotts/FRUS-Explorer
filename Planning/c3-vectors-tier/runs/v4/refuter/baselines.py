import json, struct, random, heapq, math, time
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+'semantic-vectors-index.json')); blob=open(R+'semantic-vectors-binary.bin','rb').read()
ver,dims,docs,cents=struct.unpack('<IIII',blob[4:20]); bpr=dims//8
rows=[int.from_bytes(blob[64+r*bpr:64+(r+1)*bpr],'big') for r in range(docs)]
rnd=random.Random(1877); ds=sorted(bin(rows[rnd.randrange(docs)]^rows[rnd.randrange(docs)]).count('1') for _ in range(20000))
m=sum(ds)/len(ds); sd=(sum((x-m)**2 for x in ds)/len(ds))**.5
print("random-pair baseline (20,000, Random(1877)): mean %.1f sd %.1f p1 %d min %d   [session: 167.1 14.8 132 95]"%(m,sd,ds[200],ds[0]))
rnd=random.Random(1877); sample=[rnd.randrange(docs) for _ in range(40)]
t=time.time(); k25=[]
for a in sample:
    q=rows[a]; best=[]
    for r in range(docs):
        if r==a: continue
        d=bin(q^rows[r]).count('1')
        if len(best)<25: heapq.heappush(best,-d)
        elif -best[0]>d: heapq.heapreplace(best,-d)
    k25.append(-best[0])
k25.sort(); print("25th-neighbour baseline over 40 docs: median %.1f q1 %d q3 %d (%.0fs)   [session: 108.0 103 113]"%((k25[19]+k25[20])/2,k25[10],k25[30],time.time()-t))
# centroids: after the rows; 660 = 553 volumes + 107 subseries
vids=[v['v'] for v in idx['volumes']]
base=64+docs*bpr
def cent(j):
    o=base+j*(dims+4); codes=struct.unpack('%db'%dims,blob[o:o+dims]); s=struct.unpack('<f',blob[o+dims:o+dims+4])[0]; return [x*s for x in codes]
def cos(a,b): return sum(x*y for x,y in zip(a,b))/math.sqrt(sum(x*x for x in a)*sum(y*y for y in b))
C={v:cent(k) for k,v in enumerate(vids)}
print("file size check: 64 + rows + 660 centroids =", 64+docs*bpr+cents*(dims+4), "actual", len(blob))
for a,b,claim in [('frus1898','frus1961-63v11',0.865),('frus1872p2v1','frus1961-63v11',0.861),('frus1933v05','frus1958-60v06',0.930),('frus1977-80v23','frus1969-76ve11p1',0.981),('frus1977-80v23','frus1977-80v24',0.972)]:
    print("centroid cosine %s~%s = %.3f (memo %.3f)"%(a,b,cos(C[a],C[b]),claim))
top=sorted(((cos(C['frus1977-80v23'],C[b]),b) for b in vids if b!='frus1977-80v23'),reverse=True)[:3]; print("nearest to frus1977-80v23:",[(b,round(s,3)) for s,b in top])
