# Absence checks, each run with a positive control ("Department of State") and a negative control ("ZZZ_IMPOSSIBLE_ZZZ")
# in the same pass and the same volume set. FTS5 MATCH (porter stems), apparatus excluded; volume sets named per check.
import sqlite3, json
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
tr = open("out/sql_trace.log", "a")
SQL = """SELECT f.volume_id, f.document_id, d.date_iso, c.header FROM frus_documents f
 JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
 LEFT JOIN document_dates d ON d.volume_id=f.volume_id AND d.document_id=f.document_id
 WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id IN ({vols}) {extra} ORDER BY d.date_iso"""
CHECKS = [
 ("Brazil 1964 coup: recognition / continuing relations", ["frus1964-68v31"], "AND d.date_iso BETWEEN '1964-03-25' AND '1964-05-31'",
  'Brazil* AND (recogn* OR NEAR(continu* relations, 3) OR NEAR(resum* relations, 3))'),
 ("1981-88 South America volume: recognition of governments", ["frus1981-88v16"], "", 'NEAR(recogn* govern*, 6) OR NEAR(recogn* regim*, 6) OR NEAR(recogn* junta, 6)'),
 ("Bolivia 1980 (Garcia Meza coup): recognition", ["frus1977-80v24"], "AND d.date_iso BETWEEN '1980-07-01' AND '1981-01-20'", 'Bolivia* AND recogn*'),
 ("Grenada 1979 / Suriname 1980 (non-republic Caribbean, excluded by the inclusion rule)", ["frus1977-80v23"], "", '(Grenada OR Suriname) AND (recogn* OR coup)'),
]
out = []
for name, vols, extra, m in CHECKS:
    vl = ",".join("'%s'" % v for v in vols); sql = SQL.format(vols=vl, extra=extra)
    res = {}
    for label, q in (("query", m), ("positive control", '"Department of State"'), ("negative control", 'ZZZ_IMPOSSIBLE_ZZZ')):
        tr.write(f"[absence_checks.py] {' '.join(sql.split())}  -- args=({q!r},)\n")
        rows = con.execute(sql, (q,)).fetchall(); res[label] = rows
    print(f"== {name} | volumes {vols} {extra}\n   query {m!r}: {len(res['query'])} docs | positive control: {len(res['positive control'])} | negative control: {len(res['negative control'])}")
    for r in res["query"][:12]: print("     ", r[0] + "/" + r[1], r[2], " ".join(r[3].split())[:110])
    out.append({"check": name, "volumes": vols, "extra": extra, "match": m, "n_query": len(res["query"]), "n_pos": len(res["positive control"]), "n_neg": len(res["negative control"]),
                "hits": [f"{r[0]}/{r[1]}" for r in res["query"]]})
json.dump(out, open("out/absence_checks.json", "w"), indent=1)
