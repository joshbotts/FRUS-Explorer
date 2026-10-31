import json,struct,random,sqlite3,re,sys
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ix=json.load(open(R+"semantic-vectors-index.json"))
dig=ix['provenanceDigest']
def numeric_part(d):
    if not d.startswith("d"): return None
    x=d[1:]
    if not x or not x.isdigit(): return None
    if len(x)>1 and x[0]=="0": return None
    return int(x)
def decode(segs):
    ids=[]
    for s in segs:
        assert s["s"]==len(ids)
        ids.append(s["i"])
        if s["n"]>1:
            b=numeric_part(s["i"]); ids.extend(f"d{b+k}" for k in range(1,s["n"]))
    return ids
doc_of=[];row_of={}
for v in ix['volumes']:
    ids=decode(v['seg']); assert len(ids)==v['n'],(v['v'],len(ids),v['n']); assert v['r']==len(doc_of)
    for k,i in enumerate(ids): row_of[(v['v'],i)]=v['r']+k
    doc_of.extend((v['v'],i) for i in ids)
print('round trip OK volumes',len(ix['volumes']),'docs',len(doc_of))
blob=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bd=blob[20:52].hex()
mp=open(R+"semantic-map.bin","rb").read(); md=mp[20:52].hex()
sh=open("/Users/jbotts/frus-analysis/c3/SemanticVectors/frus1964-68v01.vec","rb").read(); sd=sh[16:48].hex()
gen=open("/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation").read().strip()
print('digests index/binary/map/shard/.generation equal:',dig==bd==md==sd==gen, dig[:16])
print('dims',dims,'docs',docs,'cents',cents,'recall@10',ix['retrieval']['measuredRecallAt10'],'calib',ix['retrieval']['scoreCalibration'])
bpr=dims//8
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
def ham(a,b=None):
    if b is None: return np.bitwise_count(S ^ S[a]).sum(axis=1)
def dist_to(row): return np.bitwise_count(S ^ S[row]).sum(axis=1,dtype=np.int32)
rng=random.Random(1877)
rd=[]
for _ in range(20000):
    a=rng.randrange(docs); b=rng.randrange(docs)
    if a==b: continue
    rd.append(int(np.bitwise_count(S[a]^S[b]).sum()))
rd=np.array(rd); print('random pairs: mean %.1f sd %.1f p1 %d min %d'%(rd.mean(),rd.std(),np.percentile(rd,1),rd.min()))
# k-th neighbour distribution over 200 sampled docs
rng2=random.Random(2026); samp=[rng2.randrange(docs) for _ in range(200)]
k25=[];k1=[];k10=[]
for r in samp:
    d=dist_to(r); d[r]=9999; s=np.sort(d); k1.append(s[0]); k10.append(s[9]); k25.append(s[24])
print('1st-nn median %d, 10th-nn median %d, 25th-nn median %d (quartiles %d,%d)'%(np.median(k1),np.median(k10),np.median(k25),np.percentile(k25,25),np.percentile(k25,75)))
np.save('vec_S.npy',S) if False else None
json.dump({'dig':dig,'rand_mean':float(rd.mean()),'rand_sd':float(rd.std()),'k1':float(np.median(k1)),'k10':float(np.median(k10)),'k25':float(np.median(k25))},open('vec_baselines.json','w'))
