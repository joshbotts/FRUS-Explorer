# Recall of candidate text rules against the editors' recognition chapters (C_all, non-apparatus), and the
# size of each rule's hit set elsewhere in the Latin American sections (non-apparatus), split at 1950.
import csv, sqlite3
from collections import Counter
csv.field_size_limit(10**9)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
trace = open("out/sql_trace.log", "a")
latam = {}
for r in csv.DictReader(open("out/latam_docs.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE):
    latam[(r["volume_id"], r["document_id"])] = r["country"]
scope = list(csv.DictReader(open("out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
C = {(r["volume_id"], r["document_id"]) for r in scope if r["tier"] in ("C", "T+C")}
app = {(v, d) for v, d in con.execute("SELECT volume_id, document_id FROM document_cache WHERE is_front_matter=1 OR is_editorial_note=1")}
dates = {(v, d): (x or "") for v, d, x in con.execute("SELECT volume_id, document_id, date_iso FROM document_dates")}
trace.write("[rule_recall.py] SELECT volume_id, document_id FROM document_cache WHERE is_front_matter=1 OR is_editorial_note=1\n")
trace.write("[rule_recall.py] SELECT volume_id, document_id, date_iso FROM document_dates\n")
Q_REC = "NEAR(recogn* govern*, 6) OR NEAR(recogn* regim*, 6) OR NEAR(recogn* junta, 6)"
Q_FORCE = 'revolut* OR coup OR junta OR "de facto" OR overthrow* OR insurrect* OR golpe OR "provisional government" OR usurp* OR unconstitut*'
RULES = {"R0 rec-NEAR AND force": f"({Q_REC}) AND ({Q_FORCE})",
         "R1 rec-NEAR": Q_REC,
         "R2 recogn*": "recogn*",
         "R3 rec-NEAR AND (force OR relations)": f'({Q_REC}) AND ({Q_FORCE} OR "diplomatic relations" OR NEAR(continu* relations, 3) OR NEAR(resum* relations, 3))'}
for name, m in RULES.items():
    sql = "SELECT volume_id, document_id FROM frus_documents WHERE frus_documents MATCH ?"
    trace.write(f"[rule_recall.py] {sql}  -- args=({m!r},)\n")
    hits = {(v, d) for v, d in con.execute(sql, (m,))}
    hits = {k for k in hits if k in latam and k not in app}
    rec = len(hits & C)
    outside = hits - C
    pre = sum(1 for k in outside if dates.get(k, "")[:4] and dates[k][:4] < "1951")
    post = sum(1 for k in outside if dates.get(k, "")[:4] >= "1951")
    print(f"{name}: LatAm non-apparatus hits {len(hits)} | recall of C_all {rec} of {len(C)} | outside C: {len(outside)} (dated <=1950: {pre}, >=1951: {post})")
