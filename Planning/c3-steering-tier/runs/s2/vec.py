# vectors: digests, identity round trip, baselines, flagged neighbours for anchors, near-duplicates
import json, random, re, sqlite3, statistics, struct, os
import numpy as np
RES="/Applications/FRUS Explorer.app/Contents/Resources"; DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors"
idx=json.load(open(RES+"/semantic-vectors-index.json"))
print("index keys:", list(idx.keys())); print("generated:", idx.get("generated"))
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
print("round trip: decoded length == n for all %d volumes; %d rows" % (nvol, len(doc_of)))
blob=open(RES+"/semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); print("binary magic", blob[:4], "version", ver, "dims", dims, "docs", docs, "centroids", cents)
man=json.load(open(RES+"/semantic-shards-manifest.json"))
digests={"index":idx["provenanceDigest"],"binary":blob[20:52].hex(),"map":open(RES+"/semantic-map.bin","rb").read(52)[20:52].hex(),
         "manifest":man["provenanceDigest"],"generation_file":open(SH+"/.generation").read().strip()}
# one shard header too
sh=open(SH+"/frus1947v07.vec","rb").read(48); digests["shard frus1947v07"]=sh[16:48].hex()
for k,v in digests.items(): print("digest", k, v)
gen=digests["generation_file"]
assert len({digests[k] for k in digests if k!="generation_file"})==1, digests
print("generation file agrees:", gen==digests["index"] or gen.startswith(digests["index"][:8]) or digests["index"] in gen)
print("calibration:", json.dumps(idx.get("retrieval",{}).get("scoreCalibration"))[:300])
print("retrieval keys:", list(idx.get("retrieval",{}).keys()))
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
print("random pairs (20000, seed 1877): mean %.1f sd %.1f 1st pct %d" % (mean,sd,first))
print("25th-neighbour distance over 200 random docs (seed 1878): min %d p10 %d median %d p90 %d" % (kth[0],kth[20],kth[100],kth[180]))
line=mean-8*sd; print("near-duplicate line mean-8sd = %.1f" % line)
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
J=("SELECT c.header, c.body_text, t.date_iso, c.is_front_matter, c.is_editorial_note FROM document_cache c LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?")
print("JOIN SQL:", J)
def joined(key): return con.execute(J,key).fetchone()
scope={tuple(x) for x in json.load(open("family_hits.json"))}
literal=re.compile(r"\b(corrupt\w*|brib\w*|graft(s|ing|er|ers|ed)?|kick[\s\-]?backs?|embezzl\w*)\b",re.I)
anchors=["frus1947v07/d908","frus1958-60v01/d131","frus1961-63v22/d202","frus1955-57v13/d16","frus1969-76ve09p2/d161","frus1977-80v03/d248"]
out={}
for a in anchors:
    ak=tuple(a.split("/")); ad=(joined(ak)[2] or "")
    print("=== ANCHOR", a, ad)
    rows=[]
    for h,key in nearest(ak,25):
        r=joined(key)
        if r is None: rows.append([h,"/".join(key),"NOT IN THIS DATABASE"]); print("  ",h,"/".join(key),"NOT IN THIS DATABASE"); continue
        header,body,date,fm,en=r
        f=[h,"/".join(key),date,"IN-SCOPE" if key in scope else "OUTSIDE","SAME-DECADE" if date and date[:3]==ad[:3] else "OTHER-DECADE","LITERAL" if literal.search(header+" "+body) else "ABSENT", "APPARATUS" if (fm or en) else "", header[:90]]
        rows.append(f); print("  ", *f)
    out[a]=rows
json.dump(out,open("vec_neighbours.json","w"),indent=1)
# near-duplicates: over the cited set and over the family scope
def near_duplicates(sc):
    rs=sorted(row_of[k] for k in sc if k in row_of); found=[]
    for i,a in enumerate(rs[:-1]):
        d=np.bitwise_count(bits[rs[i+1:]]^bits[a]).sum(axis=1)
        found+=[(int(h),"/".join(doc_of[a]),"/".join(doc_of[b])) for h,b in zip(d,rs[i+1:]) if h<line]
    return sorted(found)
cited={tuple(l.strip().split("/")) for l in open("cited.txt") if l.strip()}
print("cited set: %d pairs, %d with a vector row" % (len(cited), sum(1 for k in cited if k in row_of)))
nd=near_duplicates(cited); print("near-duplicate pairs in cited set:", nd)
# each cited member's nearest-neighbour distance in the cited set
cr=sorted(row_of[k] for k in cited)
for r in cr:
    d=np.bitwise_count(bits[cr]^bits[r]).sum(axis=1); d=[int(x) for x,rr in zip(d,cr) if rr!=r]
    print("  NN-in-set", "/".join(doc_of[r]), min(d))
fam=[k for k in scope if k in row_of]; print("family scope: %d pairs, %d with a vector row" % (len(scope), len(fam)))
ndf=near_duplicates(set(fam)); print("near-duplicate pairs in family scope: %d" % len(ndf))
for x in ndf: print("  ", x)
json.dump({"mean":mean,"sd":sd,"first":first,"kth":kth,"line":line,"nd_cited":nd,"nd_family":ndf},open("vec_baselines.json","w"))
