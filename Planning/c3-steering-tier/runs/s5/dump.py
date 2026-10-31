import sqlite3, sys, re, os, json
# usage: dump.py vol/doc [vol/doc ...]  -> docs/<vol>__<doc>.txt (full body_text); appends to docs/_retrieved.jsonl {vol,doc,len,captured}
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
for a in sys.argv[1:]:
    v,d = a.split("/")
    r = db.execute("SELECT header,dateline,body_text,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print("MISSING",a); continue
    p=f"docs/{v}__{d}.txt"
    open(p,"w",encoding="utf-8").write(r[2])
    cap=len(open(p,encoding="utf-8").read())
    open("docs/_retrieved.jsonl","a").write(json.dumps({"v":v,"d":d,"len_sql":r[3],"len_captured":cap,"header":r[0][:120]})+"\n")
    print(a, "len", r[3], "captured", cap, "|", r[0][:100], "|", r[1])
