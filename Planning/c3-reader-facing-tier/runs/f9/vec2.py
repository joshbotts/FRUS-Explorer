# near-duplicates among collection docs (pairwise Hamming), map clusters + labels, unclustered share vs era-matched baseline (volumes whose manifest midpoint year 1945-1980)
import json,struct,itertools,re
import numpy as np
P="/Applications/FRUS Explorer.app/Contents/Resources/"
exec(open('vectors.py').read().split('blob=open')[0])  # reuse decode/row_of only
blob=open(P+'semantic-vectors-binary.bin','rb').read(); ver,dims,docs,cents=struct.unpack('<IIII',blob[4:20]); bpr=dims//8
S=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
pairs=[tuple(l.split()) for l in open('collection_pairs.txt') if l.strip()]
rows=[row_of[p] for p in pairs]
ds=[]
for (a,ra),(b,rb) in itertools.combinations(zip(pairs,rows),2):
    ds.append((int(np.bitwise_count(np.bitwise_xor(S[ra],S[rb])).sum()),a,b))
ds.sort(); print('closest collection pairs:',ds[:5]); print('mean pairwise',np.mean([d[0] for d in ds]).round(1),'n pairs',len(ds))
mb=open(P+'semantic-map.bin','rb').read(); assert mb[20:52].hex()==DIG
mi=json.load(open(P+'semantic-map-index.json')); print('clusters list len',len(mi['clusters'])); print(json.dumps(mi['clusters'][0])[:300])
CL=np.frombuffer(mb,dtype=np.uint16,count=docs*3,offset=64).reshape(docs,3)[:,2]
un=sum(1 for r in rows if CL[r]==0xFFFF); print('collection unclustered',un,'of',len(rows))
man=json.load(open(P+'manifest.json')); mid={v['volumeId']:(int(v['dateRange']['earliest'][:4])+int(v['dateRange']['latest'][:4]))//2 for v in man}
tot=unc=0
for v in ix['volumes']:
    if 1945<=mid[v['v']]<=1980:
        r0,n=v['r'],v['n']; c=CL[r0:r0+n]; tot+=n; unc+=int((c==0xFFFF).sum())
print('era baseline (volumes midpoint 1945-1980): unclustered',unc,'of',tot)
byid={c.get('id',i):c for i,c in enumerate(mi['clusters'])}
for p,r in zip(pairs,rows):
    c=int(CL[r]); lab=byid.get(c,{}).get('terms') if c!=0xFFFF else None
    print('MAP',p,c,(lab or '')[:6] if isinstance(lab,list) else lab)
