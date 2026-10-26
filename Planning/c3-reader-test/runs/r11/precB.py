# Precision sample: 40 evenly spaced Part B docs (sorted by volume_id, document_id); print header and first recogni* context (240 chars) for hand judgment
import re
from db import q
B=sorted(tuple(l.split()) for l in open("scopeB.tsv"))
S=[B[int(i*len(B)/40)] for i in range(40)]
for v,d in S:
    h,b=q("SELECT header, body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d),tag="precB")[0]
    m=re.search(r'recogni',b,re.I); c=b[max(0,m.start()-140):m.end()+100] if m else ''
    print("%s/%s | %s | %s"%(v,d,h[:70].replace("\n"," "),re.sub(r'\s+',' ',c)))
