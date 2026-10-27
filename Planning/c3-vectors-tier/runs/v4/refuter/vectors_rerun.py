# Refuter: independent re-run of the session's nearest-neighbour lists from the bundle's binary.
# Decode: index.volumes[].v (volume id), r (first row), n (rows), seg[] = {s: offset within the volume's rows,
# i: first document id, n: run length}; a run of n>1 continues d<base+1> ... d<base+n-1>. Binary: 'FRSV', <IIII version dims docs centroids,
# digest 32 bytes, 12 pad; rows of dims/8 bytes from offset 64 (sign bits, MSB-first).
import json, struct, heapq, sys, time
R="/Applications/FRUS Explorer.app/Contents/Resources/"
idx=json.load(open(R+'semantic-vectors-index.json'))
blob=open(R+'semantic-vectors-binary.bin','rb').read()
assert blob[:4]==b'FRSV'
ver,dims,docs,cents=struct.unpack('<IIII',blob[4:20]); bpr=dims//8
dig=blob[20:52].hex()
mapb=open(R+'semantic-map.bin','rb').read(52); mdig=mapb[20:52].hex()
gen=open('/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation').read().strip()
print("digest index==binary==map==.generation:", idx['provenanceDigest']==dig==mdig==gen, dig)
print("header: version",ver,"dims",dims,"docs",docs,"centroids",cents,"| index documentCount",idx['documentCount'])
row_of={}; doc_of={}
bad=0
for v in idx['volumes']:
    vid=v['v']; count=0
    for s in v['seg']:
        first=s['i']; m=__import__('re').fullmatch(r'd(\d+)', first)
        for k in range(s['n']):
            if k==0: did=first
            else:
                assert m, (vid, first)
                did='d%d'%(int(m.group(1))+k)
            row=v['r']+s['s']+k
            row_of[(vid,did)]=row; doc_of[row]=(vid,did); count+=1
    if count!=v['n']: bad+=1
print("volumes:",len(idx['volumes']),"decoded rows:",len(row_of),"volumes whose segments do not sum to n:",bad)
assert len(row_of)==docs
rows=[int.from_bytes(blob[64+r*bpr:64+(r+1)*bpr],'big') for r in range(docs)]
def nn(anchor,k=25):
    a=row_of[anchor]; q=rows[a]; best=[]
    for r in range(docs):
        if r==a: continue
        d=bin(q^rows[r]).count('1')
        if len(best)<k: heapq.heappush(best,(-d,-r))
        elif -best[0][0]>d: heapq.heapreplace(best,(-d,-r))
    return sorted(((-nd, doc_of[-nr]) for nd,nr in best), key=lambda x:(x[0], x[1]))
sess=json.load(open('/Users/jbotts/frus-analysis/c3v/runs/v4/s15_nn.json'))
for a in [('frus1898','d490'),('frus1958-60v06','d517'),('frus1933v05','d241')]:
    t=time.time(); L=nn(a)
    mine=[(d,v,i) for d,(v,i) in L]
    theirs=[(d,v,i) for d,(v,i) in sess['/'.join(a)]]
    print("\nNN of %s/%s (%.1fs): 25th at %d"%(a[0],a[1],time.time()-t,L[-1][0]))
    print("  reproduces the session's list exactly (same 25 pairs, same distances, same order):", mine==theirs)
    print("  same set of 25 pairs:", set(mine)==set(theirs))
    for d,v,i in mine[:8]: print("   %3d %s/%s"%(d,v,i))
    if set(mine)!=set(theirs): print("  mine-not-theirs:", set(mine)-set(theirs), " theirs-not-mine:", set(theirs)-set(mine))
# which rows are missing a vector among the 16 cited pairs
cited=[('frus1870','d197'),('frus1873p1v2','d50'),('frus1874','d552'),('frus1898','d490'),('frus1898','ch83'),('frus1902','d294'),('frus1933v05','d241'),('frus1934v05','d170'),('frus1945v09','d745'),('frus1958-60v06','d517'),('frus1958-60v06','d567'),('frus1961-63v10','d202'),('frus1961-63v11','d34'),('frus1969-76ve11p1','d278'),('frus1977-80v23','d19'),('frus1977-80v23','d98')]
print("\ncited pairs without a vector row:", [p for p in cited if p not in row_of])
# map cluster membership for the anchors and the two vector-reached documents
mapfull=open(R+'semantic-map.bin','rb').read()
mi=json.load(open(R+'semantic-map-index.json'))
byid={c['id']:c for c in mi['clusters']}
for p in [('frus1898','d490'),('frus1958-60v06','d517'),('frus1933v05','d241'),('frus1961-63v10','d202'),('frus1977-80v23','d19'),('frus1874','d552'),('frus1969-76ve11p1','d278')]:
    o=64+row_of[p]*6; x,y,cid=struct.unpack('<hhH',mapfull[o:o+6])
    print("map:", '/'.join(p), 'unclustered' if cid==0xFFFF else ('cluster %d %s n=%d'%(cid, byid[cid]['terms'], byid[cid]['documentCount'])))
unc=sum(1 for r in range(docs) if struct.unpack('<H',mapfull[64+r*6+4:64+r*6+6])[0]==0xFFFF)
print("unclustered placements: %d of %d (%.1f%%)"%(unc,docs,100*unc/docs))
