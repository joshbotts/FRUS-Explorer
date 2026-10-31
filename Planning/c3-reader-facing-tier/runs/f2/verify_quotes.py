import sqlite3
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for l in open("quotes.tsv"):
    q,v,d,t=l.rstrip("\n").split("\t")
    b,L=c.execute("SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    print(q,v,d,"EXACT" if t in b else "MISSING", "offset", b.find(t), "len", L)
