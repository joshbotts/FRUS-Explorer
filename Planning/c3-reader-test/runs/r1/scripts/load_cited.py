# load work/cited_docs.tsv into work/scope.db as table cited(finding, volume_id, document_id, role); verify every pair exists in document_cache (explicit SQL, logged)
import sqlite3, sys
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
rows = [l.rstrip("\n").split("\t") for l in open(frus.RUN + "/work/cited_docs.tsv")][1:]
conn = frus.connect()
bad = []
for f, v, d, role in rows:
    r = frus.sql(conn, "SELECT is_front_matter, is_editorial_note, document_number FROM document_cache WHERE volume_id = ? AND document_id = ?", (v, d), script="scripts/load_cited.py", log=(f == rows[0][0] and v == rows[0][1] and d == rows[0][2]))
    if not r or r[0][0] or r[0][1] or not r[0][2]:
        bad.append((v, d, r))
print("pairs:", len(rows), "| distinct:", len(set((v, d) for f, v, d, role in rows)), "| problems:", bad)
s = sqlite3.connect(frus.RUN + "/work/scope.db")
s.execute("DROP TABLE IF EXISTS cited"); s.execute("CREATE TABLE cited(finding INT, volume_id TEXT, document_id TEXT, role TEXT, PRIMARY KEY(finding, volume_id, document_id))")
s.executemany("INSERT INTO cited VALUES (?,?,?,?)", [(int(f), v, d, role) for f, v, d, role in rows]); s.commit()
print("loaded", s.execute("SELECT COUNT(*) FROM cited").fetchone()[0])
