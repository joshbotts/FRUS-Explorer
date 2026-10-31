# SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? ; test raw substring and whitespace-collapsed substring
import sqlite3,re
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for line in open('quotes.tsv'):
    q,v,d,t=line.rstrip('\n').split('\t')
    b=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    raw=t in b; col=t in re.sub(r'\s+',' ',b)
    print(q,v,d,'RAW' if raw else 'raw-MISS','COLLAPSED' if col else 'collapsed-MISS', b.count(t))
