import sqlite3, sys, json, re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
keys=[a.split("/") for a in sys.argv[1:]]
man=json.load(open("docs/manifest.json")) if __import__("os").path.exists("docs/manifest.json") else {}
for v,d in keys:
    r=con.execute("SELECT header,dateline,source_note,body_text,length(body_text),is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    assert r, (v,d)
    fn="docs/%s__%s.txt"%(v,d)
    open(fn,"w").write(r[3])
    cap=len(open(fn).read())
    man["%s/%s"%(v,d)]={"header":r[0],"dateline":r[1],"sql_len":r[4],"captured_len":cap,"whole":cap==r[4],"apparatus":[r[5],r[6]]}
    print(v,d,r[4],cap,cap==r[4])
json.dump(man,open("docs/manifest.json","w"),indent=1)
