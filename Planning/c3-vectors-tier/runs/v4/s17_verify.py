# Verify each quote: SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? ; test raw substring, and whitespace-collapsed substring.
import sqlite3
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for l in open('quotes.tsv'):
    v,d,q=l.rstrip('\n').split('\t')
    r=c.execute("SELECT body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    b=r[0]; raw=q in b; col=q in ' '.join(b.split())
    print("%s/%s raw=%s collapsed=%s fm/en=%s/%s | %s"%(v,d,raw,col,r[1],r[2],q[:60]))
