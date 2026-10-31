import sys,re
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3s/runs/s7")
from db import *
match,rx,name=sys.argv[1:4]; k=int(sys.argv[4]) if len(sys.argv)>4 else 40
H=hits(match,"ctx:"+name); n=len(H); samp=[H[int(i*n/k)] for i in range(k)]
r=re.compile(rx,re.I)
for v,d in samp:
    x=text(v,d,"ctx-text:"+name); m=r.search(x)
    print(v,d,"|",x[max(0,m.start()-90):m.end()+60] if m else "NOMATCH")
