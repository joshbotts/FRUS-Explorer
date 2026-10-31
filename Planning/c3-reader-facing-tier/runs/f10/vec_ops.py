import sys,random,json,sqlite3
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3f/runs/f10")
from vec_common import *
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
present=set(r[0] for r in db.execute("select distinct volume_id from document_cache"))
_sh={}
def shard(v):
    if v not in _sh:
        b=open(SH+v+".vec","rb").read(); n=struct.unpack("<I",b[12:16])[0]
        codes=np.frombuffer(b,dtype=np.int8,count=n*512,offset=64).reshape(n,512)
        sc=np.frombuffer(b,dtype=np.float32,count=n,offset=64+n*512)
        _sh[v]=(codes,sc)
    return _sh[v]
def vec(row):
    v,i=doc_of[row]; r0,n=vol_rows[v]; codes,sc=shard(v)
    return codes[row-r0].astype(np.float32)*sc[row-r0]
def cosine(r1,r2):
    a=vec(r1); b=vec(r2); return float(a@b/(np.linalg.norm(a)*np.linalg.norm(b)))
def cal_doc(c): return (c-0.40)/0.60
def funnel(row,k=10,pool=800):
    h=hamming_all(row); h[row]=9999
    cand=np.argpartition(h,pool)[:pool]
    sc=[(cosine(row,int(c)),int(c)) for c in cand]
    sc.sort(reverse=True)
    return [(c,r,int(h[r])) for c,r in sc[:k]], np.sort(h)[:k]
def cite(row): v,i=doc_of[row]; return v+"/"+i
def hdr(row):
    v,i=doc_of[row]
    r=db.execute("select substr(header,1,80),is_front_matter,is_editorial_note from document_cache where volume_id=? and document_id=?",(v,i)).fetchone()
    return ("[NOT IN LOCAL INDEX] " if v not in present else "")+(r[0].replace("\n"," ") if r else "[no row]")
if __name__=="__main__":
    mode=sys.argv[1]
    if mode=="baseline":
        rng=random.Random(1877); N=docs
        d=[]
        for _ in range(20000):
            a=rng.randrange(N); b=rng.randrange(N)
            if a==b: continue
            d.append(int(np.bitwise_count(np.bitwise_xor(signs[a],signs[b])).sum()))
        d=np.array(d); print("random pairs n=%d mean %.1f sd %.1f p1 %.0f min %d"%(len(d),d.mean(),d.std(),np.percentile(d,1),d.min()))
        rng=random.Random(2026); rows=[rng.randrange(N) for _ in range(200)]
        k25=[];k1=[]
        for r in rows:
            h=hamming_all(r); h[r]=9999; s=np.sort(h)[:25]; k25.append(s[24]); k1.append(s[0])
        k25=np.array(k25); k1=np.array(k1)
        print("200-doc sample (random.Random(2026)): 25th NN median %.0f q1 %.0f q3 %.0f ; 1st NN median %.0f q1 %.0f q3 %.0f"%(np.median(k25),np.percentile(k25,25),np.percentile(k25,75),np.median(k1),np.percentile(k1,25),np.percentile(k1,75)))
        # also random-pair cosine mean for calibration reading
        cs=[]
        rng=random.Random(7)
        for _ in range(300):
            a=rng.randrange(N); b=rng.randrange(N)
            if a!=b: cs.append(cosine(a,b))
        print("random-pair int8 cosine (300 pairs): mean %.3f sd %.3f"%(np.mean(cs),np.std(cs)))
    elif mode=="nn":
        for a in sys.argv[2:]:
            v,i=a.split("/"); row=row_of[(v,i)]
            top,h10=funnel(row)
            print("\nANCHOR",a,"|",hdr(row))
            print(" hamming top10 (sign scan):",[int(x) for x in h10])
            for c,r,h in top:
                print("  cos_raw %.3f cal %.3f ham %3d  %s | %s"%(c,cal_doc(c),h,cite(r),hdr(r)))
