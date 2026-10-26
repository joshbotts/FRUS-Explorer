# usage: grab.py VOL REGEX [maxdocs]  -- scans core.tsv docs of VOL (or VOL/DOC) for REGEX (re.I), prints windows; saves whole texts to texts/
# SQL: SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?
import csv, sqlite3, re, sys
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
sel, rx = sys.argv[1], sys.argv[2]; mx = int(sys.argv[3]) if len(sys.argv) > 3 else 6
if '/' in sel: pairs = [tuple(sel.split('/'))]
else: pairs = [(r[0], r[1]) for r in csv.reader(open('/Users/jbotts/frus-analysis/c3/runs/r4/core.tsv'), delimiter='\t') if r[0] == sel]
n = 0
for v, d in pairs:
    h, dl, sn, b, L = con.execute("SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    t = re.sub(r'\s+', ' ', ' '.join(x or '' for x in (h, dl, sn, b)))
    m = re.search(rx, t, re.I)
    if not m: continue
    open('/Users/jbotts/frus-analysis/c3/runs/r4/texts/%s__%s.txt' % (v, d), 'w').write(t)
    print('### %s/%s len(body_text)=%d captured_body=%d | %s | %s' % (v, d, L, len(b), re.sub(r'\s+',' ',h)[:120], dl))
    print('   ...' + t[max(0, m.start()-350): m.end()+450] + '...')
    n += 1
    if n >= mx: break
