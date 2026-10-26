# usage: coregrep.py REGEX [max]  -- every core.tsv doc whose collapsed header+dateline+source_note+body_text matches REGEX (re.I); prints pair, date, short window
# SQL: SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?
import csv, sqlite3, re, sys
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rx = re.compile(sys.argv[1], re.I); mx = int(sys.argv[2]) if len(sys.argv) > 2 else 40
n = 0; tot = 0
for r in csv.reader(open('/Users/jbotts/frus-analysis/c3/runs/r4/core.tsv'), delimiter='\t'):
    t = re.sub(r'\s+', ' ', ' '.join(x or '' for x in con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (r[0], r[1])).fetchone()))
    m = rx.search(t)
    if m:
        tot += 1
        if n < mx: print('%s/%s %s | %s' % (r[0], r[1], r[4][:10], t[max(0, m.start()-120): m.end()+160])); n += 1
print('TOTAL matches', tot, 'of', 1105)
