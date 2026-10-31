# Independent re-implementation: decode ids per Appendix A.3 (segments s/i/n), Hamming over 512 sign bits from the bundle's binary, rerank 800 by int8 cosine from the shards.
import json,struct,numpy as np
RES="/Applications/FRUS Explorer.app/Contents/Resources/"; SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
ix=json.load(open(RES+"semantic-vectors-index.json"))
def numeric_part(i):
    if not i.startswith("d"): return None
    s=i[1:]
    if not s.isdigit() or (len(s)>1 and s[0]=="0"): return None
    return int(s)
doc_of=[None]*ix["documentCount"]; row_of={}; vol_rows={}
ok=0
for v in ix["volumes"]:
    ids=[]
    for seg in v["seg"]:
        assert seg["s"]==len(ids), (v["v"],seg)
        ids.append(seg["i"])
        if seg["n"]>1:
            b=numeric_part(seg["i"]); ids+=["d%d"%(b+k) for k in range(1,seg["n"])]
    assert len(ids)==v["n"]; ok+=1
    vol_rows[v["v"]]=(v["r"],v["n"])
    for k,i in enumerate(ids): doc_of[v["r"]+k]=(v["v"],i); row_of[(v["v"],i)]=v["r"]+k
print("decoded volumes",ok,"rows with id",sum(1 for x in doc_of if x),"of",ix["documentCount"])
blob=open(RES+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bpr=dims//8
signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
# bit-count lookup (no reliance on np.bitwise_count)
POP=np.array([bin(i).count("1") for i in range(256)],dtype=np.uint8)
def hamming_all(row): return POP[np.bitwise_xor(signs,signs[row])].sum(axis=1,dtype=np.int32)
_sh={}
def shard(v):
    if v not in _sh:
        b=open(SH+v+".vec","rb").read(); n=struct.unpack("<I",b[12:16])[0]
        codes=np.frombuffer(b,dtype=np.int8,count=n*512,offset=64).reshape(n,512)
        sc=np.frombuffer(b,dtype=np.float32,count=n,offset=64+n*512); _sh[v]=(codes,sc)
    return _sh[v]
def vec(row):
    v,i=doc_of[row]; r0,n=vol_rows[v]; codes,sc=shard(v); return codes[row-r0].astype(np.float32)*sc[row-r0]
def cos(a,b): x=vec(a); y=vec(b); return float(x@y/(np.linalg.norm(x)*np.linalg.norm(y)))
anchor=("frus1917-72PubDipv07","d73"); row=row_of[anchor]
h=hamming_all(row); h[row]=99999
print("anchor",anchor,"row",row,"hamming top10:",sorted(h)[:10])
cand=np.argpartition(h,800)[:800]
sc=sorted([(cos(row,int(c)),int(c)) for c in cand],reverse=True)[:10]
for c,r in sc: print("  cos_raw %.3f cal %.3f ham %3d  %s/%s"%(c,(c-0.40)/0.60,h[r],*doc_of[r]))
