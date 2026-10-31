import sqlite3,json,re
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
SQL="SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0"
print("SQL:",SQL)
bad=0
for v,d,q in json.load(open('quotes.json')):
    r=c.execute(SQL,(v,d)).fetchone()
    raw=r[0]; col=re.sub(r'\s+',' ',raw)
    exact=q in raw; collapsed=q in col
    print(f"{v}/{d} len={r[1]} exact_in_body={exact} in_collapsed={collapsed} :: {q[:60]}")
    bad+= not collapsed
print("FAILED:",bad)
