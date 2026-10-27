import sqlite3, sys
# usage: find.py "FTS query" date_lo date_hi [limit] [colspec]
q, lo, hi = sys.argv[1], sys.argv[2], sys.argv[3]
lim = int(sys.argv[4]) if len(sys.argv)>4 else 20
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
sql = """SELECT d.volume_id, d.document_id, dd.date_iso, substr(d.header,1,70), length(d.body_text),
 snippet(frus_documents, 6, '[', ']', ' .. ', 24), bm25(frus_documents)
 FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
 LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
 WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0
 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
 AND dd.date_iso >= ? AND dd.date_iso < ? ORDER BY bm25(frus_documents) LIMIT ?"""
for r in db.execute(sql,(q,lo,hi,lim)):
    print(f"{r[0]}/{r[1]} {r[2]} len={r[4]} | {r[3]} | {r[5]}".replace("\n"," "))
