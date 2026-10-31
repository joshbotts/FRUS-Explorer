import sqlite3,sys,os
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for pair in sys.argv[1:]:
    v,d=pair.split('/')
    r=c.execute("SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print("MISSING",pair); continue
    with open(f"raw/{v}_{d}.txt","w") as f:
        f.write("HEADER: "+r[0]+"\nDATELINE: "+(r[1] or "")+"\nSOURCE: "+(r[2] or "")+"\nBODY:\n"+r[3])
    print(pair, r[4], flush=True)
