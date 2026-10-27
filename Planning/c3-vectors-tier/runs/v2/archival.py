# Came-from (document_sources) and pointed-at (external_citations) channels over the Cuba core set (coreset.json), never summed.
# Core ids are loaded into a TEMP table of an in-memory connection; the index is ATTACHed read-only as f.
import sqlite3, json, collections
m = sqlite3.connect(":memory:")
m.execute("ATTACH DATABASE 'file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro' AS f")
m.execute("CREATE TEMP TABLE core(volume_id TEXT, document_id TEXT, yr INT)")
m.executemany("INSERT INTO core VALUES (?,?,?)", [(x["v"], x["d"], int(x["date"][:4])) for x in json.load(open("coreset.json"))])
Q1 = """SELECT s.repository, s.record_group, COALESCE(s.lot_file_norm, s.series_name), s.citation_era, COUNT(*) n, MIN(c.yr), MAX(c.yr)
FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id
GROUP BY 1,2,3,4 ORDER BY n DESC LIMIT 30"""
print("== CAME-FROM (document_sources) over core set; total rows:", m.execute("SELECT COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id").fetchone()[0], "of core", m.execute("SELECT COUNT(*) FROM core").fetchone()[0])
print(Q1)
for r in m.execute(Q1): print(r)
Q2 = """SELECT e.repository, e.collection, e.lot_file_norm, COUNT(*) n, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs, MIN(c.yr), MAX(c.yr)
FROM core c JOIN f.external_citations e ON e.volume_id=c.volume_id AND e.document_id=c.document_id
GROUP BY 1,2,3 ORDER BY docs DESC LIMIT 30"""
print("== POINTED-AT (external_citations) over core set")
print(Q2)
for r in m.execute(Q2): print(r)
Q3 = """SELECT s.decimal_class, COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.decimal_class IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 12"""
print("== came-from decimal classes"); print(Q3)
for r in m.execute(Q3): print(r)
