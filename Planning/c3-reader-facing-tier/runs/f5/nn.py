# nn.py: nearest neighbours of anchor documents: Hamming over sign bits (Tier 1), top-800 funnel reranked by int8 cosine (Tier 2)
import sys; sys.path.insert(0,'/Users/jbotts/frus-analysis/c3f/runs/f5')
import vec, numpy as np
from h import *
c=conn()
_sh={}
def shard_rows(v):
    if v not in _sh:
        dg,codes,sc=vec.shard(v); _sh[v]=(codes,sc)
    return _sh[v]
def vecof(row):
    v,d=vec.doc_of[row]; r0,n=vec.vol_rows[v]
    codes,sc=shard_rows(v)
    return codes[row-r0].astype(np.float32)*sc[row-r0]
def info(row):
    v,d=vec.doc_of[row]
    r=c.execute("SELECT substr(replace(header,char(10),' '),1,85),substr(dateline,1,30),is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",[v,d]).fetchone()
    return v,d,r
def nn(anchor,k=10,pool=800):
    row=vec.row_of[anchor]
    h=vec.hamming_all(row); h[row]=9999
    cand=np.argsort(h)[:pool]
    a=vecof(row)
    cs=[]
    for r in cand:
        cs.append(float(np.dot(a,vecof(int(r)))))
    cs=np.array(cs)
    order=np.argsort(-cs)[:k]
    out=[]
    for i in order:
        r=int(cand[i]); out.append((r,int(h[r]),float(cs[i]),(cs[i]-0.40)/0.60))
    return out
if __name__=="__main__":
    for a in sys.argv[1:]:
        v,d=a.split('/')
        print("ANCHOR",a, info(vec.row_of[(v,d)])[2][:2])
        for r,hm,cs,cal in nn((v,d)):
            vv,dd,inf=info(r)
            flag="" if inf else " [NOT IN document_cache]"
            print(f"  ham {hm:3d} cos_raw {cs:.3f} cal {cal:.3f} {vv}/{dd} | {inf[0] if inf else ''} | {inf[1] if inf else ''}{flag}")
