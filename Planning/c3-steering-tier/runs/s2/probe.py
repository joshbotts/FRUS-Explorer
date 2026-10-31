# thread probes: bm25-ranked hits within a volume set, with snippet
import sqlite3, sys
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL = ("SELECT c.volume_id, c.document_id, t.date_iso, substr(c.header,1,110), snippet(frus_documents, 6, '[', ']', '…', 30), bm25(frus_documents) AS score "
       "FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id "
       "WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') {vol} ORDER BY score ASC LIMIT {k}")
def run(label, match, vols=None, k=15):
    vc = ""; args=[match]
    if vols:
        vc = "AND c.volume_id IN (%s)" % ",".join("?"*len(vols)); args += vols
    q = SQL.format(vol=vc, k=k)
    n = con.execute("SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') "+vc, args).fetchone()[0]
    print("=== %s | MATCH %s | vols %s | total %d" % (label, match, vols, n))
    for r in con.execute(q, args): print(" ", r[0], r[1], r[2], "|", r[3], "|", r[4].replace("\n"," "))
print("SQL template:", SQL)
exec(open(sys.argv[1]).read())
