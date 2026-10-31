import json, struct, sqlite3, re, time
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
RUN="/Users/jbotts/frus-analysis/c3s/runs/s5/"
ix=json.load(open(R+"semantic-vectors-index.json"))
print("index keys:", list(ix.keys()))
print("volume entry sample:", json.dumps(ix["volumes"][0])[:300])
print("documentCount:", ix.get("documentCount"), "provenanceDigest:", ix.get("provenanceDigest"))
# my own decode of the run-length id segments: s = row offset within the volume, i = first id, n = ids in the run; a run continues d<b+1>... for a plain numeric id
def numeric(d):
    m=re.fullmatch(r'd([1-9]\d*)', d)
    return int(m.group(1)) if m else None
def decode(segs):
    ids=[]
    for s in segs:
        assert s["s"]==len(ids), ("segment start mismatch", s, len(ids))
        ids.append(s["i"])
        if s["n"]>1:
            b=numeric(s["i"]); assert b is not None, ("run on non-numeric id", s)
            ids.extend(f"d{b+k}" for k in range(1,s["n"]))
    return ids
row_of={}; doc_of={}
for v in ix["volumes"]:
    ids=decode(v["seg"]); assert len(ids)==v["n"], (v["v"], len(ids), v["n"])
    for k,i in enumerate(ids):
        row_of[(v["v"],i)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],i)
print("decoded rows:", len(doc_of), "contiguous 0..N-1:", set(doc_of)==set(range(ix["documentCount"])))
# cross-check the decode against document_cache ids
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
cache={(v,d) for v,d in db.execute("SELECT volume_id, document_id FROM document_cache")}
missing=[k for k in row_of if k not in cache]
print("decoded ids absent from document_cache:", len(missing), missing[:10])
blob=open(R+"semantic-vectors-binary.bin","rb").read()
magic=blob[:4]; ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bdig=blob[20:52].hex()
mp=open(R+"semantic-map.bin","rb").read(); mdig=mp[20:52].hex(); mhdr=struct.unpack("<IIII",mp[4:20])
gen=open(SH+".generation").read().strip()
print("binary magic", magic, "ver", ver, "dims", dims, "docs", docs, "centroids", cents)
print("DIGESTS equal (index, binary, map, .generation):", ix["provenanceDigest"]==bdig==mdig==gen, "|", ix["provenanceDigest"][:16], bdig[:16], mdig[:16], gen[:16])
bpr=dims//8
try:
    import numpy as np
    signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
    def hamming_all(row):
        return np.bitwise_count(np.bitwise_xor(signs,signs[row])).sum(axis=1).astype(int)
    HAVE_NP=True
except Exception as e:
    print("numpy unavailable:", e); HAVE_NP=False
    rows_int=[int.from_bytes(blob[64+r*bpr:64+(r+1)*bpr],'little') for r in range(docs)]
    def hamming_all(row):
        a=rows_int[row]; return [(a^b).bit_count() for b in rows_int]
# parse the session's lists
sess=open(RUN+"vec_v2.txt").read()
sess_lists={}
for block in sess.split("### ANCHOR ")[1:]:
    anchor=block.split()[0]
    ham=re.findall(r'^ ham=\s*(\d+) (\S+) ', block, re.M)
    sess_lists[anchor]=[(int(h),p) for h,p in ham]
anchors=["frus1964-68v05/d258","frus1922v01/d841","frus1969-76ve09p2/d155"]
for a in anchors:
    v,d=a.split("/"); r=row_of[(v,d)]
    t=time.time(); h=hamming_all(r)
    if HAVE_NP:
        h[r]=10**6; order=np.argsort(h,kind="stable")[:10]
        mine=[(int(h[i]),"%s/%s"%doc_of[int(i)]) for i in order]
    else:
        h[r]=10**6; order=sorted(range(docs), key=lambda i:(h[i],i))[:10]
        mine=[(h[i],"%s/%s"%doc_of[i]) for i in order]
    print(f"\nANCHOR {a} row {r} ({time.time()-t:.1f}s)")
    print(" mine   :", mine)
    print(" session:", sess_lists.get(a))
    print(" REPRODUCES (same pairs, same order, same distances):", mine==sess_lists.get(a))
    # map placement
    off=64+r*6; x,y,c=struct.unpack("<hhH",mp[off:off+6]); print(" map: x=%d y=%d cluster=%s"%(x,y,'unclustered' if c==0xFFFF else c))
# near-duplicate claim: frus1950v03/d728 vs frus1950v07/d977 at Hamming 13
r1=row_of[("frus1950v03","d728")]; r2=row_of[("frus1950v07","d977")]
h=hamming_all(r1); print("\nnear-duplicate: d728 vs frus1950v07/d977 Hamming =", int(h[r2]), "| nearest other to d728:", sorted([(int(h[i]),"%s/%s"%doc_of[int(i)]) for i in (np.argsort(h,kind='stable')[:3] if HAVE_NP else sorted(range(docs),key=lambda i:h[i])[:3])]))
# d836 vs d841 hamming
print("d841 vs d836 Hamming:", int(hamming_all(row_of[("frus1922v01","d841")])[row_of[("frus1922v01","d836")]]))
print("retrieval block:", json.dumps(ix.get("retrieval"))[:400])
