# scan2.py: narrow vocabularies over scope.csv documents. SEC2 = security/defence words only; PRO2 = sugar/trade/investment words only.
import csv,re,collections
from h import *
SEC2=re.compile(r"\b(secur\w*|strategic\w*|defen[cs]\w*|menace\w*|Soviet\w*|missile\w*|naval|Monroe|European power\w*)\b",re.I)
PRO2=re.compile(r"\b(sugar\w*|commerc\w*|trade|tariff\w*|reciproc\w*|export\w*|import\w*|investment\w*|market\w*|prosper\w*|quota\w*|tobacco)\b",re.I)
CUB=re.compile(r"\bCub(?:a|an|ans)\b")
c=con()
rows=list(csv.DictReader(open("scope.csv")))
def band(d):
    y=int(d[:4]); return "1870-1899" if y<1900 else "1900-1939" if y<1940 else "1940-1957" if y<1958 else "1958-1989"
B=collections.defaultdict(lambda:[0,0,0,0])
for r in rows:
    b=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(r["volume_id"],r["document_id"])).fetchone()[0]
    s=p=False
    for m in CUB.finditer(b):
        w=b[max(0,m.start()-250):m.start()+250]
        s=s or bool(SEC2.search(w)); p=p or bool(PRO2.search(w))
    x=B[band(r["date"])]; x[0]+=1; x[1]+=s; x[2]+=p; x[3]+=(s and p)
print("band | M | narrow-security window | narrow-prosperity window | docs with both (anywhere)")
for k in ["1870-1899","1900-1939","1940-1957","1958-1989"]:
    x=B[k]; print("%s | %d | %d of %d (%.3f) | %d of %d (%.3f) | %d of %d (%.3f)"%(k,x[0],x[1],x[0],x[1]/x[0],x[2],x[0],x[2]/x[0],x[3],x[0],x[3]/x[0]))
