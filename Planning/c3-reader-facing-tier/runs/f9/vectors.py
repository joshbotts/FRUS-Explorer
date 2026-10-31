# Appendix A operations at digest 89481b18...: decode ids (A.3), Hamming kNN (A.5) with baselines, Tier-2 rerank (A.6), calibrated cosine (A.7),
# semantic join to document_cache/document_dates/document_sources, centroid similarity, map cluster, near-duplicates among collection docs.
import json,struct,random,sys,sqlite3
import numpy as np
P="/Applications/FRUS Explorer.app/Contents/Resources/"; SV="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
ix=json.load(open(P+'semantic-vectors-index.json')); DIG=ix['provenanceDigest']
def numeric_part(i):
    if not i.startswith('d'): return None
    g=i[1:]
    if not g or not g.isdigit(): return None
    if len(g)>1 and g[0]=='0': return None
    return int(g)
def decode(segs):
    ids=[]
    for s in segs:
        assert s['s']==len(ids); ids.append(s['i'])
        if s['n']>1:
            b=numeric_part(s['i']); ids.extend(f"d{b+k}" for k in range(1,s['n']))
    return ids
row_of={}; doc_of=[None]*ix['documentCount']; vol_rows={}
ok=0
for v in ix['volumes']:
    ids=decode(v['seg']); ok+= len(ids)==v['n']; vol_rows[v['v']]=(v['r'],v['n'])
    for k,i in enumerate(ids): row_of[(v['v'],i)]=v['r']+k; doc_of[v['r']+k]=(v['v'],i)
print('roundtrip volumes ok',ok,'of',len(ix['volumes']))
blob=open(P+'semantic-vectors-binary.bin','rb').read()
ver,dims,docs,cents=struct.unpack('<IIII',blob[4:20]); assert blob[20:52].hex()==DIG
bpr=dims//8
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
def ham(q): return np.bitwise_count(np.bitwise_xor(S,S[q])).sum(axis=1)
# baselines
rng=random.Random(1877); a=[rng.randrange(docs) for _ in range(20000)]; b=[rng.randrange(docs) for _ in range(20000)]
rp=np.bitwise_count(np.bitwise_xor(S[a],S[b])).sum(axis=1)
print('random pairs: mean %.1f sd %.1f p1 %d min %d'%(rp.mean(),rp.std(),np.percentile(rp,1),rp.min()))
rng2=random.Random(2026); samp=[rng2.randrange(docs) for _ in range(200)]
k1=[];k10=[];k25=[]
for q in samp:
    h=ham(q); h[q]=9999; hs=np.sort(h); k1.append(hs[0]); k10.append(hs[9]); k25.append(hs[24])
print('kth-neighbour over 200 docs (Random(2026)): 1st median %d; 10th median %d q1 %d q3 %d; 25th median %d q1 %d q3 %d'%(np.median(k1),np.median(k10),np.percentile(k10,25),np.percentile(k10,75),np.median(k25),np.percentile(k25,25),np.percentile(k25,75)))
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
indexed=set(r[0] for r in db.execute("SELECT DISTINCT volume_id FROM document_cache"))
shards={}
def shard(v):
    if v not in shards:
        bl=open(SV+v+'.vec','rb').read(); assert bl[16:48].hex()==DIG
        n=struct.unpack('<I',bl[12:16])[0]; d=struct.unpack('<I',bl[8:12])[0]
        codes=np.frombuffer(bl,dtype=np.int8,count=n*d,offset=64).reshape(n,d).astype(np.float32)
        sc=np.frombuffer(bl,dtype=np.float32,count=n,offset=64+n*d)
        shards[v]=(codes,sc)
    return shards[v]
def vec(row):
    v,i=doc_of[row]; r0,n=vol_rows[v]; codes,sc=shard(v); return codes[row-r0]*sc[row-r0]
def info(v,d):
    r=db.execute("SELECT substr(replace(header,char(10),' '),1,110), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    dt=db.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    src=db.execute("SELECT repository, record_group, coalesce(lot_file_norm,series_name) FROM document_sources WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    return r,(dt[0] if dt else None),src
for anchor in [('frus1917-72PubDipv08','d31'),('frus1969-76v38p2','d105')]:
    q=row_of[anchor]; h=ham(q); h[q]=9999
    pool=np.argsort(h)[:800]
    qa=vec(q)
    cos=np.array([float(np.dot(qa,vec(r))) for r in pool])
    order=np.argsort(-cos)[:15]
    print('\nANCHOR',anchor,'row',q,'own-vol centroid n/a; top15 by int8 cosine after Hamming-800')
    for o in order:
        r=pool[o]; v,d=doc_of[r]; inf=info(v,d)
        flag='' if v in indexed else ' [VOLUME NOT IN document_cache]'
        print(f"  ham {h[r]:3d} cos_raw {cos[o]:.3f} calibrated {(cos[o]-0.40)/0.60:.3f} {v}/{d}{flag} | {inf[1]} | {inf[0][0] if inf[0] else None} | apparatus={inf[0][1:] if inf[0] else None} | src={inf[2]}")
# centroids
co=64+docs*bpr; C=[]
for k in range(cents):
    off=co+k*(dims+4); c8=np.frombuffer(blob,dtype=np.int8,count=dims,offset=off).astype(np.float32); s=struct.unpack('<f',blob[off+dims:off+dims+4])[0]; C.append(c8*s)
C=np.array(C); C/=np.linalg.norm(C,axis=1,keepdims=True)
vnames=[v['v'] for v in ix['volumes']]
for vv in ['frus1917-72PubDipv08','frus1917-72PubDipv07']:
    k=vnames.index(vv); sims=C[:len(vnames)]@C[k]; top=np.argsort(-sims)[1:9]
    print('\nCENTROID neighbours of',vv,[(vnames[t],round(float(sims[t]),3)) for t in top])
# map clusters of anchors
mb=open(P+'semantic-map.bin','rb').read(); assert mb[20:52].hex()==DIG
mi=json.load(open(P+'semantic-map-index.json'))
def place(row): return struct.unpack('<hhH',mb[64+row*6:64+row*6+6])
print('\nmap-index keys',list(mi.keys())[:10])
for anchor in [('frus1917-72PubDipv08','d31'),('frus1969-76v38p2','d105'),('frus1917-72PubDipv07','d48'),('frus1955-57v09','d190')]:
    x,y,cl=place(row_of[anchor]); print('MAP',anchor,x,y,cl)
json.dump({'row_of_ok':ok},open('vectors_meta.json','w'))
