import json, sqlite3, re
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
ok=0; Q=json.load(open("quotes.json"))
for v,d,q in Q:
    b=con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    raw=open("raw/%s__%s.txt"%(v,d)).read()
    hit_db=q in re.sub(r"\s+"," ",b); hit_raw=q in re.sub(r"\s+"," ",raw)
    ok+=hit_db and hit_raw; print(v,d,"DB" if hit_db else "--","RAW" if hit_raw else "--",q[:60])
print("verified",ok,"of",len(Q))
