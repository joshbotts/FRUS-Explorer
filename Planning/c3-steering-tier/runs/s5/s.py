import sqlite3, sys
# usage: s.py "<FTS5 MATCH expr on frus_documents>" N [dmin dmax]
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
expr = sys.argv[1]; n = int(sys.argv[2])
dmin = sys.argv[3] if len(sys.argv) > 3 else "0000"
dmax = sys.argv[4] if len(sys.argv) > 4 else "9999"
q = """SELECT c.volume_id, c.document_id, d.date_iso, substr(c.header,1,110), bm25(frus_documents) sc,
 snippet(frus_documents,6,'[',']','...',22)
 FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
 LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
 WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0
 AND (d.date_iso IS NULL OR (d.date_iso>=? AND d.date_iso<=?))
 ORDER BY sc LIMIT ?"""
tot = db.execute("""SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
 LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
 WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0
 AND (d.date_iso IS NULL OR (d.date_iso>=? AND d.date_iso<=?))""",(expr,dmin,dmax)).fetchone()[0]
print("TOTAL", tot, "expr:", expr, dmin, dmax)
for r in db.execute(q,(expr,dmin,dmax,n)):
    print(f"{r[0]}/{r[1]} {r[2]} {r[3]!r} bm25={r[4]:.1f}\n    {r[5]!r}")
