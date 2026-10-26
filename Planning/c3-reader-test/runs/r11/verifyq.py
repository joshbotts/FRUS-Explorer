# Verify each quotation is an exact substring of header+dateline+source_note+body_text (whitespace-collapsed) of its document; case-sensitive.
import json,re
from db import q
out=[]
for qid,v,d,txt in json.load(open("quotes.json")):
    r=q("SELECT header, coalesce(dateline,''), coalesce(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d),tag="verify-quotes")
    t=re.sub(r"\s+"," "," ".join(r[0])); b=re.sub(r"\s+"," ",r[0][3])
    ok=txt in t; inbody=txt in b
    out.append((qid,v,d,ok,inbody,len(txt)))
    print(qid,v,d,"VERIFIED" if ok else "NOT FOUND","in body_text" if inbody else "", len(txt))
