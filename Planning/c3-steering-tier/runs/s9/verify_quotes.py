import sqlite3, json, re
R="/Users/jbotts/frus-analysis/c3s/runs/s9"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
out=[]
for q,v,d,t in json.load(open(R+"/quotes.json")):
    b, L = con.execute("SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?", (v,d)).fetchone()
    raw_exact = t in b
    coll = t in re.sub(r"\s+"," ",b)
    out.append({"q":q,"v":v,"d":d,"exact_in_body_text":raw_exact,"in_whitespace_collapsed_body":coll,"len":L})
    print(q, v, d, "exact:", raw_exact, "collapsed:", coll)
json.dump(out, open(R+"/quote_verification.json","w"), indent=1)
