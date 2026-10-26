# Text tier of the scope: Latin American documents (out/latam_docs.tsv), apparatus excluded, matching
# the recognition-of-a-government NEAR rule AND the force vocabulary. Writes out/scope_text.tsv and
# appends every SQL statement it runs to out/sql_trace.log.
import csv, sqlite3
csv.field_size_limit(10**9)
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con = sqlite3.connect(DB, uri=True)
trace = open("out/sql_trace.log", "a")
def q(sql, args=()):
    trace.write("[scope_text.py] " + " ".join(sql.split()) + (f"  -- args={args}" if args else "") + "\n")
    return con.execute(sql, args).fetchall()
latam = {}
with open("out/latam_docs.tsv") as f:
    for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
        latam[(r["volume_id"], r["document_id"])] = (r["country"], r["breadcrumb"])
Q_REC = "NEAR(recogn* govern*, 6) OR NEAR(recogn* regim*, 6) OR NEAR(recogn* junta, 6)"
Q_FORCE = 'revolut* OR coup OR junta OR "de facto" OR overthrow* OR insurrect* OR golpe OR "provisional government" OR usurp* OR unconstitut*'
MATCH = f"({Q_REC}) AND ({Q_FORCE})"
sql = """SELECT f.volume_id, f.document_id, c.is_front_matter, c.is_editorial_note, d.date_iso
         FROM frus_documents f
         JOIN document_cache c ON c.volume_id = f.volume_id AND c.document_id = f.document_id
         LEFT JOIN document_dates d ON d.volume_id = f.volume_id AND d.document_id = f.document_id
         WHERE frus_documents MATCH ?"""
rows = q(sql, (MATCH,))
tot = len(rows); app = sum(1 for r in rows if r[2] or r[3])
inl = [r for r in rows if (r[0], r[1]) in latam]
keep = [r for r in inl if not r[2] and not r[3]]
with open("out/scope_text.tsv", "w") as o:
    o.write("volume_id\tdocument_id\tdate_iso\tcountry\tbreadcrumb\n")
    for r in sorted(keep):
        c, b = latam[(r[0], r[1])]
        o.write(f"{r[0]}\t{r[1]}\t{r[4] or ''}\t{c}\t{b}\n")
print("MATCH:", MATCH)
print("corpus hits", tot, "of which apparatus", app, "| in LatAm sections", len(inl), "| LatAm non-apparatus kept", len(keep))
