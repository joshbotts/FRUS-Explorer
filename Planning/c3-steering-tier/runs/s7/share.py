import sys,re,json
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3s/runs/s7")
from db import *
match,strict,tol,name=sys.argv[1:5]
H=hits(match,"share:"+name)
n=len(H); k=min(40,n)
samp=H if n<300 and len(sys.argv)>5 and sys.argv[5]=="census" else [H[int(i*n/k)] for i in range(k)]
rs=re.compile(strict,re.I); rt=re.compile(tol,re.I)
s=t=0; miss=[]
for v,d in samp:
    x=text(v,d,"share-text:"+name)
    a=bool(rs.search(x)); b=bool(rt.search(x)); s+=a; t+=b
    if not b: miss.append((v,d))
out=dict(name=name,match=match,hits=n,sample=len(samp),strict=s,tolerant=t,strict_re=strict,tol_re=tol,misses=miss)
print(json.dumps(out))
open("/Users/jbotts/frus-analysis/c3s/runs/s7/shares.jsonl","a").write(json.dumps(out)+"\n")
