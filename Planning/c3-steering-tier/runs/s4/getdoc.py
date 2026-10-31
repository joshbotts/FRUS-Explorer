import sqlite3,sys,re,os
# usage: python3 getdoc.py vol/doc [more...] -> writes work/docs/<vol>__<doc>.txt (header, dateline, body) and prints length; prints text if env SHOW
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
os.makedirs("work/docs",exist_ok=True)
for a in sys.argv[1:]:
    v,d=a.split("/")
    r=con.execute("SELECT header,dateline,body_text,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print(a,"MISSING"); continue
    txt=r[2]
    open(f"work/docs/{v}__{d}.txt","w").write(txt)
    ok = len(txt)==r[3]
    print(f"== {a} | {r[0][:110]} | {r[1]} | len={r[3]} captured={len(txt)} whole={ok}")
    if os.environ.get("SHOW"):
        lim=int(os.environ.get("LIM","3500"))
        print(re.sub(r"\s+"," ",txt)[:lim]); print()
