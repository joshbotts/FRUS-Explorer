import json,pickle,sqlite3,struct,collections
import numpy as np
from docs_list import COLL
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ix=json.load(open(R+"semantic-vectors-index.json"))
vl=[v["v"] for v in ix["volumes"]]; vinfo={v["v"]:v for v in ix["volumes"]}
row_of,doc_of=pickle.load(open("vec_rows.pkl","rb")); bits=np.load("vec_bits.npy")
blob=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bpr=dims//8
co=64+docs*bpr; stride=dims+4
C=np.zeros((cents,dims),dtype=np.float32)
for i in range(cents):
    o=co+i*stride
    codes=np.frombuffer(blob,dtype=np.int8,count=dims,offset=o).astype(np.float32); sc=struct.unpack("<f",blob[o+dims:o+dims+4])[0]
    C[i]=codes*sc
C/=np.linalg.norm(C,axis=1,keepdims=True)
print("== CENTROID SIMILARITY (semantic-vectors-binary.bin centroid block; first 553 = volumes in index order; raw cosine; random-volume-pair baseline below)")
rnd=np.random.RandomState(1877); idx=rnd.randint(0,553,size=(5000,2)); idx=idx[idx[:,0]!=idx[:,1]]
cs=(C[idx[:,0]]*C[idx[:,1]]).sum(axis=1); print("baseline random volume pairs: mean %.3f sd %.3f p99 %.3f"%(cs.mean(),cs.std(),np.percentile(cs,99)))
for a in ["frus1917-72PubDipv08","frus1977-80v30","frus1964-68v27"]:
    i=vl.index(a); s=C[:553]@C[i]; s[i]=-1; o=np.argsort(-s)[:8]
    print(a,"->",[(vl[j],round(float(s[j]),3)) for j in o])
print("\n== MAP (semantic-map.bin placements; cluster labels from semantic-map-index.json)")
mp=open(R+"semantic-map.bin","rb").read(); mdocs=struct.unpack("<I",mp[8:12])[0]
pl=np.frombuffer(mp,dtype=np.dtype([("x","<i2"),("y","<i2"),("c","<u2")]),count=mdocs,offset=64)
mi=json.load(open(R+"semantic-map-index.json")); print("map-index keys",list(mi.keys())[:8])
cl=mi.get("clusters") or mi.get("labels")
def label(c):
    for x in cl:
        if x.get("id",x.get("c"))==c or x.get("cluster")==c: return x.get("terms") or x.get("label") or x
    return None
uncl=int((pl["c"]==0xFFFF).sum()); print("corpus unclustered: %d of %d (%.1f%%)"%(uncl,mdocs,100*uncl/mdocs))
cnt=collections.Counter()
for v,d in COLL:
    r=row_of[(v,d)]; c=int(pl["c"][r]); cnt[c]+=1
    print("  %s/%s cluster %s %s"%(v,d,"UNCLUSTERED" if c==0xFFFF else c,"" if c==0xFFFF else str(label(c))[:90]))
print("collection unclustered: %d of %d"%(cnt[0xFFFF],len(COLL)))
# era-matched baseline: all docs in regional scope volumes
vols=[l.strip() for l in open("scope_vols.txt")]
rows=np.concatenate([np.arange(vinfo[v]["r"],vinfo[v]["r"]+vinfo[v]["n"]) for v in vols if v in vinfo])
print("scope-volume baseline (76 volumes, all rows incl. apparatus): unclustered %d of %d (%.1f%%)"%(int((pl["c"][rows]==0xFFFF).sum()),len(rows),100*(pl["c"][rows]==0xFFFF).mean()))
print("\n== SEMANTIC JOIN: top-60 Hamming neighbours of frus1969-76v38p2/d105 into document_dates and document_sources")
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
a=row_of[("frus1969-76v38p2","d105")]; d=np.bitwise_count(bits^bits[a]).sum(axis=1).astype(int); d[a]=999
nn=np.argsort(d,kind="stable")[:60]
dec=collections.Counter(); rg=collections.Counter(); notdb=0; not_in_scope=0
for r in nn:
    v,dd=doc_of[r]
    x=db.execute("select date_iso from document_dates where volume_id=? and document_id=?",(v,dd)).fetchone()
    s=db.execute("select repository,record_group from document_sources where volume_id=? and document_id=?",(v,dd)).fetchone()
    if x is None and s is None: notdb+=1
    dec[(x[0][:3]+"0s") if x and x[0] else "undated"]+=1; rg[(s[0],s[1]) if s else None]+=1
    if v not in vols: not_in_scope+=1
print("decades:",sorted(dec.items())); print("came-from (repository, RG):",rg.most_common(6)); print("not in db:",notdb,"; outside the 76-volume scope:",not_in_scope,"; nearest",d[nn[0]],"60th",d[nn[59]])
print("\n== NEAR-DUPLICATE SCAN among the %d collection documents (min Hamming over all pairs)"%len(COLL))
rs=[row_of[k] for k in COLL]; pairs=[]
for i in range(len(rs)):
    for j in range(i+1,len(rs)):
        pairs.append((int(np.bitwise_count(bits[rs[i]]^bits[rs[j]]).sum()),COLL[i],COLL[j]))
pairs.sort(); print("closest 5 pairs:",pairs[:5]); print("median pair distance",np.median([p[0] for p in pairs]))
