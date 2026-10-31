"""Refuter step 4: every archival identifier in the bottom line's second paragraph, against the bundle and the index."""
import json, sqlite3
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
q = lambda sql, *a: con.execute(sql, a).fetchall()
J = lambda n: json.load(open(RES + "/" + n))

cf = J("central-files-index.json"); sf = J("series-facts-index.json"); plc = J("presidential-library-catalog.json")
cur = J("curated-lot-resolutions.json"); ca = J("collection-authority.json"); vsi = J("volume-sources-index.json"); eci = J("external-citation-index.json")
print("central-files-index schemaVersion", cf.get("schemaVersion"), "generated", cf.get("generated"), "| keys", list(cf.keys()))
print("series-facts-index schemaVersion", sf.get("schemaVersion"), "generated", sf.get("generated"), "| keys", list(sf.keys()))
print("presidential-library-catalog schemaVersion", plc.get("schemaVersion"), "generated", plc.get("generated"), "| keys", list(plc.keys()))

print("\n== LOT FILES in central-files-index.lotFiles ==")
for lot in ["63D351", "66D95", "62D430", "62D1", "54D270", "79F80"]:
    rows = [r for r in cf["lotFiles"] if r.get("lotNumber") == lot]
    print(lot, "->", json.dumps(rows)[:900] if rows else "NOT IN lotFiles")

print("\n== series-facts-index byNaId ==")
L = sf["legend"]["keys"]
def deref(row):
    out = {}
    for k, v in row.items():
        spec = L.get(k)
        if not spec: out[k] = v; continue
        if "into" in spec:
            arr = sf[spec["into"]]
            out[spec["field"]] = [arr[i] for i in v] if spec["kind"] == "indexList" else arr[v]
        else: out[spec["field"]] = v
    return out
for n in ["2839192", "2839191", "2838992", "10481258", "1164", "567979", "572235"]:
    r = sf["byNaId"].get(n); print(n, "->", json.dumps(deref(r))[:700] if r else "not in byNaId")

print("\n== curated-lot-resolutions for 54D270 ==")
for row in cur["lots"]:
    if "54D270" in json.dumps(row): print(json.dumps(row)[:1500])

print("\n== collection-authority rows naming 54D270 ==")
for c in ca["collections"]:
    s = json.dumps(c)
    if "54D270" in s or "54 D 270" in s: print(s[:700])

print("\n== presidential-library-catalog: naId 1164, 567979, 572235, 623746 and 'National Security Affairs' ==")
colls = plc.get("collections") or plc.get("rows") or []
print("catalog collections:", len(colls), "| row keys:", list(colls[0].keys()) if colls else None)
for c in colls:
    s = json.dumps(c)
    if any(str(c.get(k)) in ("1164", "567979", "572235", "623746") for k in c if "naId" in k or k in ("naid", "naId", "id")) or '"1164"' in s or '"567979"' in s or '"572235"' in s or '"623746"' in s or 1164 == c.get("naId") or "National Security Affairs" in s:
        print(s[:500])

print("\n== index: document_sources for the cited Saudi airgram (RG 84 Lot 79F80) and Crowder (837.51/764) ==")
print(q("SELECT repository, record_group, lot_file_norm, series_name, decimal_class, citation_era, raw_text FROM document_sources WHERE volume_id='frus1969-76ve09p2' AND document_id='d122'"))
print(q("SELECT repository, record_group, lot_file_norm, series_name, decimal_class, citation_era, raw_text FROM document_sources WHERE volume_id='frus1922v01' AND document_id='d841'"))

print("\n== index: came-from (M12) and pointed-at (M13) counts over the 3,057 set, for the units paragraph 2 names ==")
con.execute("""CREATE TEMP TABLE h AS SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
 WHERE frus_documents MATCH 'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')""")
print("hit set", q("SELECT COUNT(*) FROM h"))
print("came-from rows:", q("SELECT COUNT(*) FROM h JOIN document_sources s ON s.volume_id=h.volume_id AND s.document_id=h.document_id"))
print("came-from by unit:")
for r in q("""SELECT s.repository, s.record_group, coalesce(s.lot_file_norm, s.series_name), COUNT(*) n FROM h JOIN document_sources s ON s.volume_id=h.volume_id AND s.document_id=h.document_id
 WHERE coalesce(s.lot_file_norm, s.series_name) IN ('54D270','63D351','62D430','66D95','62D1','79F80','National Security File','National Security Files','NSC Files','National Security Affairs','CFPF','Central Files 1964–66','Central Files 1967–69','Central Files 1970–73') OR s.repository='Central Intelligence Agency' GROUP BY 1,2,3 ORDER BY n DESC"""): print("  ", r)
print("came-from citation_era:", q("SELECT s.citation_era, COUNT(*) FROM h JOIN document_sources s ON s.volume_id=h.volume_id AND s.document_id=h.document_id GROUP BY 1 ORDER BY 2 DESC"))
print("pointed-at rows/docs:", q("SELECT COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM h JOIN external_citations e ON e.volume_id=h.volume_id AND e.document_id=h.document_id"))
print("pointed-at by unit:")
for r in q("""SELECT e.repository, coalesce(e.lot_file_norm, e.collection), COUNT(*) n FROM h JOIN external_citations e ON e.volume_id=h.volume_id AND e.document_id=h.document_id
 WHERE coalesce(e.lot_file_norm, e.collection) IN ('66D95','63D351','62D1','62D430','National Security File','National Security Files','NSC Files','National Security Affairs') GROUP BY 1,2 ORDER BY n DESC"""): print("  ", r)
print("pointed-at anchors:", q("SELECT e.anchor, COUNT(*) FROM h JOIN external_citations e ON e.volume_id=h.volume_id AND e.document_id=h.document_id GROUP BY 1 ORDER BY 2 DESC"))
print("pre-1940 series (M15):", end=" ")
ys = [r.get("y0") for r in sf["byNaId"].values() if r.get("y0") is not None]
print(len(ys), "with a start year;", sum(1 for y in ys if y < 1940), "before 1940")
