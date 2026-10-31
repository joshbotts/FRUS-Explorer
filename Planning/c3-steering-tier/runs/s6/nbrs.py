import sys; sys.path.insert(0,".")
import vec, sqlite3, re, numpy as np, struct
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
FAM=re.compile(r"\b(corrupt\w*|brib\w*|kickback\w*|embezzl\w*|malfeasance|peculat\w*|graft|venal\w*|nepotism|cronyism)\b",re.I)
_sh={}
def shard(v):
    if v not in _sh:
        b=open(vec.SV+"/%s.vec"%v,"rb").read()
        n=struct.unpack("<I",b[12:16])[0]
        codes=np.frombuffer(b,dtype=np.int8,count=n*512,offset=64).reshape(n,512).astype(np.float32)
        sc=np.frombuffer(b,dtype=np.float32,count=n,offset=64+n*512)
        _sh[v]=(codes,sc)
    return _sh[v]
def vecof(key):
    v,d=key; r=vec.row_of[key]-vec.vol_rows[v][0]
    c,s=shard(v); return c[r]*s[r]
def cos(a,b):
    x,y=vecof(a),vecof(b); return float(x@y/(np.linalg.norm(x)*np.linalg.norm(y)))
def info(key):
    v,d=key
    r=con.execute("SELECT header,is_front_matter,is_editorial_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",key).fetchone()
    if r is None: return None
    n=len(FAM.findall(r[3]))
    return r[0][:70],r[1],r[2],n
for arg in sys.argv[1:]:
    v,d=arg.split("/"); a=(v,d)
    print("##ANCHOR",arg,info(a))
    for dist,key in vec.neighbours(vec.row_of[a],10):
        i=info(key)
        c=cos(a,key); cal=(c-0.40)/0.60
        print("  ham %3d  %s/%s  raw_cos %.3f calibrated %.0f%%  %s"%(dist,key[0],key[1],c,100*cal, "NOT IN document_cache (cite by URL)" if i is None else "famhits=%d apparatus=%d/%d | %s"%(i[3],i[1],i[2],i[0])))
