import json, struct, heapq, time
R='/Applications/FRUS Explorer.app/Contents/Resources/'
idx=json.load(open(R+'semantic-vectors-index.json'))
# my own A.3 decode: each segment (i=first id, n=count, s=start offset within the volume); ids after the first are d<base+k>
def decode(segs):
    ids=[]
    for seg in segs:
        assert seg['s']==len(ids), seg
        first=seg['i']; ids.append(first)
        if seg['n']>1:
            assert first[0]=='d' and first[1:].isdigit() and not (len(first)>2 and first[1]=='0'), first
            base=int(first[1:]); ids += [f"d{base+k}" for k in range(1,seg['n'])]
    return ids
row_of={}; doc_of={}
for v in idx['volumes']:
    ids=decode(v['seg']); assert len(ids)==v['n'], (v['v'],len(ids),v['n'])
    for k,d in enumerate(ids): row_of[(v['v'],d)]=v['r']+k; doc_of[v['r']+k]=(v['v'],d)
assert len(row_of)==idx['documentCount']==314616
blob=open(R+'semantic-vectors-binary.bin','rb').read()
magic=blob[:4]; ver,dims,docs,cents=struct.unpack('<IIII',blob[4:20]); digest=blob[20:52].hex()
print("magic",magic,"ver",ver,"dims",dims,"docs",docs,"centroids",cents,"digest==index:",digest==idx['provenanceDigest'])
bpr=dims//8
assert len(blob)==64+docs*bpr+cents*(dims+4), len(blob)
S=[int.from_bytes(blob[64+r*bpr:64+(r+1)*bpr],'big') for r in range(docs)]
def knn(row,k):
    q=S[row]; best=[]
    for r in range(docs):
        if r==row: continue
        d=bin(q^S[r]).count('1')
        if len(best)<k: heapq.heappush(best,(-d,r))
        elif -best[0][0]>d: heapq.heapreplace(best,(-d,r))
    return sorted([(-a,b) for a,b in best])
session=open('../vec_neighbours.txt').read().split('ANCHOR ')
def session_list(anchor):
    for blk in session:
        if blk.startswith(anchor):
            return [(int(l.split()[1]), l.split()[2]) for l in blk.splitlines()[1:] if l.strip().startswith('ham')]
for a in [('frus1969-76ve10','d205'),('frus1958-60v06','d499')]:
    t=time.time(); mine=[(d,'%s/%s'%doc_of[r]) for d,r in knn(row_of[a],15)]
    theirs=session_list('%s/%s'%a)
    print(f"\nANCHOR {a[0]}/{a[1]}  ({time.time()-t:.1f}s)")
    for i,(m,s) in enumerate(zip(mine,theirs)):
        print(f"  {i+1:2d} mine {m[0]:3d} {m[1]:34s} session {s[0]:3d} {s[1]:34s} {'OK' if m==s else 'DIFF'}")
    print("  identical list and order:", mine==theirs)
def ham(a,b): return bin(S[row_of[a]]^S[row_of[b]]).count('1')
print("\nHamming frus1881/d405 vs frus1894app2/d394 =", ham(('frus1881','d405'),('frus1894app2','d394')), "(memo: 4)")
print("Hamming frus1969-76ve10/d205 vs frus1961-63v10-12mSupp/d729 =", ham(('frus1969-76ve10','d205'),('frus1961-63v10-12mSupp','d729')), "(memo: 52)")
print("Hamming frus1958-60v06/d499 vs frus1958-60v05/d112 =", ham(('frus1958-60v06','d499'),('frus1958-60v05','d112')), "(memo: 106)")
print("Hamming frus1874/d552 vs frus1898/d498 =", ham(('frus1874','d552'),('frus1898','d498')), "(memo: 80)")
print("frus1898/ch83 in vector index:", ('frus1898','ch83') in row_of, "(memo: not in it)")
# map and shard digests
mp=open(R+'semantic-map.bin','rb').read(64); print("map header digest==index:", mp[20:52].hex()==idx['provenanceDigest'], "map docs/clusters", struct.unpack('<II',mp[8:16]))
import os
sd='/Users/jbotts/frus-analysis/c3/SemanticVectors/'
gen=open(sd+'.generation').read().split() if os.path.exists(sd+'.generation') else None
vecs=[f for f in os.listdir(sd) if f.endswith('.vec')]
bad=sum(1 for f in vecs if open(sd+f,'rb').read(64)[16:48].hex()!=idx['provenanceDigest'])
print("shards:",len(vecs),"with mismatched header digest:",bad,"; .generation:",gen)
