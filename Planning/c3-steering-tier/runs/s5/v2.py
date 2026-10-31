from vecsetup import *
import sqlite3, json, sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
core=set(map(tuple,json.load(open("core_hits.json"))))
cache={}
def getshard(v):
    if v not in cache: cache[v]=shard(v)
    return cache[v]
def info(v,d):
    r=db.execute("""SELECT substr(c.header,1,70),c.is_front_matter,c.is_editorial_note,dd.date_iso FROM document_cache c
      LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?""",(v,d)).fetchone()
    return r
anchors=[a.split("/") for a in sys.argv[1:]]
for v,d in anchors:
    a=row_of[(v,d)]
    h=hamming_all(a).astype(np.int32); h[a]=10**6
    order=np.argsort(h,kind="stable")
    print(f"\n### ANCHOR {v}/{d}  (row {a}) in_core_vocab_hits={ (v,d) in core}")
    print("-- Hamming top 10 (sign bits, 512)")
    for r in order[:10]:
        nv,nd=doc_of[r]; i=info(nv,nd)
        print(f" ham={h[r]:3d} {nv}/{nd} date={i[3] if i else None} flags(fm,ed)={(i[1],i[2]) if i else None} corevocab={(nv,nd) in core} | {i[0] if i else 'NOT IN document_cache'}")
    # funnel: 800 pool -> int8 cosine
    pool=order[:800]
    dg,codes,scales=getshard(v); ar=a-vol_rows[v][0]
    avec=codes[ar].astype(np.float32)*scales[ar]
    res=[]
    for r in pool:
        nv,nd=doc_of[r]
        try: dg2,c2,s2=getshard(nv)
        except FileNotFoundError: continue
        assert dg2==ix["provenanceDigest"]
        k=r-vol_rows[nv][0]
        res.append((float(avec@(c2[k].astype(np.float32)*s2[k])),r))
    res.sort(reverse=True)
    print("-- funnel: Hamming-800 pool -> int8 cosine, top 10 [raw cosine -> calibrated (cos-0.40)/0.60]")
    for c,r in res[:10]:
        nv,nd=doc_of[r]; i=info(nv,nd)
        print(f" cos={c:.3f} cal={(c-0.40)/0.60:.2f} ham={h[r]:3d} {nv}/{nd} date={i[3] if i else None} flags={(i[1],i[2]) if i else None} corevocab={(nv,nd) in core} | {i[0] if i else 'NOT IN document_cache'}")
    # map
    off=64+a*6
    x,y,c=struct.unpack("<hhH",mp[off:off+6]); print(f"-- map placement: x={x} y={y} cluster={'unclustered' if c==0xFFFF else c}")
