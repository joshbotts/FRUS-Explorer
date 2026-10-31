import sqlite3, json
from quotes_ov import OV
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
out=[]; bad=0
for a,qs in OV.items():
    v,d=a.split("/")
    t=" ".join(db.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone()[0].split())
    for q in qs:
        ok=" ".join(q.split()) in t; bad+= (not ok)
        if not ok: print("MISS",a,q)
        out.append({"pair":a,"quote":q,"verified":ok,"select":f"SELECT body_text FROM document_cache WHERE volume_id='{v}' AND document_id='{d}' AND is_front_matter=0 AND is_editorial_note=0;"})
json.dump(out,open("ov_quotes_verified.json","w"),indent=1,ensure_ascii=False)
print("overview/excerpt quotations:",len(out),"verified:",len(out)-bad)
