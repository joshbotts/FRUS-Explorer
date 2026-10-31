import re, json, sys
sys.path.insert(0,".")
from quotes import Q
man=json.load(open("docs/manifest.json"))
out=[]; bad=0
for qid,v,d,txt in Q:
    body=re.sub(r"\s+"," ",open("docs/%s__%s.txt"%(v,d)).read())
    n=body.count(txt); ok=n>=1
    bad+= 0 if ok else 1
    out.append((qid,v,d,ok,n))
    print(qid,v+"/"+d,"VERIFIED" if ok else "NOT FOUND",n)
print("verified",len(Q)-bad,"of",len(Q))
json.dump([dict(id=a,vol=b,doc=c,ok=e,occurrences=n,text=[t for (i,_,_,t) in Q if i==a][0]) for a,b,c,e,n in out],open("quotes_verified.json","w"),indent=1,ensure_ascii=False)
