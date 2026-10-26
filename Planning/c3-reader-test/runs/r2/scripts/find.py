# Usage: python3 -I scripts/find.py "<FTS MATCH>" [all]   -- prints hits (scope members only unless 'all'),
# with date, tier, header and an FTS snippet of body_text. Logs the SQL to out/sql_trace.log.
import csv, sqlite3, sys
csv.field_size_limit(10**9)
m = sys.argv[1]; allhits = len(sys.argv) > 2 and sys.argv[2] == "all"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
scope = {(r["volume_id"], r["document_id"]): r for r in csv.DictReader(open("out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE)}
sql = """SELECT f.volume_id, f.document_id, d.date_iso, c.header, snippet(frus_documents, 6, '[', ']', '…', 18), bm25(frus_documents) AS score,
         c.is_front_matter, c.is_editorial_note
         FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
         LEFT JOIN document_dates d ON d.volume_id=f.volume_id AND d.document_id=f.document_id
         WHERE frus_documents MATCH ? ORDER BY d.date_iso"""
open("out/sql_trace.log", "a").write(f"[find.py] {' '.join(sql.split())}  -- args=({m!r},)\n")
n = 0
for v, d, dt, h, sn, sc, fm, en in con.execute(sql, (m,)):
    s = scope.get((v, d))
    if not s and not allhits: continue
    n += 1
    tag = s["tier"] if s else ("APP" if (fm or en) else "-")
    print(f"{v}/{d}\t{dt}\t{tag}\t{' '.join(h.split())[:110]}\n    {' '.join(sn.split())[:300]}")
print("hits shown:", n)
