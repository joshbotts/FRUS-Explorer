"""Refuter step 2: the five headline numbers of overview.md, re-run from the index and the bundle."""
import json, re, sqlite3
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
q = lambda sql, *a: con.execute(sql, a).fetchall()

print("== N1: 'all 553 volumes' (memo M1) ==")
print(q("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache"))
man = json.load(open(RES + "/manifest.json"))
print("manifest volumes:", len(man), "published:", sum(1 for v in man if v.get("status") == "published"))

print("== N2: 'about one document in a hundred' (memo M2, M5: 3,057 of 311,429) ==")
den = q("SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')")[0][0]
FAM = "corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl"
hits = q("""SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
 WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY f.volume_id, f.document_id""", FAM)
nvol = len(set(v for v, d in hits))
print("denominator", den, "| family hits", len(hits), "in", nvol, "volumes |", round(1000.0 * len(hits) / den, 1), "per 1,000 =", round(100.0 * len(hits) / den, 2), "%", "= 1 in", round(den / len(hits)))
raw = q("SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM frus_documents WHERE frus_documents MATCH ?", FAM)
print("raw (M4) hits, volumes:", raw)

print("== N3: 'about three in four of a sample' (memo M6 referent 31 of 40) ==")
M = len(hits); sample = [hits[int(i * M / 40.0)] for i in range(40)]
STRICT = re.compile(r"\b(corrupt|corruption|bribe|bribery|graft|kickback|embezzlement)\b")
TOL = re.compile(r"\b(corrupt\w*|brib(e|es|ed|ing|ery|eries)\b|graft\w*|kick[\s\-]?backs?|embezzl\w*)", re.I)
off = {"frus1894app2/d59", "frus1904/d578", "frus1911/d1020", "frus1917/d387", "frus1919Parisv07/d25", "frus1948v06/d51", "frus1955-57v05/d164", "frus1961-63v25/d24", "frus1969-76v15/d55"}
s = t = 0; seen_off = 0
for v, d in sample:
    h, dl, sn, b = q("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?", v, d)[0]
    txt = re.sub(r"\s+", " ", " ".join([h or "", dl or "", sn or "", b or ""]))
    s += bool(STRICT.search(txt)); t += bool(TOL.search(txt))
    key = v + "/" + d
    if key in off:
        seen_off += 1
        m = TOL.search(txt); print("  OFF-TOPIC claimed:", key, "|", txt[max(0, m.start() - 100):m.end() + 100] if m else "NO MATCH")
print("sample size", len(sample), "STRICT", s, "TOLERANT", t, "| claimed off-topic ids present in the sample:", seen_off, "of", len(off))
print("sample ids:", " ".join(v + "/" + d for v, d in sample))
print("31 of 40 =", round(31 / 40, 2), "-> 'about three in four' =", round(3 / 4, 2))

print("== N4: 'The collection holds twelve documents' (memo M10 / §8) ==")
col = json.load(open("/Users/jbotts/frus-analysis/c3s/runs/s3/collection.fruscollection"))
docs = [(e["volumeId"], e["documentId"]) for e in col["entries"] if e["kind"] == "document"]
print("document entries", len(docs), "distinct", len(set(docs)))

print("== N5: Lot 54D270 'which NARA split into ten series under ... creator identifier 10481258' ==")
cur = json.load(open(RES + "/curated-lot-resolutions.json"))
print("curated-lot-resolutions keys:", list(cur.keys()))
for row in cur["lots"]:
    if "54D270" in json.dumps(row):
        print(json.dumps(row, indent=1)[:3000])
