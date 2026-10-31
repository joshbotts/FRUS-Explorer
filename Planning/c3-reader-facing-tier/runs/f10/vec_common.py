import json,struct,numpy as np,os,glob
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
ix=json.load(open(RES+"semantic-vectors-index.json"))
def numeric_part(doc_id):
    if not doc_id.startswith("d"): return None
    digits=doc_id[1:]
    if not digits or not digits.isdigit(): return None
    if len(digits)>1 and digits[0]=="0": return None
    return int(digits)
def decode_segments(segments):
    ids=[]
    for seg in segments:
        assert seg["s"]==len(ids)
        ids.append(seg["i"])
        if seg["n"]>1:
            base=numeric_part(seg["i"])
            ids.extend("d%d"%(base+k) for k in range(1,seg["n"]))
    return ids
vol_names=[]; row_of={}; doc_of=[None]*ix["documentCount"]; vol_rows={}
for v in ix["volumes"]:
    ids=decode_segments(v["seg"]); assert len(ids)==v["n"]
    vol_names.append(v["v"]); vol_rows[v["v"]]=(v["r"],v["n"])
    for k,i in enumerate(ids):
        row_of[(v["v"],i)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],i)
blob=open(RES+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
digest_bin=blob[20:52].hex()
bpr=dims//8
signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
cent_off=64+docs*bpr
cent_codes=np.frombuffer(blob,dtype=np.int8,count=cents*dims,offset=cent_off) if False else None
# centroids: each (dims int8 codes + float32 scale) contiguous
cent=[]
for c in range(cents):
    o=cent_off+c*(dims+4)
    codes=np.frombuffer(blob,dtype=np.int8,count=dims,offset=o).astype(np.float32)
    sc=struct.unpack("<f",blob[o+dims:o+dims+4])[0]
    cent.append(codes*sc)
cent=np.array(cent)
mp=open(RES+"semantic-map.bin","rb").read()
map_digest=mp[20:52].hex()
map_docs=struct.unpack("<I",mp[8:12])[0]
placements=np.frombuffer(mp,dtype=np.dtype([("x","<i2"),("y","<i2"),("c","<u2")]),count=map_docs,offset=64)
def hamming_all(row):
    x=np.bitwise_xor(signs,signs[row])
    return np.bitwise_count(x).sum(axis=1)
