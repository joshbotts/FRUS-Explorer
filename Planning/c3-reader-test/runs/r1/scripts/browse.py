# usage: browse.py 'FTS EXPR' 'SNIPPET REGEX' [--vol LIKE] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--max N] [--width W] [--latam 0|1] [--path REGEX] [--order date|bm25]
# Lists scope documents (numbered, non-apparatus, no Ed2) matching the FTS expression, with date, header and a snippet around the first regex match.
import sys, re, argparse
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
ap = argparse.ArgumentParser()
ap.add_argument("expr"); ap.add_argument("rx")
ap.add_argument("--vol", default=None); ap.add_argument("--from", dest="dfrom", default=None); ap.add_argument("--to", dest="dto", default=None)
ap.add_argument("--max", type=int, default=40); ap.add_argument("--width", type=int, default=260); ap.add_argument("--latam", type=int, default=1)
ap.add_argument("--path", default=None); ap.add_argument("--newonly", default=None); ap.add_argument("--order", default="date"); ap.add_argument("--skip", type=int, default=0)
a = ap.parse_args()
conn = frus.connect()
conn.execute("ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
frus.log_line("# browse.py: next statement run after ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
q = ("SELECT f.volume_id, f.document_id, sd.date_iso, c.header, c.dateline, c.source_note, c.body_text, sd.section_path FROM frus_documents f "
     "JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id "
     "JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id "
     "WHERE frus_documents MATCH ? AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0")
params = [a.expr]
if a.latam: q += " AND sd.latam=1"
if a.vol: q += " AND f.volume_id LIKE ?"; params.append(a.vol)
if a.dfrom: q += " AND sd.date_iso >= ?"; params.append(a.dfrom)
if a.dto: q += " AND sd.date_iso <= ?"; params.append(a.dto)
q += " ORDER BY sd.date_iso, f.volume_id, f.document_id" if a.order == "date" else " ORDER BY bm25(frus_documents), f.volume_id, f.document_id"
# the log line shows the statement without the body_text/header columns' use in Python (all columns are read-only SELECTs)
rows = frus.sql(conn, q, tuple(params), script="scripts/browse.py")
rx = re.compile(a.rx, re.I)
pr = re.compile(a.path, re.I) if a.path else None
old = re.compile(a.newonly, re.I) if a.newonly else None
n = 0; shown = 0
for v, d, di, h, dl, sn, bt, sp in rows:
    if pr and not pr.search(sp or ""):
        continue
    txt = frus.collapse(" ".join([h or "", dl or "", sn or "", bt or ""]))
    m = rx.search(txt)
    if not m:
        continue
    if old and old.search(txt):
        continue
    n += 1
    if n <= a.skip: continue
    if shown >= a.max: continue
    shown += 1
    s0 = max(0, m.start() - a.width // 2); s1 = min(len(txt), m.end() + a.width // 2)
    print("%s/%s | %s | %s | ...%s..." % (v, d, di, frus.collapse(h)[:60], txt[s0:s1]))
print("-- %d rows from SQL; %d matched the snippet regex (after path filter); showed %d" % (len(rows), n, shown))
