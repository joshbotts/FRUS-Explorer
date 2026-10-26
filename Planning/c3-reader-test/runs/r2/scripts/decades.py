# Decade shape of the scope tiers with denominators. Periodisation: document_dates.date_iso (checked against the TEI
# frus:doc-dateTime-min below). Denominators: (a) all dated non-apparatus documents in the corpus, by decade (SQL);
# (b) dated non-apparatus documents in Latin American sections (out/latam_docs.tsv), by decade.
import csv, sqlite3, json, glob
from collections import Counter, defaultdict
csv.field_size_limit(10**9)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
tr = open("out/sql_trace.log", "a")
SQL_DEN = """SELECT substr(d.date_iso,1,3) || '0s' AS decade, COUNT(*) FROM document_cache c
  JOIN document_dates d ON d.volume_id = c.volume_id AND d.document_id = c.document_id
  WHERE c.is_front_matter = 0 AND c.is_editorial_note = 0 AND d.date_iso GLOB '[0-9][0-9][0-9][0-9]*'
  GROUP BY decade ORDER BY decade"""
tr.write("[decades.py] " + " ".join(SQL_DEN.split()) + "\n")
den_all = dict(con.execute(SQL_DEN).fetchall())
SQL_APP = "SELECT c.volume_id, c.document_id, c.is_front_matter, c.is_editorial_note, d.date_iso FROM document_cache c LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id"
tr.write("[decades.py] " + SQL_APP + "\n")
meta = {(v, d): (fm, en, dt) for v, d, fm, en, dt in con.execute(SQL_APP)}
den_latam = Counter()
for r in csv.DictReader(open("out/latam_docs.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE):
    fm, en, dt = meta[(r["volume_id"], r["document_id"])]
    if fm or en or not dt or not dt[:4].isdigit(): continue
    den_latam[dt[:3] + "0s"] += 1
scope = list(csv.DictReader(open("out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
num = {"C": defaultdict(Counter), "T": defaultdict(Counter), "U": defaultdict(Counter)}
undated = Counter()
for r in scope:
    dt = r["date_iso"]
    if not dt or not dt[:4].isdigit(): undated[r["tier"]] += 1; continue
    dec = dt[:3] + "0s"
    if r["tier"] in ("C", "T+C"): num["C"][dec][r["volume_id"]] += 1
    if r["tier"] in ("T", "T+C"): num["T"][dec][r["volume_id"]] += 1
    num["U"][dec][r["volume_id"]] += 1
decs = sorted(set(den_all) | set(den_latam))
rows = []
for dec in decs:
    row = {"decade": dec, "den_all": den_all.get(dec, 0), "den_latam": den_latam.get(dec, 0)}
    for k in ("C", "T", "U"):
        c = num[k].get(dec, Counter()); n = sum(c.values())
        top = c.most_common(1)[0] if c else ("", 0)
        row[k] = n; row[k + "_per1000_all"] = round(1000 * n / row["den_all"], 2) if row["den_all"] else None
        row[k + "_per1000_latam"] = round(1000 * n / row["den_latam"], 1) if row["den_latam"] else None
        row[k + "_topvol"] = top[0]; row[k + "_topvol_n"] = top[1]
    rows.append(row)
json.dump({"rows": rows, "undated": undated}, open("out/decades.json", "w"), indent=1)
print("decade | dated non-app corpus | dated non-app LatAm | C n (per1000 corpus, per1000 LatAm) top vol | T n (...) top vol | U n (...) top vol")
for r in rows:
    if not (r["U"]): 
        print(f"{r['decade']} | {r['den_all']} | {r['den_latam']} | 0"); continue
    def f(k): return f"{r[k]} ({r[k+'_per1000_all']}, {r[k+'_per1000_latam']}) {r[k+'_topvol']}:{r[k+'_topvol_n']}"
    print(f"{r['decade']} | {r['den_all']} | {r['den_latam']} | {f('C')} | {f('T')} | {f('U')}")
print("undated scope docs by tier:", dict(undated))
# periodisation check against TEI frus:doc-dateTime-min
agree = differ = missing = 0; diffs = []
for f in glob.glob("out/tei/*.json"):
    j = json.load(open(f))
    for d, rec in j["docs"].items():
        dmin = (rec.get("dmin") or "")[:10]
        di = meta[(j["volume_id"], d)][2] or ""
        if not dmin: missing += 1
        elif dmin == di[:10]: agree += 1
        else: differ += 1; diffs.append((j["volume_id"], d, di, rec.get("dmin")))
print(f"TEI doc-dateTime-min vs date_iso over {agree+differ+missing} scope docs: agree {agree}, differ {differ}, TEI attribute missing {missing}")
for x in diffs[:12]: print("   differ:", x)
json.dump(diffs, open("out/date_diffs.json", "w"))
