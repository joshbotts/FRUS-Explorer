import json,struct,sqlite3,collections,numpy as np
RES="/Applications/FRUS Explorer.app/Contents/Resources/"; SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
ix=json.load(open(RES+"semantic-vectors-index.json"))
def np_(i):
    s=i[1:]; return int(s) if i.startswith("d") and s.isdigit() and not (len(s)>1 and s[0]=="0") else None
doc_of=[None]*ix["documentCount"]; row_of={}; vol_rows={}
for v in ix["volumes"]:
    ids=[]
    for seg in v["seg"]:
        ids.append(seg["i"])
        if seg["n"]>1: b=np_(seg["i"]); ids+=["d%d"%(b+k) for k in range(1,seg["n"])]
    vol_rows[v["v"]]=(v["r"],v["n"])
    for k,i in enumerate(ids): doc_of[v["r"]+k]=(v["v"],i); row_of[(v["v"],i)]=v["r"]+k
blob=open(RES+"semantic-vectors-binary.bin","rb").read(); ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bpr=dims//8
signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
POP=np.array([bin(k).count("1") for k in range(256)],dtype=np.uint8)
def ham_all(r): h=POP[np.bitwise_xor(signs,signs[r])].sum(axis=1,dtype=np.int32); return h
def ham(a,b): return int(POP[np.bitwise_xor(signs[a],signs[b])].sum())
_sh={}
def vec(row):
    v,i=doc_of[row]; r0,n=vol_rows[v]
    if v not in _sh:
        b=open(SH+v+".vec","rb").read(); m=struct.unpack("<I",b[12:16])[0]
        _sh[v]=(np.frombuffer(b,dtype=np.int8,count=m*512,offset=64).reshape(m,512),np.frombuffer(b,dtype=np.float32,count=m,offset=64+m*512))
    c,s=_sh[v]; return c[row-r0].astype(np.float32)*s[row-r0]
def cos(a,b): x=vec(a);y=vec(b); return float(x@y/(np.linalg.norm(x)*np.linalg.norm(y)))
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
# V2
r=row_of[("frus1917-72PubDipv07","d73")]; h=ham_all(r); h[r]=99999; near=np.argsort(h)[:30]
dec=collections.Counter(); src=collections.Counter()
for n in near:
    v,i=doc_of[n]
    d=db.execute("select dd.date_iso,s.repository,s.record_group from document_cache c left join document_dates dd on dd.volume_id=c.volume_id and dd.document_id=c.document_id left join document_sources s on s.volume_id=c.volume_id and s.document_id=c.document_id where c.volume_id=? and c.document_id=?",(v,i)).fetchone()
    dec[(d[0] or 'none')[:3]+"0s" if d and d[0] else "none"]+=1; src[(d[1],d[2]) if d else None]+=1
print("V2: 30 nearest of d73 Hamming min %d max %d; decades %s; sources %s"%(h[near].min(),h[near].max(),dict(dec),dict(src)))
print("    (memo: 87-114; 1960s 14, 1950s 15, 1940s 1; RG59 13, RG306 7, Johnson 2, Eisenhower 3, Kennedy 1, RG286 1, CIA 1, none 2)")
# V5
a=row_of[("frus1917-72PubDipv06","d141")]; b=row_of[("frus1961-63v04","d108")]; print("V5 reprint d141~v04/d108: ham",ham(a,b),"cos %.3f"%cos(a,b),"(memo 56, 0.976)")
a=row_of[("frus1917-72PubDipv06","d140")]; b=row_of[("frus1961-63v04","d81")]; print("V5 reprint d140~v04/d81: ham",ham(a,b),"cos %.3f"%cos(a,b),"(memo 53, 0.985)")
coll=[tuple(p) for p in json.load(open("/Users/jbotts/frus-analysis/c3f/runs/f10/refuter/pairs.json"))["docs"]]
rows=[row_of[p] for p in coll]
pairs=sorted((ham(rows[i],rows[j]),coll[i],coll[j]) for i in range(30) for j in range(i+1,30))
print("V5 closest pairs among the 30:",[(x[0],"/".join(x[1]),"/".join(x[2])) for x in pairs[:4]],"(memo 76 d126~d133; 88; 92; 94)")
mins=[]
for p,rw in zip(coll,rows):
    hh=ham_all(rw); hh[rw]=99999; j=int(np.argmin(hh)); mins.append((int(hh[j]),"/".join(p),"/".join(doc_of[j])))
print("V5 collection docs with a corpus neighbour at <=40 bits:",[m for m in mins if m[0]<=40],"(memo: d190~d185 at 32)")
