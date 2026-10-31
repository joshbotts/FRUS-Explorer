# vectors.py: Appendix A operations at one digest.
# 1 digest check (index, binary @20, map @20, shards @16); 2 id decode round trip; 3 baselines: 20,000 random pairs (random.Random(1877)) and
# 25th-neighbour distance over 200 random docs (random.Random(1878)); 4 nearest neighbours (Hamming) of anchors, top 800 reranked by Tier-2 int8 cosine,
# calibrated (cos-0.40)/0.60 per retrieval.scoreCalibration.documentOffset; 5 map cluster of anchors; 6 near-duplicate scan among the collection docs.
import json,struct,random,sys,os
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources"; SH="/Users/jbotts/frus-analysis/c3/SemanticVectors"
idx=json.load(open(R+'/semantic-vectors-index.json')); dig=idx['provenanceDigest']
blob=open(R+'/semantic-vectors-binary.bin','rb').read(); mp=open(R+'/semantic-map.bin','rb').read()
ver,dims,docs,cents=struct.unpack('<IIII',blob[4:20]); bd=blob[20:52].hex(); md=mp[20:52].hex()
print('index digest',dig); print('binary digest',bd,'match',bd==dig); print('map digest',md,'match',md==dig)
def numeric_part(x):
    if not x.startswith('d'): return None
    g=x[1:]
    if not g or not g.isdigit() or (len(g)>1 and g[0]=='0'): return None
    return int(g)
row_of={}; doc_of={}; ok=0; volrow={}
for vol in idx['volumes']:
    ids=[]
    for s in vol['seg']:
        assert s['s']==len(ids); ids.append(s['i'])
        if s['n']>1:
            b=numeric_part(s['i']); ids.extend('d%d'%(b+k) for k in range(1,s['n']))
    ok+= len(ids)==vol['n']; volrow[vol['v']]=(vol['r'],vol['n'],ids)
    for i,d in enumerate(ids): row_of[(vol['v'],d)]=vol['r']+i; doc_of[vol['r']+i]=(vol['v'],d)
print('round trip',ok,'of',len(idx['volumes']),'volumes; docs',docs,'dims',dims)
bpr=dims//8
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
def ham(q): return np.unpackbits(np.bitwise_xor(S,S[q]),axis=1).sum(axis=1) if not hasattr(np,'bitwise_count') else np.bitwise_count(np.bitwise_xor(S,S[q])).sum(axis=1)
rng=random.Random(1877); pr=[]
for _ in range(20000):
    a=rng.randrange(docs); b=rng.randrange(docs)
    if a!=b: pr.append(int(np.bitwise_count(np.bitwise_xor(S[a],S[b])).sum()))
pr=np.array(pr); print('random pairs n',len(pr),'mean %.1f sd %.1f p1 %d min %d'%(pr.mean(),pr.std(),np.percentile(pr,1),pr.min()))
rng2=random.Random(1878); k25=[]
for _ in range(200):
    q=rng2.randrange(docs); h=ham(q); h[q]=9999; k25.append(int(np.partition(h,24)[24]))
print('25th-neighbour over 200 docs: median %d q1 %d q3 %d'%(np.median(k25),np.percentile(k25,25),np.percentile(k25,75)))
shcache={}
def shard(v):
    if v in shcache: return shcache[v]
    p=SH+'/%s.vec'%v
    if not os.path.exists(p): shcache[v]=None; return None
    b=open(p,'rb').read(); n=struct.unpack('<I',b[12:16])[0]; d=struct.unpack('<I',b[8:12])[0]
    assert b[16:48].hex()==dig, 'shard digest mismatch '+v
    codes=np.frombuffer(b,dtype=np.int8,count=n*d,offset=64).reshape(n,d).astype(np.float32)
    sc=np.frombuffer(b,dtype=np.float32,count=n,offset=64+n*d)
    shcache[v]=(codes,sc); return shcache[v]
def vec(row):
    v,d=doc_of[row]; s=shard(v)
    if s is None: return None
    i=row-volrow[v][0]; return s[0][i]*s[1][i]
indexed=set(l.split('|')[0] for l in open('raw/indexed_volumes.txt').read().split())
pl=np.frombuffer(mp,dtype=np.int16,count=docs*3,offset=64).reshape(docs,3); cl=pl[:,2].view(np.uint16)
mi=json.load(open(R+'/semantic-map-index.json'))
def clabel(c):
    for x in mi.get('clusters',[]):
        if x.get('id')==int(c): return x
    return None
for a in sys.argv[1:]:
    v,d=a.split('/'); q=row_of[(v,d)]; h=ham(q); h[q]=9999
    pool=np.argsort(h,kind='stable')[:800]
    qv=vec(q); res=[]
    for r in pool:
        x=vec(int(r)); cos=float(np.dot(qv,x)) if (qv is not None and x is not None) else None
        res.append((int(r),int(h[r]),cos))
    res.sort(key=lambda t:-(t[2] if t[2] is not None else -9))
    print('\nANCHOR',a,'map cluster',int(cl[q]))
    for r,hh,cos in res[:10]:
        vv,dd=doc_of[r]; flag='' if vv in indexed else ' [VOLUME NOT IN INDEX]'
        print('  %s/%s hamming %d raw cos %.3f calibrated %.3f cluster %d%s'%(vv,dd,hh,cos,(cos-0.40)/0.60,int(cl[r]),flag))
print('\nmap clusters with labels for anchors:')
for a in sys.argv[1:]:
    v,d=a.split('/'); c=int(cl[row_of[(v,d)]]); x=clabel(c)
    print(a,c,json.dumps(x)[:300] if x else ('unclustered' if c==65535 else 'no label row'))
