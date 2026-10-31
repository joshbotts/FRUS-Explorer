import sqlite3,sys,os
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
SQL="SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0"
for line in open(sys.argv[1]):
    line=line.strip()
    if not line: continue
    v,d=line.split('/')
    r=c.execute(SQL,(v,d)).fetchone()
    if not r: print("MISSING",line); continue
    fn=f"raw/{v}__{d}.txt"
    with open(fn,'w') as f:
        f.write(f"HEADER: {r[0]}\nDATELINE: {r[1]}\nSOURCE: {r[2]}\nBODYLEN: {r[4]}\n---\n{r[3]}")
    print(line, r[4])
