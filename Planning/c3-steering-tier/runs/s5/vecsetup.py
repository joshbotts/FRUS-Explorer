import json, struct, numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
ix=json.load(open(R+"semantic-vectors-index.json"))
def numeric_part(d):
    if not d.startswith("d"): return None
    dg=d[1:]
    if not dg or not dg.isdigit(): return None
    if len(dg)>1 and dg[0]=="0": return None
    return int(dg)
def decode_segments(segs):
    ids=[]
    for s in segs:
        assert s["s"]==len(ids)
        ids.append(s["i"])
        if s["n"]>1:
            b=numeric_part(s["i"]); ids.extend(f"d{b+k}" for k in range(1,s["n"]))
    return ids
vol_rows={}   # volume -> (rowOffset, [ids])
row_of={}; doc_of=[None]*ix["documentCount"]
for v in ix["volumes"]:
    ids=decode_segments(v["seg"]); assert len(ids)==v["n"]
    vol_rows[v["v"]]=(v["r"],ids)
    for k,i in enumerate(ids):
        row_of[(v["v"],i)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],i)
blob=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
bdigest=blob[20:52].hex()
bpr=dims//8
signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
cent_off=64+docs*bpr
cent_codes=np.frombuffer(blob,dtype=np.int8,count=cents*dims,offset=cent_off) if False else None
# centroid rows are (dims int8 codes + float32 scale) each: "centroids x (dims+4) B (int8 codes, then Float32 scale)"
cent_raw=np.frombuffer(blob,dtype=np.uint8,count=cents*(dims+4),offset=cent_off).reshape(cents,dims+4)
mp=open(R+"semantic-map.bin","rb").read()
mdigest=mp[20:52].hex()
def hamming_all(row):
    x=np.bitwise_xor(signs,signs[row])
    return np.bitwise_count(x).sum(axis=1)
def shard(vol):
    b=open(SH+vol+".vec","rb").read()
    assert b[:4]==b"FRSS"
    ver,dm,nd=struct.unpack("<III",b[4:16]); dg=b[16:48].hex()
    codes=np.frombuffer(b,dtype=np.int8,count=nd*dm,offset=64).reshape(nd,dm)
    scales=np.frombuffer(b,dtype=np.float32,count=nd,offset=64+nd*dm)
    return dg,codes,scales
