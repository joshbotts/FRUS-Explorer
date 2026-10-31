import json, random, re, sqlite3, statistics, struct, glob, os
import numpy as np
RES="/Applications/FRUS Explorer.app/Contents/Resources"
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors"
idx=json.load(open(RES+"/semantic-vectors-index.json"))
def numeric_part(doc_id):
    digits=doc_id[1:]
    if not doc_id.startswith("d") or not digits.isdigit(): return None
    if len(digits)>1 and digits[0]=="0": return None
    return int(digits)
row_of,doc_of={},{}
for v in idx["volumes"]:
    ids=[]
    for seg in v["seg"]:
        assert seg["s"]==len(ids)
        ids.append(seg["i"])
        if seg["n"]>1:
            base=numeric_part(seg["i"])
            ids.extend(f"d{base+k}" for k in range(1,seg["n"]))
    assert len(ids)==v["n"]
    for k,d in enumerate(ids):
        row_of[(v["v"],d)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],d)
blob=open(RES+"/semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
digests={"index":idx["provenanceDigest"],"binary":blob[20:52].hex(),
 "map":open(RES+"/semantic-map.bin","rb").read(52)[20:52].hex(),
 "manifest":json.load(open(RES+"/semantic-shards-manifest.json"))["provenanceDigest"],
 "generation_file":open(SH+"/.generation").read().strip()}
bits=np.frombuffer(blob,dtype=">u8",count=docs*dims//64,offset=64).reshape(docs,dims//64)
ED2=("frus1951-54IranEd2","frus1969-76ve15p2Ed2")
skip=np.array([doc_of[r][0] in ED2 for r in range(docs)])
def distances(row):
    d=np.bitwise_count(bits^bits[row]).sum(axis=1).astype(np.int64)
    d[skip]=1<<20; d[row]=1<<20
    return d
def nearest(key,k=25):
    d=distances(row_of[key])
    return [(int(d[r]),doc_of[int(r)]) for r in np.argsort(d,kind="stable")[:k]]
