import json, sqlite3, collections, re
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s4/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
coll = json.load(open(RUN + "collection.fruscollection"))
cited = [(e["volumeId"], e["documentId"]) for e in coll["entries"] if e["kind"] == "document"]
vols = sorted({v for v, d in cited})
print("collection volumes:", len(vols), vols)

# ---- document_sources tally for the 35 (read raw_text) ----
print("\n== document_sources rows ==")
tally = collections.Counter()
for v, d in cited:
    r = con.execute("select repository,record_group,lot_file,series_name,citation_era,raw_text from document_sources where volume_id=? and document_id=?", (v, d)).fetchone()
    raw = (r[5] if r else "") or ""
    print(f"{v}/{d} | era={r[4] if r else None} repo={r[0] if r else None} rg={r[1] if r else None} lot={r[2] if r else None} series={r[3] if r else None} | {re.sub(chr(10),' ',raw)[:140]}")
    if r is None: tally["no row"] += 1
    elif r[4] == "decimal": tally["RG59 decimal"] += 1
    elif r[4] == "cfpf": tally["RG59 central foreign policy file"] += 1
    elif r[4] == "subject_numeric": tally["RG59 subject-numeric"] += 1
    elif "INR" in raw: tally["INR-NIE"] += 1
    elif "Kissinger, Entry 5403" in raw or "Records of Secretary of State Henry Kissinger" in raw: tally["RG59 Kissinger records"] += 1
    elif "Jidda Embassy" in raw and "RG 84" in raw and "Ford Library" not in raw: tally["RG84 Jidda"] += 1
    elif "Library" in raw and ("Johnson" in raw or "Kennedy" in raw or "Carter" in raw or "Ford" in raw):
        tally["presidential library: " + re.search(r"(Johnson|Kennedy|Carter|Ford) Library", raw).group(1)] += 1
    elif "Library of Congress" in raw: tally["LoC Kissinger Papers"] += 1
    elif "Center for Military History" in raw: tally["CMH"] += 1
    else: tally["other: " + raw[:40]] += 1
print("TALLY:", dict(tally), "sum", sum(tally.values()))

# ---- central-files-index: lots, numerical file, country series ----
cf = json.load(open(RES + "central-files-index.json"))
print("\n== central-files-index keys:", list(cf.keys()))
lots = {r["lotNumber"]: r for r in cf["lotFiles"]}
sf = json.load(open(RES + "series-facts-index.json"))
print("series-facts keys:", [k for k in sf if k != "byNaId"], "byNaId rows:", len(sf["byNaId"]))
def facts(naid):
    f = sf["byNaId"].get(str(naid))
    if not f: return None
    return {"creator": sf["headings"][f["c"]] if "c" in f else None, "extent": f.get("x"), "years": (f.get("y0"), f.get("y1")),
            "access": sf["statuses"][f["as"]] if "as" in f else None, "restr": [sf["restrictions"][i] for i in f.get("ar", [])], "title": f.get("t")}
for lot in ["91D414", "79F80", "81D113", "85D240", "65D330", "80D177"]:
    r = lots.get(lot)
    if not r: print(lot, "NOT in central-files lotFiles"); continue
    print(lot, "| title:", r.get("title")[:80], "| rg", r.get("recordGroup"), "| naId", r.get("naId"), "| entry", r.get("hmsMlrEntryNumbers"), "| facts:", facts(r.get("naId")))
print("numericalFile:", json.dumps(cf.get("numericalFile"))[:400])
print("numerical seriesNaId facts:", facts(cf.get("numericalFile", {}).get("seriesNaId")))
cs = cf.get("countrySeries")
print("countrySeries type:", type(cs).__name__, "len", len(cs) if cs else None)
def find_hawaii(obj, path="countrySeries"):
    if isinstance(obj, dict):
        s = json.dumps(obj)
        if "Hawaii" in s and ("177380751" in s or "189267012" in s) and len(s) < 3000:
            print("  HAWAII @", path, ":", s[:1200]); return
        for k, v in obj.items(): find_hawaii(v, path + "." + k)
    elif isinstance(obj, list):
        for i, v in enumerate(obj): find_hawaii(v, path + f"[{i}]")
find_hawaii(cs)
# ---- series facts: 11 of 698 before 1940 ----
n = len(sf["byNaId"]); early = sum(1 for f in sf["byNaId"].values() if f.get("y0") is not None and f["y0"] < 1940)
print("series-facts rows:", n, "with y0 < 1940:", early, "ratio 1 in %.1f" % (n / early if early else 0))

# ---- presidential-library-catalog ----
pl = json.load(open(RES + "presidential-library-catalog.json"))
print("\n== presidential-library-catalog keys:", [k for k in pl if not isinstance(pl[k], list)], {k: len(v) for k, v in pl.items() if isinstance(v, list)})
s = json.dumps(pl)
for naid in ["567979", "1164", "560131"]:
    i = s.find(f'"{naid}"')
    print(naid, "found" if i >= 0 else "NOT FOUND", "|", s[max(0, i - 250):i + 300].replace("\n", " ") if i >= 0 else "")
print("catalog mentions 'access':", "access" in s.lower())

# ---- external-citation-index over the 20 volumes ----
e = json.load(open(RES + "external-citation-index.json"))
a = json.load(open(RES + "collection-authority.json"))
auth = {c["id"]: c for c in a["collections"]}
ev = {v: i for i, v in enumerate(e["volumes"])}
absent = [v for v in vols if v not in ev]
print("\n== external-citation-index: volumes list size", len(e["volumes"]), "first:", e["volumes"][0], "| absent collection volumes:", absent, "present:", 20 - len(absent))
point = collections.Counter()
for c in e["targets"]:
    for n, vi in zip(c["n"], c["v"]):
        if e["volumes"][vi] in vols: point[e["targetIds"][c["k"]]] += n
print("targets:", len(point), "refs:", sum(point.values()))
for i, n in point.most_common(12):
    x = auth.get(i); print(" ", n, i, (x["name"][:70] + " | " + x["repository"]) if x else "?")
for lot in ["81D113", "85D240", "65D330", "80D177"]:
    print(" lot", lot, "refs:", [(i, n) for i, n in point.items() if lot in i])
print("volume list begins:", sorted(e["volumes"])[:3], "| earliest by series year:", min(e["volumes"], key=lambda v: re.search(r"\d{4}", v).group()))

# ---- document_sources: what the index resolves for the 16 central files? (decimal classes) ----
print("\n== decimal classes among the cited rows ==")
for v, d in cited:
    r = con.execute("select decimal_class, citation_era from document_sources where volume_id=? and document_id=?", (v, d)).fetchone()
    if r and r[1] in ("decimal", "cfpf", "subject_numeric"): print(f"  {v}/{d} class={r[0]} era={r[1]}")
