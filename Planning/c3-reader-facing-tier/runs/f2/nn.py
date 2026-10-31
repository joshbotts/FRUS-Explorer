import json,struct,pickle,sys,sqlite3
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"; SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
idx=json.load(open(R+"semantic-vectors-index.json")); dig=idx["provenanceDigest"]
row_of,doc_of,vol_rows,dims=pickle.load(open("vecmaps.pkl","rb"))
blob=open(R+"semantic-vectors-binary.bin","rb").read()
docs=struct.unpack("<I",blob[12:16])[0]; bpr=dims//8
signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
cache={}
def shard(vol):
    if vol in cache: return cache[vol]
    b=open(SH+vol+".vec","rb").read()
    assert b[:4]==b"FRSS"; n=struct.unpack("<I",b[12:16])[0]; d=struct.unpack("<I",b[8:12])[0]
    assert b[16:48].hex()==dig, "digest mismatch "+vol
    codes=np.frombuffer(b,dtype=np.int8,count=n*d,offset=64).reshape(n,d).astype(np.int32)
    sc=np.frombuffer(b,dtype=np.float32,count=n,offset=64+n*d)
    cache[vol]=(codes,sc); return cache[vol]
def vec(key):
    vol,d=key; r0,ids=vol_rows[vol]; i=ids.index(d); c,s=shard(vol); return c[i],s[i]
ED2={"frus1951-54IranEd2","frus1969-76ve15p2Ed2"}
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
present={r[0] for r in c.execute("SELECT DISTINCT volume_id FROM document_cache")}
for anchor in sys.argv[1:]:
    v,d=anchor.split("/"); ar=row_of[(v,d)]
    h=np.bitwise_count(np.bitwise_xor(signs,signs[ar])).sum(axis=1); h[ar]=9999
    pool=np.argsort(h,kind="stable")[:800]
    qa,qs=vec((v,d)); out=[]
    for r in pool:
        key=doc_of[int(r)]
        if key[0] in ED2: continue
        cc,ss=vec(key); cos=float(qs*ss*np.dot(qa,cc)); out.append((cos,key,int(h[r])))
    out.sort(reverse=True)
    print("ANCHOR",anchor,"shards touched",len(cache),"all digests match")
    for cos,key,hh in out[:10]:
        hd=c.execute("SELECT substr(header,1,110) FROM document_cache WHERE volume_id=? AND document_id=?",key).fetchone()
        print("  %s/%s hamming %d raw-cos %.3f calibrated %.3f %s | %s"%(key[0],key[1],hh,cos,(cos-0.40)/0.60,"" if key[0] in present else "[ABSENT FROM INDEX]",hd[0] if hd else "?"))
