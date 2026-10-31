import json,pickle,random,sqlite3,struct
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ix=json.load(open(R+"semantic-vectors-index.json"))
vinfo={v["v"]:v for v in ix["volumes"]}
row_of,doc_of=pickle.load(open("vec_rows.pkl","rb"))
bits=np.load("vec_bits.npy")
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
indb=set(r[0] for r in db.execute("select distinct volume_id from document_cache"))
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
cache={}
def shard(v):
    if v not in cache:
        b=open(SH+v+".vec","rb").read(); ver,dims,n=struct.unpack("<III",b[4:16])
        codes=np.frombuffer(b,dtype=np.int8,count=n*dims,offset=64).reshape(n,dims).astype(np.float32)
        sc=np.frombuffer(b,dtype=np.float32,count=n,offset=64+n*dims)
        cache[v]=(codes,sc)
    return cache[v]
def vec(key):
    v,d=doc_of[key]; codes,sc=shard(v); lr=key-vinfo[v]["r"]; return codes[lr]*sc[lr]
def dist(a):
    return np.bitwise_count(bits^bits[a]).sum(axis=1).astype(int)
# baseline 25th neighbour over 200 docs
rnd=random.Random(1877); k25=[];k1=[]
for _ in range(200):
    a=rnd.randrange(len(bits)); d=dist(a); d[a]=999; s=np.sort(d); k25.append(s[24]); k1.append(s[0])
k25=np.array(k25); k1=np.array(k1)
print("BASELINE 200-doc sample (seed 1877): 25th-neighbour median %d quartiles %d/%d ; nearest-neighbour median %d, quartiles %d/%d"%(np.median(k25),np.percentile(k25,25),np.percentile(k25,75),np.median(k1),np.percentile(k1,25),np.percentile(k1,75)))
anchors=[("frus1917-72PubDipv08","d31"),("frus1969-76v38p2","d105"),("frus1964-68v29p2","d46"),("frus1917-72PubDipv07","d100")]
for a in anchors:
    ar=row_of[a]; d=dist(ar); d[ar]=999; order=np.argsort(d,kind="stable")
    av=vec(ar)
    print("\nANCHOR",a[0]+"/"+a[1],"25th-neighbour distance",d[order[24]],"nearest",d[order[0]])
    for r in order[:12]:
        v,dd=doc_of[r]; cos=float(np.dot(av,vec(r))); cal=(cos-0.40)/0.60
        t=db.execute("select substr(replace(header,char(10),' '),1,90),is_front_matter,is_editorial_note from document_cache where volume_id=? and document_id=?",(v,dd)).fetchone()
        print("  ham %3d  %s/%s  rawcos %.3f calibrated %.0f%%  in_db=%s  %s"%(d[r],v,dd,cos,100*cal,v in indb, (t[0] if t else "NOT IN document_cache")))
