# Re-run every find.sh query the log records (same MATCH, glob, bm25 order and LIMIT), and the same without LIMIT; test membership
# of each cited pair. Also the LIKE query, the corpus-wide mention MATCH, and the heading scope set (my_core_pairs.json).
import sqlite3, json, re
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
log = open("/Users/jbotts/frus-analysis/c3v/runs/v2/queries.log").read()
calls = re.findall(r"\./find\.sh '((?:[^']|'')*)' '([^']+)'(?: (\d+))?", log)
print("find.sh invocations in the log:", len(calls))
cited = [("frus1870","d197"),("frus1881","d405"),("frus1898","d490"),("frus1898","ch83"),("frus1902","d313"),("frus1903","d331"),("frus1906p1","d427"),("frus1933v05","d281"),("frus1941v07","d119"),("frus1952-54v04","d343"),("frus1961-63v10","d202"),("frus1961-63v11","d34"),("frus1969-76ve10","d205"),("frus1969-76v12","d211"),("frus1977-80v23","d21"),("frus1977-80v23","d98")]
SQL = "SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.volume_id GLOB ? AND c.is_front_matter=0 AND c.is_editorial_note=0 ORDER BY bm25(frus_documents)"
within = {p: [] for p in cited}; unlimited = {p: [] for p in cited}
for n, (q, g, lim) in enumerate(calls, 1):
    lim = int(lim) if lim else 8
    try:
        rows = db.execute(SQL, (q, g)).fetchall()
    except Exception as e:
        print(f"[{n}] ERROR {e}: {q[:60]}"); continue
    top = rows[:lim]
    print(f"[{n}] n={len(rows)} limit={lim} glob={g} :: {q[:90]}")
    for p in cited:
        if p in top: within[p].append(n)
        if p in rows: unlimited[p].append(n)
print("\n== LIKE query (Nov 1875):", db.execute("SELECT c.volume_id||'/'||c.document_id FROM document_cache c JOIN document_dates d USING(volume_id, document_id) WHERE d.date_iso BETWEEN '1875-11-01' AND '1875-11-30' AND c.body_text LIKE '%Cuba%' AND c.is_front_matter=0 AND c.is_editorial_note=0").fetchall())
mention = set(db.execute("SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '{header dateline body_text}: (cuba OR cuban OR havana OR habana)' AND c.is_front_matter=0 AND c.is_editorial_note=0").fetchall())
core = set(tuple(p.split("/")) for p in json.load(open("my_core_pairs.json")))
print("\n== per cited pair: find.sh queries returning it within LIMIT | unlimited | in corpus-wide mention MATCH | in heading scope set")
for p in cited:
    print(f"  {'/'.join(p):24s} within={within[p]!s:14s} unlimited={unlimited[p]!s:18s} mention={p in mention} scope={p in core}")
