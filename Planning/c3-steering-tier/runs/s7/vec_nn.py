import json,struct,numpy as np,pickle,sys,sqlite3
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3s/runs/s7")
from db import q
R="/Applications/FRUS Explorer.app/Contents/Resources/"; SH="/Users/jbotts/frus-analysis/c3/SemanticVectors/"
DIG="89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101"
ix=json.load(open(R+"semantic-vectors-index.json")); vr={ (v.get("v") or v.get("id") or v.get("volumeId")):v for v in ix["volumes"]}
print("sample vol keys", list(ix["volumes"][0].keys()))
S=np.load("signs.npy"); row_of,doc_of=pickle.load(open("idmap.pkl","rb"))
cache={}
def shard(vid):
    if vid in cache: return cache[vid]
    try: b=open(SH+vid+".vec","rb").read()
    except FileNotFoundError: cache[vid]=None; return None
    assert b[:4]==b"FRSS"; dims,n=struct.unpack("<II",b[8:16]); dg=b[16:48].hex()
    if dg!=DIG: raise SystemExit("DIGEST MISMATCH "+vid)
    codes=np.frombuffer(b,np.int8,n*dims,64).reshape(n,dims).astype(np.int32); sc=np.frombuffer(b,np.float32,n,64+n*dims)
    cache[vid]=(codes,sc); return cache[vid]
def vec(row):
    vid,d=doc_of[row]; s=shard(vid)
    if s is None: return None
    k=row-vr[vid]["r"]; return s[0][k],s[1][k]
present=set(r[0] for r in q("SELECT DISTINCT volume_id FROM document_cache",(),"vec-present"))
def fts_hit(v,d):
    return bool(q("SELECT 1 FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt* OR briberi OR bribe* OR graft OR embezzl*' AND c.volume_id=? AND c.document_id=?",(v,d),"vec-join"))
for a in sys.argv[1:]:
    v,d=a.split("/"); r=row_of[(v,d)]
    dd=np.bitwise_count(S^S[r]).sum(1); dd[r]=9999
    pool=np.argsort(dd,kind="stable")[:800]
    qa=vec(r); res=[]
    for c in pool:
        x=vec(int(c))
        cos=None if (qa is None or x is None) else float(qa[1]*x[1]*np.dot(qa[0],x[0]))
        res.append((cos if cos is not None else -9, int(dd[c]), int(c)))
    res.sort(key=lambda t:(-t[0],t[1]))
    print("== anchor",a,"nearest hamming overall:",int(dd.min()))
    for cos,h,c in res[:10]:
        vv,did=doc_of[c]; hd=q("SELECT substr(replace(header,char(10),' '),1,90) FROM document_cache WHERE volume_id=? AND document_id=?",(vv,did),"vec-hdr")
        print("  ham %3d cos_raw %.3f cal %.3f %s/%s inDB=%s ftsCorruption=%s | %s"%(h,cos,(cos-0.4)/0.6,vv,did,vv in present,fts_hit(vv,did),hd[0][0] if hd else "-"))
