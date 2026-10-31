import sqlite3, json
from quotes import Q
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
out=[]; bad=0; n=0
for a,qs in Q.items():
    v,d=a.split("/")
    body=db.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone()[0]
    t=" ".join(body.split())
    for q in qs:
        n+=1; ok = " ".join(q.split()) in t
        if not ok: bad+=1; print("MISS",a,q[:80])
        out.append({"pair":a,"quote":q,"verified":ok,"select":f"SELECT body_text FROM document_cache WHERE volume_id='{v}' AND document_id='{d}' AND is_front_matter=0 AND is_editorial_note=0;"})
json.dump(out,open("quotes_verified.json","w"),indent=1,ensure_ascii=False)
print("quotes",n,"verified",n-bad)
