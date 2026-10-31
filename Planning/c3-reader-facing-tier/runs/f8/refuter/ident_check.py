import json, re
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
def load(n): return json.load(open(R + n))
cf = load("central-files-index.json"); sf = load("series-facts-index.json"); ca = load("collection-authority.json")
pl = load("presidential-library-catalog.json"); acc = load("accession-series-index.json"); ec = load("external-citation-index.json")
vs = load("volume-sources-index.json")

print("== central-files lotFiles for the lots named ==")
for row in cf["lotFiles"]:
    if row.get("lotNumber") in ("63D351", "62D430", "62D333", "59D260", "60D322", "62D255", "63D224", "66D95"):
        print(json.dumps(row))
print("decimal/subject-numeric structures in central-files-index:", [k for k in cf.keys()])
print("numericalFile keys:", list(cf["numericalFile"].keys()) if isinstance(cf["numericalFile"], dict) else type(cf["numericalFile"]))
print("countrySeries categories:", [x.get("category") for x in cf["countrySeries"]])

print("\n== series-facts byNaId for the NAIDs named ==")
st = sf["statuses"]; heads = sf["headings"]
for n in ["2839192", "2839191", "2124692", "1257679", "591194", "12005682", "567979", "566962", "591256", "591289", "5552237", "5585931"]:
    row = sf["byNaId"].get(n)
    if row:
        print(n, json.dumps(row), "| access", st[row["as"]] if "as" in row else None, "| creator", heads[row["c"]] if "c" in row else None)
    else:
        print(n, "NOT IN series-facts")
print("series-facts byNaId count:", len(sf["byNaId"]))
pre1940 = [n for n, r in sf["byNaId"].items() if r.get("y0") and r["y0"] < 1940]
print("series with inclusive start < 1940:", len(pre1940), "of", len(sf["byNaId"]))
pre1940c = [n for n, r in sf["byNaId"].items() if min([y for y in (r.get("y0"), r.get("cy0")) if y] or [9999]) < 1940]
print("series with inclusive or coverage start < 1940:", len(pre1940c))

print("\n== collection-authority records for lots 60D322, 62D255, 63D224, 59D260, 63D351, 62D430, 62D333 ==")
for rec in ca["collections"]:
    if rec.get("lotFileNorm") in ("60D322", "62D255", "63D224", "59D260", "63D351", "62D430", "62D333"):
        print(json.dumps({k: rec[k] for k in rec if k != "volumeIds"})[:400])

print("\n== collection-authority records naming entry A1-42 / A1 42 / P-207 / P 207 / P-104 / UD-UP 7 / 84-0003 ==")
pat = re.compile(r'A1[-–\s]?42\b|P[-–\s]?207\b|P[-–\s]?104\b|UD[-–\s]?UP[-–\s]?7\b|84[-–]0003|Director.s Subject Files|Office of Policy and Plans', re.I)
for rec in ca["collections"]:
    s = json.dumps(rec, ensure_ascii=False)
    if pat.search(s):
        print(json.dumps({k: rec[k] for k in rec if k != "volumeIds"}, ensure_ascii=False)[:300])

print("\n== accession-series byAccession 306/840003 ==")
for k in acc["byAccession"]:
    if "840003" in k or "84-0003" in k or "84A0003" in k:
        print(k, json.dumps(acc["byAccession"][k]))

print("\n== presidential-library-catalog: Johnson NSF / Confidential Files / Carter Plains ==")
for lib in pl["libraries"]:
    for col in lib["collections"]:
        if col.get("naId") in (567979, 566962, 591256) or str(col.get("naId")) in ("567979", "566962", "591256"):
            print(lib["citedAs"], "|", col["title"], "| collection naId", col["naId"], "| access keys:", [k for k in col.keys()])
            for s in col["series"]:
                if str(s.get("naId")) in ("591194", "12005682", "591289", "591273", "591286"):
                    print("   series", s)
# any access field anywhere in the presidential catalog?
keys = set()
for lib in pl["libraries"]:
    for col in lib["collections"]:
        keys.update(col.keys())
        for s in col["series"]:
            keys.update("series." + k for k in s.keys())
print("presidential catalog keys:", sorted(keys))

print("\n== external-citation-index: entries for 511.00, lot 62D333, 59D260, 63D224, 60D322, 62D255 ==")
print("ec keys", list(ec.keys()))
s = json.dumps(ec)
for needle in ["62D333", "59D260", "63D224", "60D322", "62D255", "2124692", "1257679"]:
    print(needle, "present in external-citation-index:", needle in s)

print("\n== volume-sources-index: entries for the cited volumes mentioning RG 306 entries ==")
print("vs keys", list(vs.keys())[:10])
s2 = json.dumps(vs, ensure_ascii=False)
for needle in ["A1-42", "A1–42", "P-207", "P–207", "P-104", "P–104", "UD-UP 7", "UD–UP 7", "306-84-0003", "306–84–0003", "RG 305", "A1 1586E", "A1 1586C", "A1 1462", "UD-WW 151"]:
    print(repr(needle), "in volume-sources-index:", needle in s2)
