# Check every collection pair exists in document_cache (both keys), is not apparatus, is not an Ed2 volume beside its
# first edition, was retrieved whole this session (out/reading_log.tsv), and say whether it is in the measured scope set.
# Also fetch document_number, date and the manifest title for the edition citation.
import csv, json, sqlite3
csv.field_size_limit(10**9)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL = """SELECT c.document_number, c.is_front_matter, c.is_editorial_note, d.date_iso, length(c.body_text), c.header
         FROM document_cache c LEFT JOIN document_dates d ON d.volume_id = c.volume_id AND d.document_id = c.document_id
         WHERE c.volume_id = ? AND c.document_id = ?"""
open("out/sql_trace.log", "a").write(f"[collection_check.py] {' '.join(SQL.split())}  -- once per collection pair\n")
man = {v["volumeId"]: " ".join(v["title"].split()) for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
scope = {(r["volume_id"], r["document_id"]): r["tier"] for r in csv.DictReader(open("out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE)}
whole = {(r[0], r[1]) for r in csv.reader(open("out/reading_log.tsv"), delimiter="\t") if r[4] == "whole"}
rows = []; seen = set()
for f, p in csv.reader(open("out/collection_pairs.tsv"), delimiter="\t"):
    v, d = p.split("/")
    r = con.execute(SQL, (v, d)).fetchone()
    assert r is not None, p
    assert (v, d) not in seen, "duplicate " + p; seen.add((v, d))
    num, fm, en, dt, blen, h = r
    rows.append({"finding": f, "pair": p, "exists": True, "front_matter": fm, "editorial_note": en, "date": dt, "doc_number": num,
                 "body_chars": blen, "retrieved_whole": (v, d) in whole, "in_scope_tier": scope.get((v, d), "ANCHOR (outside measured set)"),
                 "ed2": v.endswith("Ed2"), "volume_title": man.get(v), "header": " ".join(h.split()),
                 "url": f"https://history.state.gov/historicaldocuments/{v}/{d}"})
json.dump(rows, open("out/collection_check.json", "w"), indent=1, ensure_ascii=False)
for x in rows: print(f"{x['finding']} {x['pair']:24s} n={x['doc_number']:>5} {x['date']} fm={x['front_matter']} en={x['editorial_note']} whole={x['retrieved_whole']} tier={x['in_scope_tier']} | {x['volume_title'][:95]}")
print("pairs:", len(rows), "| all exist:", all(x['exists'] for x in rows), "| any apparatus:", any(x['front_matter'] or x['editorial_note'] for x in rows),
      "| any Ed2:", any(x['ed2'] for x in rows), "| all retrieved whole:", all(x['retrieved_whole'] for x in rows),
      "| anchors outside measured set:", sum(1 for x in rows if x['in_scope_tier'].startswith('ANCHOR')))
