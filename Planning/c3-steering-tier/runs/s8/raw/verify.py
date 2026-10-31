# Verify each quotation is an exact substring of the document's body_text (no whitespace folding), and where it sits
import sqlite3, json
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL="SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0"
print("SQL:",SQL)
for q,v,d,t in json.load(open("raw/quotes.json")):
    b,L=con.execute(SQL,(v,d)).fetchone()
    n=b.count(t); pos=b.find(t)
    print(f"{q} {v}/{d} exact_count={n} offset={pos} of len={L} {'OK' if n>=1 else 'FAIL'}")
