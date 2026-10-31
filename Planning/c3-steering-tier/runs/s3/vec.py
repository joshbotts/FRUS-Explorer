import json, random, re, sqlite3, statistics, struct, sys
import numpy as np
RES="/Applications/FRUS Explorer.app/Contents/Resources"; DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
SV="/Users/jbotts/frus-analysis/c3/SemanticVectors"
idx=json.load(open(RES+"/semantic-vectors-index.json"))
def numeric_part(doc_id):
    digits=doc_id[1:]
    if not doc_id.startswith("d") or not digits.isdigit(): return None
    if len(digits)>1 and digits[0]=="0": return None
    return int(digits)
row_of,doc_of={},{}; nvol=0
for v in idx["volumes"]:
    ids=[]
    for seg in v["seg"]:
        assert seg["s"]==len(ids); ids.append(seg["i"])
        if seg["n"]>1:
            base=numeric_part(seg["i"]); ids.extend("d%d"%(base+k) for k in range(1,seg["n"]))
    assert len(ids)==v["n"]; nvol+=1
    for k,d in enumerate(ids): row_of[(v["v"],d)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],d)
blob=open(RES+"/semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
shard=open(SV+"/frus1947v07.vec","rb").read(48)
digests={"index":idx["provenanceDigest"],"binary":blob[20:52].hex(),
 "map":open(RES+"/semantic-map.bin","rb").read(52)[20:52].hex(),
 "manifest":json.load(open(RES+"/semantic-shards-manifest.json"))["provenanceDigest"],
 "shard frus1947v07.vec":shard[16:48].hex(),
 "generation":open(SV+"/.generation").read().strip()}
print("digests",json.dumps(digests,indent=1)); assert len(set(digests.values()))==1
print("index generated:",idx.get("generated"),"| round trip OK for",nvol,"volumes; rows",len(row_of),"header docs",docs,"dims",dims,"centroids",cents)
print("calibration:",json.dumps(idx.get("retrieval",{}).get("scoreCalibration"))[:300])
bits=np.frombuffer(blob,dtype=">u8",count=docs*dims//64,offset=64).reshape(docs,dims//64)
ED2=("frus1951-54IranEd2","frus1969-76ve15p2Ed2")
skip=np.array([doc_of[r][0] in ED2 for r in range(docs)])
def distances(row):
    d=np.bitwise_count(bits^bits[row]).sum(axis=1).astype(np.int64); d[skip]=1<<20; d[row]=1<<20; return d
def nearest(key,k=25):
    d=distances(row_of[key]); return [(int(d[r]),doc_of[int(r)]) for r in np.argsort(d,kind="stable")[:k]]
rng=random.Random(1877)
pairs=[int(np.bitwise_count(bits[rng.randrange(docs)]^bits[rng.randrange(docs)]).sum()) for _ in range(20000)]
mean,sd=statistics.mean(pairs),statistics.pstdev(pairs); first=sorted(pairs)[len(pairs)//100]
kth=sorted(int(np.sort(distances(r))[24]) for r in random.Random(1878).sample(range(docs),200))
print("random pairs: mean %.1f sd %.1f 1st pct %d"%(mean,sd,first))
print("25th-neighbour over 200 random rows: min %d p10 %d median %d p90 %d"%(kth[0],kth[20],kth[100],kth[180]))
line=mean-8*sd; print("near-dup line (mean-8sd): %.1f"%line)
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
def joined(key):
    return con.execute("SELECT c.header, c.body_text, t.date_iso FROM document_cache c LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?",key).fetchone()
hits=set(con.execute("""SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH 'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')""").fetchall())
literal=re.compile(r"corrupt\w*|brib\w*|graft\w*|kick-?backs?|embezzl\w*|pay-?offs?|illicit payment|improper payment|questionable payment",re.I)
anchors=[("frus1947v07","d583"),("frus1969-76ve09p2","d122"),("frus1969-76ve11p1","d159"),("frus1922v01","d841")]
out={}
for a in anchors:
    a_date=(joined(a) or ("","",""))[2] or ""
    print("\nANCHOR",a,a_date)
    rows=[]
    for h,key in nearest(a,25):
        r=joined(key)
        if r is None: rows.append((h,key,"NOT IN THIS DATABASE")); print(h,key,"NOT IN DB"); continue
        header,body,date=r; date=date or ""
        fl=("IN-SCOPE" if key in hits else "OUTSIDE","SAME-DECADE" if date and date[:3]==a_date[:3] else "OTHER-DECADE","LITERAL" if literal.search((header or "")+" "+body) else "ABSENT")
        rows.append((h,key,date)+fl); print(h,key[0]+"/"+key[1],date,*fl,"|",(header or "")[:80].replace("\n"," "))
    out["%s/%s"%a]=rows
cited=[tuple(x.split("/")) for x in sys.argv[1:]]
def near_duplicates(scope):
    rr=sorted(row_of[k] for k in scope if k in row_of); found=[]
    for i,a in enumerate(rr[:-1]):
        d=np.bitwise_count(bits[rr[i+1:]]^bits[a]).sum(axis=1)
        found+=[(int(h),doc_of[a],doc_of[b]) for h,b in zip(d,rr[i+1:]) if h<line]
    return sorted(found)
nd_hits=near_duplicates(hits)
print("\nnear-duplicate pairs in the hit set (%d docs): %d"%(len(hits),len(nd_hits)))
for x in nd_hits[:60]: print(x)
nnd=[]
for k in cited:
    others=[row_of[o] for o in cited if o!=k and o in row_of]
    d=np.bitwise_count(bits[others]^bits[row_of[k]]).sum(axis=1); nnd.append((k,int(d.min())))
print("\ncited set nearest-in-set distance:"); [print(k[0]+"/"+k[1],d) for k,d in nnd]
print("cited-set near-dup pairs:",near_duplicates(set(cited)))
json.dump({"digests":digests,"mean":mean,"sd":sd,"first":first,"kth":kth,"neighbours":out,"nd_hits":nd_hits,"cited_nnd":nnd},open("vectors_out.json","w"),indent=1,default=str)
