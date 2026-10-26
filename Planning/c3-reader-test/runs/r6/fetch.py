# usage: python3 fetch.py vol/doc vol/doc ...  -- reads whole documents and saves them to raw/docs/
# SQL: SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?
import sqlite3, sys
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
for a in sys.argv[1:]:
    v,d=a.split("/")
    r=con.execute("SELECT header, dateline, source_note, body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print("MISSING",a); continue
    t="HEADER: %s\nDATELINE: %s\nSOURCE: %s\nBODY:\n%s"%(r[0],r[1],r[2],r[3])
    open("raw/docs/%s_%s.txt"%(v,d),"w").write(t)
    with open("raw/read_ledger.tsv","a") as L: L.write("%s\t%s\t%d\t%d\t%d\n"%(v,d,r[4],len(r[3]),r[5]+r[6]))
    print(a, "chars", r[4], "captured", len(r[3]), "FM/EN", r[5], r[6])
