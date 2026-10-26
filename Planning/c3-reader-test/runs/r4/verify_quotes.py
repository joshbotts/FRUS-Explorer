# Verifies each quote in quotes.json is a substring of the document's body_text with runs of whitespace collapsed to one space (and, separately, of the raw body_text).
# SQL: SELECT body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?
import json, sqlite3, re
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
ok = 0; Q = json.load(open('/Users/jbotts/frus-analysis/c3/runs/r4/quotes.json'))
for v, d, q in Q:
    r = con.execute("SELECT body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    b = re.sub(r'\s+', ' ', r[0]); raw = q in r[0]; col = q in b
    ok += col
    print('%s/%s len=%d fm=%d en=%d collapsed_match=%s raw_match=%s' % (v, d, r[1], r[2], r[3], col, raw))
print('VERIFIED', ok, 'of', len(Q))
