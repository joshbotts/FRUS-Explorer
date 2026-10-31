import json,sys
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3s/runs/s7")
from db import *
Q=json.load(open("quotes.json")); ok=0
for v,d,t in Q:
    r=q("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d),"verify")
    b=" ".join(r[0][0].split()) if r else ""
    hit=t in b; ok+=hit; print("OK " if hit else "MISS",v,d,t[:60])
print(ok,"of",len(Q),"verified in body_text (whitespace-collapsed, exact, case-sensitive)")
