# Refuter: re-run the overview's quantitative claims with the memo's SQL (explicit Ed2 list).
import json, os, re, sqlite3
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s2"
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
ED2 = ("frus1951-54IranEd2", "frus1969-76ve15p2Ed2")
NA = "c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
def q(sql, *a):
    print("SQL:", sql, a if a else "")
    r = con.execute(sql, a).fetchall(); print("   ->", r); return r

print("## M1 coverage")
q("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache")
den = q(f"SELECT COUNT(*) FROM document_cache c WHERE {NA}")[0][0]

print("\n## family (claim 1: 'about one document in a hundred'; scope: 3,036 docs, 447 volumes)")
fam = q(f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA}",
        "corrupt OR bribe OR briberi OR graft OR kickback OR embezzl")[0]
print(f"   family {fam[0]} of {den} = {100*fam[0]/den:.2f}% -> 'about one in a hundred'; volumes {fam[1]}")
# membership check vs family_hits.json
fh = set(tuple(x) for x in json.load(open(RUN + "/family_hits.json")))
rows = set(con.execute(f"SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA}",
                       ("corrupt OR bribe OR briberi OR graft OR kickback OR embezzl",)).fetchall())
print("   family_hits.json == re-run set:", rows == fh, len(rows), len(fh))

print("\n## claim 2: 553 volumes (above: COUNT(DISTINCT volume_id)); manifest volumes:", len(json.load(open(RES + "/manifest.json"))))

print("\n## claim 3: 19 documents retrieved whole and read")
cited = [l.strip().split("/") for l in open(RUN + "/cited.txt") if l.strip()]
print("   cited.txt pairs:", len(cited))
whole = 0
for v, d in cited:
    r = con.execute("SELECT header, COALESCE(dateline,''), COALESCE(source_note,''), body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    p = f"{RUN}/texts/{v}__{d}.txt"
    t = open(p, encoding="utf-8").read() if os.path.exists(p) else None
    ok = t is not None and r[3] in t
    whole += ok
    print(f"   {v}/{d}: length(body_text)={r[4]} texts file={'present' if t is not None else 'MISSING'} holds whole body_text={ok}")
print(f"   retrieved whole (texts/ file holds the full body_text): {whole} of {len(cited)}")

print("\n## claim 4: Marshall Mission Files, Lot 54 D 270 = ten NARA series under creator 10481258")
cur = json.load(open(RES + "/curated-lot-resolutions.json"))
lot = [l for l in cur["lots"] if l.get("lotNumber") == "54D270"]
for l in lot:
    print("   kind", l.get("kind"), "creatorNaId", l.get("creatorNaId"), "candidates", len(l.get("candidates", [])))
    for c in l.get("candidates", []): print("     ", c.get("naId"), c.get("title"))

print("\n## claim 5: 'Foreign Corrupt Practices Act' by name: four documents, all 1977-80; none in the thirteen 1981-88 volumes")
r = q(f"SELECT c.volume_id, c.document_id, t.date_iso FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE frus_documents MATCH ? AND {NA} ORDER BY 1,2",
      '"foreign corrupt practices"')
# does each hit literally hold the phrase?
for v, d, dt in r:
    b = con.execute("SELECT header||' '||COALESCE(dateline,'')||' '||COALESCE(source_note,'')||' '||body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0]
    print(f"   {v}/{d} {dt}: literal 'foreign corrupt practices' present = {bool(re.search(r'foreign corrupt practices', b, re.I))}; 'Foreign Corrupt Practices Act' present = {bool(re.search(r'foreign corrupt practices act', b, re.I))}")
q(f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA} AND c.volume_id LIKE 'frus1981-88%'", '"foreign corrupt practices"')
q(f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM document_cache c WHERE {NA} AND c.volume_id LIKE 'frus1981-88%'")
q("SELECT COUNT(DISTINCT volume_id) FROM document_cache WHERE volume_id LIKE 'frus1981-88%'")

print("\n## further overview numbers (checked beyond the five)")
q(f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA} AND c.volume_id LIKE 'frus1981-88%'", '"corrupt practices"')
q(f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA} AND c.volume_id LIKE 'frus1981-88%'", 'corrupt OR bribe OR briberi')
q(f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA}", '"church committee"')
q(f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA}", '"church committee" AND (bribe OR bribery OR payments)')
q(f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA}", '(bribe OR bribery) AND (consul OR consular) AND (fee OR fees)')
q(f"SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA}", '"department of state"')
q(f"SELECT COUNT(DISTINCT c.volume_id) FROM document_cache c WHERE {NA}")
q(f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA}", 'ZZZ_IMPOSSIBLE_ZZZ')
# decade densities for the 1930s, 1960s, 1970s
print("decades:")
den_dec = {}
for (k, n) in con.execute(f"SELECT substr(t.date_iso,1,3), COUNT(*) FROM document_cache c JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE {NA} AND t.date_iso IS NOT NULL GROUP BY 1"):
    den_dec[k] = n
fam_dec = {}
for (k, n) in con.execute(f"SELECT substr(t.date_iso,1,3), COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE frus_documents MATCH ? AND {NA} GROUP BY 1", ("corrupt OR bribe OR briberi OR graft OR kickback OR embezzl",)):
    fam_dec[k] = n
for k in ("193", "196", "197"):
    print(f"   {k}0s: {fam_dec.get(k)} of {den_dec.get(k)} = {1000*fam_dec.get(k,0)/den_dec[k]:.2f} per 1,000")
# top volume frus1947v07 = 71
q(f"SELECT c.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NA} GROUP BY 1 ORDER BY 2 DESC LIMIT 3", "corrupt OR bribe OR briberi OR graft OR kickback OR embezzl")
# lockheed 50 and the 27 referent (regex as in lockheed.py)
print("lockheed.py source:"); print(open(RUN + "/lockheed.py").read())
# series-facts 11 of 698 before 1940
sf = json.load(open(RES + "/series-facts-index.json"))
rows = sf.get("byNaId", {})
y0 = [r.get("y0") for r in rows.values()]
print("series-facts rows:", len(rows), "with y0:", sum(1 for y in y0 if y is not None), "starting before 1940:", sum(1 for y in y0 if y is not None and y < 1940))
# near-duplicate reprints: 16 copies -> 3,020
print("vec_baselines nd_family pairs:", len(json.load(open(RUN + "/vec_baselines.json"))["nd_family"]))
