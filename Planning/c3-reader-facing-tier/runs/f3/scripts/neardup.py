# neardup.py: for each collection doc, its nearest corpus neighbour by Hamming over the Tier-1 sign bits (digest checked), and pairwise min within the collection.
import json,struct,numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources"
idx=json.load(open(R+'/semantic-vectors-index.json')); blob=open(R+'/semantic-vectors-binary.bin','rb').read()
assert blob[20:52].hex()==idx['provenanceDigest']
ver,dims,docs,cents=struct.unpack('<IIII',blob[4:20]); bpr=dims//8
def np_(x):
    if not x.startswith('d'): return None
    g=x[1:]
    if not g.isdigit() or (len(g)>1 and g[0]=='0'): return None
    return int(g)
row_of={}; doc_of={}
for vol in idx['volumes']:
    ids=[]
    for s in vol['seg']:
        ids.append(s['i'])
        if s['n']>1: b=np_(s['i']); ids.extend('d%d'%(b+k) for k in range(1,s['n']))
    for i,d in enumerate(ids): row_of[(vol['v'],d)]=vol['r']+i; doc_of[vol['r']+i]=(vol['v'],d)
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
ids=[tuple(l.split('/')) for l in open('raw/collection_ids.txt').read().split()]
rows=[row_of[i] for i in ids]
for i,r in zip(ids,rows):
    h=np.bitwise_count(np.bitwise_xor(S,S[r])).sum(axis=1); h[r]=9999; n=int(np.argmin(h))
    print('%s/%s nearest %s/%s hamming %d'%(i[0],i[1],doc_of[n][0],doc_of[n][1],h[n]))
m=9999;pair=None
for a in range(len(rows)):
    for b in range(a+1,len(rows)):
        d=int(np.bitwise_count(np.bitwise_xor(S[rows[a]],S[rows[b]])).sum())
        if d<m: m=d;pair=(ids[a],ids[b])
print('min pairwise within collection',m,pair)
