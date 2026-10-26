# Post-1950 Latin American hits of R1 (recognition NEAR government/regime/junta) split by whether they also pass R0's force vocabulary.
import csv, sqlite3, re
from collections import Counter
csv.field_size_limit(10**9)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
trace = open("out/sql_trace.log", "a")
latam = {}
for r in csv.DictReader(open("out/latam_docs.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE):
    latam[(r["volume_id"], r["document_id"])] = r["country"]
Q_REC = "NEAR(recogn* govern*, 6) OR NEAR(recogn* regim*, 6) OR NEAR(recogn* junta, 6)"
Q_FORCE = 'revolut* OR coup OR junta OR "de facto" OR overthrow* OR insurrect* OR golpe OR "provisional government" OR usurp* OR unconstitut*'
sql = """SELECT f.volume_id, f.document_id, d.date_iso, c.header FROM frus_documents f
 JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
 LEFT JOIN document_dates d ON d.volume_id=f.volume_id AND d.document_id=f.document_id
 WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso >= '1951'"""
r1 = {}; r0 = set()
for m, tgt in ((Q_REC, "r1"), (f"({Q_REC}) AND ({Q_FORCE})", "r0")):
    trace.write(f"[post1950_peek.py] {' '.join(sql.split())}  -- args=({m!r},)\n")
    for v, d, dt, h in con.execute(sql, (m,)):
        if (v, d) not in latam: continue
        if tgt == "r1": r1[(v, d)] = (dt, latam[(v, d)], " ".join(h.split()))
        else: r0.add((v, d))
print("R1 post-1950 LatAm", len(r1), "R0", len(r0))
c1 = Counter((latam[k], v[0][:4]) for k, v in r1.items() if k in r0)
c2 = Counter((latam[k], v[0][:4]) for k, v in r1.items() if k not in r0)
print("R0 by country-year:", sorted(c1.items(), key=lambda x: (x[0][1], x[0][0])))
print()
print("R1-not-R0 by country-year:", sorted(c2.items(), key=lambda x: (x[0][1], x[0][0])))
with open("out/post1950_r1.tsv", "w") as o:
    for k, v in sorted(r1.items()):
        o.write(f"{k[0]}\t{k[1]}\t{v[0]}\t{v[1]}\t{'R0' if k in r0 else 'R1only'}\t{v[2][:200]}\n")
