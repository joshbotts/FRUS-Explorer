# SQL: SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?
import sqlite3,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f12"
out=open(R+"/out/reading_lengths.tsv","a")
for line in open(sys.argv[1]):
    v,d=line.split()
    r=c.execute("SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print("MISSING",v,d); continue
    txt="\n".join([r[0] or "", r[1] or "", r[2] or "", r[3]])
    open(f"{R}/raw/{v}__{d}.txt","w").write(txt)
    ok = len(r[3])==r[4]
    out.write(f"{v}\t{d}\t{r[4]}\t{len(r[3])}\t{'whole' if ok else 'PARTIAL'}\n")
    print(v,d,r[4],'whole' if ok else 'PARTIAL')
