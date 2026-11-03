#!/usr/bin/env python3
"""The assessment's smaller checks, read-only, in one run
(Planning/Agentic-Guide-Full-Corpus-Premise-Assessment-2026-11-02.md §2).

    python3 -I checks.py <app data folder> <bundle Resources folder> <index copy .db> <tei_pass.tsv>

The app data folder is the container's Application Support/FRUSExplorer; the index copy is opened
read-only."""
import csv, hashlib, json, os, sqlite3, sys
import xml.etree.ElementTree as ET

TEI = "{http://www.tei-c.org/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
C, R, DB, TSV = sys.argv[1:5]
VOL = os.path.join(C, "volumes")
man = json.load(open(os.path.join(R, "manifest.json")))
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
q = lambda sql: con.execute(sql).fetchall()

def tei_docs(v):
    root = ET.parse(os.path.join(VOL, v + ".xml")).getroot()
    return [(d.get(XMLID), d.get("subtype")) for d in root.iter(TEI + "div") if d.get("type") == "document"]

print("1. Footnote share of document-division text, by era band (volume dated by the mean of the")
print("   first and last years of its manifest range, rounded down; guide §A.5's rule)")
rows = {r["filename"]: r for r in csv.DictReader(open(TSV), delimiter="\t")}
bands = [(1861, 1899), (1900, 1944), (1945, 1964), (1965, 1988)]
agg = {b: [0] * 5 for b in bands}
for v in man:
    y = (int(v["dateRange"]["earliest"][:4]) + int(v["dateRange"]["latest"][:4])) // 2
    r = rows[v["filename"]]
    for b in bands:
        if b[0] <= y <= b[1]:
            a = agg[b]; a[0] += 1; a[4] += int(r["docs"])
            a[1] += int(r["body_chars"]); a[2] += int(r["source_chars"]); a[3] += int(r["note_chars"])
allr = [sum(int(r[k]) for r in rows.values()) for k in ("body_chars", "source_chars", "note_chars", "docs")]
tot = sum(allr[:3])
print(f"   all 553 volumes: {allr[3]:,} documents; notes {allr[2]:,} of {tot:,} characters "
      f"({allr[2] / tot:.4f}); source notes {allr[1]:,} ({allr[1] / tot:.4f})")
for b in bands:
    a = agg[b]; t = a[1] + a[2] + a[3]
    print(f"   {b[0]}-{b[1]}: {a[0]} volumes, {a[4]:,} documents; notes {a[3]:,} of {t:,} "
          f"({a[3] / t:.4f}); source notes ({a[2] / t:.4f})")

print("2. The second editions' overlap on the TEI (guide §14.9)")
for a, b in (("frus1951-54Iran", "frus1951-54IranEd2"), ("frus1969-76ve15p2", "frus1969-76ve15p2Ed2")):
    A, B = tei_docs(a), tei_docs(b)
    hist = lambda L: sum(1 for _, s in L if s == "historical-document")
    print(f"   {a} {len(A)} ({hist(A)} historical), {b} {len(B)} ({hist(B)} historical), "
          f"shared ids {len({i for i, _ in A} & {i for i, _ in B})}")

print("3. The guide's document predicate, GLOB 'd[0-9]*' (§4.2, §4.3), against the TEI")
non_d = set()
for v in man:
    vid = v["filename"][:-4]
    if vid in ("frus1958-60v05mSupp", "frus1981-88v01", "frus1981-88v04", "frus1981-88v05",
               "frus1981-88v11", "frus1981-88v44p1"):
        non_d |= {(vid, i) for i, _ in tei_docs(vid) if not (i[:1] == "d" and i[1:2].isdigit())}
START = ("EXISTS (SELECT 1 FROM page_ranges p WHERE p.volume_id = dc.volume_id "
         "AND p.document_id = dc.document_id AND p.is_start = 1)")
start_non_d = set(q("SELECT DISTINCT volume_id, document_id FROM page_ranges "
                    "WHERE is_start = 1 AND document_id NOT GLOB 'd[0-9]*'"))
d_rows = q("SELECT COUNT(*) FROM document_cache WHERE document_id GLOB 'd[0-9]*'")[0][0]
d_no_start = q("SELECT COUNT(*) FROM document_cache dc WHERE dc.document_id GLOB 'd[0-9]*' "
               "AND NOT " + START)[0][0]
union = q("SELECT COUNT(*) FROM document_cache dc WHERE dc.document_id GLOB 'd[0-9]*' OR " + START)[0][0]
supp = sum(1 for v, _ in non_d if v.endswith("mSupp"))
others = sorted(i for v, i in non_d if not v.endswith("mSupp"))
print(f"   index rows matching the predicate: {d_rows:,}")
print(f"   TEI documents in the six volumes with a non-d id: {len(non_d)}; "
      f"non-d rows with a page_ranges start row: {len(start_non_d)}; identical: {non_d == start_non_d}")
print(f"   non-d TEI documents in frus1958-60v05mSupp: {supp}; the others: {others}")
print(f"   d rows with no start row: {d_no_start}")
print(f"   rows matching GLOB 'd[0-9]*' OR a start row: {union:,}")

print("4. Undated rows (guide §4.3, §6.4)")
print("   d rows outside front matter and editorial notes, with date_iso NULL:",
      q("SELECT COUNT(*), SUM(dd.date_iso IS NULL) FROM document_cache dc LEFT JOIN document_dates dd "
        "USING (volume_id, document_id) WHERE dc.is_front_matter = 0 AND dc.is_editorial_note = 0 "
        "AND dc.document_id GLOB 'd[0-9]*'")[0])
print("   §6.4's undated query (every row outside front matter):",
      q("SELECT SUM(dd.date_iso IS NULL), COUNT(*) FROM document_cache dc LEFT JOIN document_dates dd "
        "USING (volume_id, document_id) WHERE dc.is_front_matter = 0")[0])
print("   its NULL rows by (id is d and a digit, is_editorial_note):",
      q("SELECT dc.document_id GLOB 'd[0-9]*', dc.is_editorial_note, COUNT(*) FROM document_cache dc "
        "JOIN document_dates dd USING (volume_id, document_id) WHERE dc.is_front_matter = 0 "
        "AND dd.date_iso IS NULL GROUP BY 1, 2"))

print("5. The TEI files against the installed manifest's sizeBytes")
diff = [v["filename"] for v in man if v["sizeBytes"] != os.path.getsize(os.path.join(VOL, v["filename"]))]
print(f"   {len(man)} volumes in the manifest, {len(diff)} whose file size differs")

print("6. The Tier-2 shards against semantic-shards-manifest.json")
sm = json.load(open(os.path.join(R, "semantic-shards-manifest.json")))
bad = 0
for s in sm["shards"]:
    b = open(os.path.join(C, "SemanticVectors", s["volumeID"] + ".vec"), "rb").read()
    bad += len(b) != s["bytes"] or hashlib.sha256(b).hexdigest() != s["sha256"]
gen = open(os.path.join(C, "SemanticVectors", ".generation")).read().strip()
print(f"   {len(sm['shards'])} shards, {bad} differing; folder .generation equals the manifest's digest: "
      f"{gen == sm['provenanceDigest']}")

print("7. The on-device query encoder against the index's pin")
idx = json.load(open(os.path.join(R, "semantic-vectors-index.json")))
h = hashlib.sha256()
with open(os.path.join(C, "SemanticModel", "embeddinggemma-2-Q8_0.gguf"), "rb") as f:
    for chunk in iter(lambda: f.read(1 << 20), b""):
        h.update(chunk)
print(f"   computed equals provenance.modelFileSHA256: {h.hexdigest() == idx['provenance']['modelFileSHA256']}")
