# Re-run the memo's pointed-at query (external_citations over the session's core set) and the came-from decimal classes.
import sqlite3, json
m = sqlite3.connect(":memory:")
m.execute("ATTACH DATABASE 'file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro' AS f")
m.execute("CREATE TEMP TABLE core(volume_id TEXT, document_id TEXT, yr INT)")
core = json.load(open("/Users/jbotts/frus-analysis/c3v/runs/v2/coreset.json"))
m.executemany("INSERT INTO core VALUES (?,?,?)", [(x["v"], x["d"], int(x["date"][:4])) for x in core])
print("core rows", m.execute("SELECT COUNT(*) FROM core").fetchone()[0])
Q2 = """SELECT e.repository, e.collection, e.lot_file_norm, COUNT(*) n, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs, MIN(c.yr), MAX(c.yr)
FROM core c JOIN f.external_citations e ON e.volume_id=c.volume_id AND e.document_id=c.document_id
GROUP BY 1,2,3 ORDER BY docs DESC LIMIT 5"""
for r in m.execute(Q2): print(r)
# the first row more directly: Department of State rows with no collection and no lot -> decimal anchors?
print("DoS/no collection/no lot rows by citation kind columns:")
cols = [r[1] for r in m.execute("PRAGMA f.table_info(external_citations)")]; print(cols)
r = m.execute("""SELECT COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id), MIN(c.yr), MAX(c.yr) FROM core c JOIN f.external_citations e ON e.volume_id=c.volume_id AND e.document_id=c.document_id WHERE e.repository='Department of State' AND e.collection IS NULL AND e.lot_file_norm IS NULL""").fetchone(); print("DoS no-collection no-lot:", r)
if "decimal_class" in cols or "decimal_file" in cols:
    dc = "decimal_class" if "decimal_class" in cols else "decimal_file"
    r = m.execute(f"""SELECT COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id), MIN(c.yr), MAX(c.yr) FROM core c JOIN f.external_citations e ON e.volume_id=c.volume_id AND e.document_id=c.document_id WHERE e.{dc} IS NOT NULL""").fetchone(); print(f"rows with {dc} not null:", r)
print("sample of the DoS no-collection rows:")
for r in m.execute("""SELECT e.* FROM core c JOIN f.external_citations e ON e.volume_id=c.volume_id AND e.document_id=c.document_id WHERE e.repository='Department of State' AND e.collection IS NULL AND e.lot_file_norm IS NULL LIMIT 5"""): print(r)
print("came-from decimal classes:")
for r in m.execute("""SELECT s.decimal_class, COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.decimal_class IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 8"""): print(r)
print("came-from rows over core:", m.execute("SELECT COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id").fetchone())
