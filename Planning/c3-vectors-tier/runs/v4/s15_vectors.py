# Vector operations (Appendix A). Files: semantic-vectors-index.json, semantic-vectors-binary.bin, semantic-map.bin, semantic-map-index.json,
# /Users/jbotts/frus-analysis/c3/SemanticVectors/<vol>.vec. Python 3.9: popcount via bin(x).count("1").
import json,struct,heapq,random,sqlite3,collections,math,os
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+'semantic-vectors-index.json'))
blob=open(R+'semantic-vectors-binary.bin','rb').read()
mapb=open(R+'semantic-map.bin','rb').read()
mapi=json.load(open(R+'semantic-map-index.json'))
dig_idx=idx['provenanceDigest']; dig_bin=blob[20:52].hex(); dig_map=mapb[20:52].hex()
SV="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
print("DIGESTS index",dig_idx,"binary",dig_bin,"map",dig_map, "generation file", open(SV+'.generation').read().strip() if os.path.exists(SV+'.generation') else 'none')
assert dig_idx==dig_bin==dig_map
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
            b=numeric_part(s['i']); ids.extend('d%d'%(b+k) for k in range(1,s['n']))
    return ids
row_of={}; doc_of={}; ok=0
vols=idx['volumes']
print("volume keys:",list(vols[0]))
for v in vols:
    vid=v.get('id') or v.get('v') or v.get('volumeId')
    ids=decode(v['seg']); ok+= len(ids)==v['n']
    for k,i in enumerate(ids): row_of[(vid,i)]=v['r']+k; doc_of[v['r']+k]=(vid,i)
print("round trip ok volumes:",ok,"of",len(vols))
ver,dims,docs,cents=struct.unpack('<IIII',blob[4:20]); bpr=dims//8
rows=[int.from_bytes(blob[64+r*bpr:64+(r+1)*bpr],'big') for r in range(docs)]
pc=lambda x: bin(x).count('1')
ED2=('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
dates={(v,d):i for v,d,i in c.execute("SELECT volume_id,document_id,date_iso FROM document_dates")}
incache=set(c.execute("SELECT volume_id,document_id FROM document_cache").fetchall())
# baseline
rnd=random.Random(1877); ds=[pc(rows[rnd.randrange(docs)]^rows[rnd.randrange(docs)]) for _ in range(20000)]
ds.sort(); m=sum(ds)/len(ds); sd=(sum((x-m)**2 for x in ds)/len(ds))**.5
print("RANDOM-PAIR baseline (20,000 pairs, Random(1877)): mean %.1f sd %.1f p1 %d min %d"%(m,sd,ds[200],ds[0]))
def nn(anchor,k=25):
    q=rows[row_of[anchor]]; best=[]
    for r in range(docs):
        if r==row_of[anchor]: continue
        d=pc(q^rows[r])
        if len(best)<k: heapq.heappush(best,(-d,r))
        elif -best[0][0]>d: heapq.heapreplace(best,(-d,r))
    return sorted((-a,doc_of[r]) for a,r in best)
anchors=[('frus1898','d490'),('frus1958-60v06','d517'),('frus1933v05','d241')]
out={}
for a in anchors:
    L=nn(a); out['/'.join(a)]=L
    ad=(dates.get(a) or '')[:3]
    print("\nNN of",'/'.join(a),"date",dates.get(a),"; 25th-neighbour distance",L[-1][0])
    for d,(v,i) in L:
        flag=[]
        if (v,i) not in incache: flag.append('NOT-IN-INDEX')
        if v in ED2: flag.append('Ed2')
        dd=dates.get((v,i)) or ''
        if dd[:3]!=ad: flag.append('OTHER-DECADE')
        print("  %3d %s/%s %s %s"%(d,v,i,dd,' '.join(flag)))
json.dump(out,open('s15_nn.json','w'))
# near-duplicate check on reading set
print("\nNEAR-DUP check (nearest neighbour distance) for reading set:")
for l in open('reading_ids.txt'):
    v,i=l.split()
    if (v,i) not in row_of: print(' ',v,i,'not in vectors'); continue
    L=nn((v,i),1); print('  %s/%s nearest %d %s/%s'%(v,i,L[0][0],L[0][1][0],L[0][1][1]))
# centroid cosine
vid_list=[v.get('id') or v.get('v') or v.get('volumeId') for v in vols]
base=64+docs*bpr
def cent(j):
    o=base+j*(dims+4); codes=struct.unpack('%db'%dims,blob[o:o+dims]); s=struct.unpack('<f',blob[o+dims:o+dims+4])[0]; return [x*s for x in codes]
def cos(a,b): return sum(x*y for x,y in zip(a,b))/math.sqrt(sum(x*x for x in a)*sum(y*y for y in b))
C={v:cent(k) for k,v in enumerate(vid_list)}
focus=['frus1872p2v1','frus1898','frus1902','frus1933v05','frus1934v05','frus1945v09','frus1958-60v06','frus1961-63v10','frus1961-63v11','frus1964-68v32','frus1977-80v23']
print("\nCENTROID cosine matrix (volume centroids):")
print('            '+' '.join(x[4:14].rjust(10) for x in focus))
for a in focus: print(a[4:16].ljust(12)+' '.join(('%.3f'%cos(C[a],C[b])).rjust(10) for b in focus))
for a in ['frus1898','frus1958-60v06','frus1977-80v23']:
    top=sorted(((cos(C[a],C[b]),b) for b in vid_list if b!=a),reverse=True)[:6]
    print("nearest volumes to",a,[(b,round(s,3)) for s,b in top])
# map
print("\nMAP header:",struct.unpack('<IIII',mapb[4:20]))
cl=mapi.get('clusters'); print("map index keys",list(mapi)[:10])
