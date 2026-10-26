# False-friend test, one method for the whole family: SQL LIKE (case-insensitive for ASCII) over document_cache.body_text,
# apparatus rows excluded (is_front_matter=0 AND is_editorial_note=0). Sets:
#   ON   = editors' recognition chapters (scope tier C / T+C)                    -> id list written to out/ff_ids_on.tsv
#   LATAM= every Latin American section document (out/latam_docs.tsv)           -> out/ff_ids_latam.tsv
#   ALL  = the whole corpus (no id list)
# The SQL for ON/LATAM joins a VALUES list of (volume_id, document_id) pairs on BOTH keys; the full statements are in
# out/ff_sql_on.sql and out/ff_sql_latam.sql.
import csv, sqlite3, json
csv.field_size_limit(10**9)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
TERMS = {"recogni": "%recogni%", "by force": "%by force%", "came to power": "%came to power%",
         "latin america": "%latin america%", "revolution": "%revolution%", "de facto": "%de facto%",
         "CONTROL department of state": "%department of state%"}
sel = ", ".join(f"SUM(c.body_text LIKE '{p}')" for p in TERMS.values())
def q_ids(name, pairs):
    vals = ",".join("('%s','%s')" % (v, d) for v, d in pairs)
    sql = (f"WITH s(v, d) AS (VALUES {vals}) SELECT COUNT(*), {sel} FROM document_cache c JOIN s ON c.volume_id = s.v AND c.document_id = s.d "
           f"WHERE c.is_front_matter = 0 AND c.is_editorial_note = 0")
    open(f"out/ff_sql_{name}.sql", "w").write(sql + ";\n")
    with open(f"out/ff_ids_{name}.tsv", "w") as f:
        for v, d in pairs: f.write(f"{v}\t{d}\n")
    return con.execute(sql).fetchone()
scope = list(csv.DictReader(open("out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
on = sorted({(r["volume_id"], r["document_id"]) for r in scope if r["tier"] in ("C", "T+C")})
latam = sorted({(r["volume_id"], r["document_id"]) for r in csv.DictReader(open("out/latam_docs.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE)})
SQL_ALL = f"SELECT COUNT(*), {sel} FROM document_cache c WHERE c.is_front_matter = 0 AND c.is_editorial_note = 0"
open("out/sql_trace.log", "a").write("[false_friend.py] " + SQL_ALL + "\n[false_friend.py] ON and LATAM statements: out/ff_sql_on.sql, out/ff_sql_latam.sql\n")
res = {"ON": q_ids("on", on), "LATAM": q_ids("latam", latam), "ALL": con.execute(SQL_ALL).fetchone()}
out = {}
for k, r in res.items():
    n = r[0]; out[k] = {"n": n}
    for (t, _), x in zip(TERMS.items(), r[1:]): out[k][t] = x
json.dump(out, open("out/false_friend.json", "w"), indent=1)
print("term".ljust(28), "ON (editors' chapters)".rjust(26), "LATAM sections".rjust(24), "ALL corpus".rjust(26))
for t in TERMS:
    cells = []
    for k in ("ON", "LATAM", "ALL"):
        n = out[k]["n"]; x = out[k][t]; cells.append(f"{x} of {n} ({x/n:.3f})")
    print(t.ljust(28), cells[0].rjust(26), cells[1].rjust(24), cells[2].rjust(26))
