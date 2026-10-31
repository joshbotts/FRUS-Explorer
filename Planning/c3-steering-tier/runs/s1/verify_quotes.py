import sqlite3, re, json
from quotes import Q
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
SQL="SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0"
res=[]
for qid,v,d,t in Q:
    body,L=con.execute(SQL,(v,d)).fetchone()
    raw=t in body; col=re.sub(r"\s+"," ",t) in re.sub(r"\s+"," ",body)
    res.append((qid,v,d,L,raw,col))
    print(qid,f"{v}/{d}","len",L,"exact-in-raw:",raw,"in-whitespace-collapsed:",col)
json.dump(res,open("quotes_verified.json","w"))
