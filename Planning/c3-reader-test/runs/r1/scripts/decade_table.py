# usage: decade_table.py NAME 'FTS MATCH EXPRESSION' [latam=1]
# Prints, for documents (numbered, non-apparatus, no Ed2 duplicates, dated) that match the FTS expression inside the scope (latam=1) or the whole index (latam=0):
#   per decade: hits, dated scope documents in the decade (denominator), hits per 1,000, number of volumes, top volume and its share of the hits.
import sys, re
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
name, expr = sys.argv[1], sys.argv[2]
latam = int(sys.argv[3]) if len(sys.argv) > 3 else 1
conn = frus.connect()
conn.execute("ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
frus.log_line("# decade_table.py %s -- the two statements below were run after ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % (name, frus.RUN))
flt = "sd.latam=1 AND " if latam else ""
num = ("SELECT sd.decade, sd.volume_id, COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id "
       "WHERE frus_documents MATCH ? AND %ssd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 AND sd.date_iso IS NOT NULL GROUP BY sd.decade, sd.volume_id" % flt)
den = ("SELECT sd.decade, COUNT(*) FROM s.scope_docs sd WHERE %ssd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 AND sd.date_iso IS NOT NULL GROUP BY sd.decade" % flt)
rows = frus.sql(conn, num, (expr,), script="scripts/decade_table.py " + name)
dens = dict(frus.sql(conn, den, (), script="scripts/decade_table.py " + name))
by = {}
for dec, vol, n in rows:
    by.setdefault(dec, []).append((n, vol))
print("## %s  | MATCH %s | scope=%s" % (name, expr, "latam" if latam else "whole index"))
print("decade | hits | dated docs in decade | per 1,000 | volumes | top volume (share of hits)")
tot = 0
for dec in sorted(by):
    lst = sorted(by[dec], key=lambda x: (-x[0], x[1]))
    hits = sum(n for n, _ in lst)
    tot += hits
    d = dens.get(dec, 0)
    print("%ds | %d | %d | %.1f | %d | %s (%.2f)" % (dec, hits, d, 1000.0 * hits / d if d else 0, len(lst), lst[0][1], lst[0][0] / hits))
print("total hits (dated):", tot)
