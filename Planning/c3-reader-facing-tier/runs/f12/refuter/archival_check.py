# Refuter's check of the bottom line's archival identifiers against the bundled artifacts.
import json, re
B = "/Applications/FRUS Explorer.app/Contents/Resources/"
def load(n): return json.load(open(B + n))

def walk(node, path, needles, hits, maxhits=400):
    if len(hits) >= maxhits: return
    if isinstance(node, dict):
        s = json.dumps(node, ensure_ascii=False)
        if len(s) < 1500 and any(n.lower() in s.lower() for n in needles):
            hits.append((path, s[:700])); return
        for k, v in node.items(): walk(v, path + "/" + str(k), needles, hits, maxhits)
    elif isinstance(node, list):
        for i, v in enumerate(node): walk(v, path + f"[{i}]", needles, hits, maxhits)
    elif isinstance(node, str):
        if any(n.lower() in node.lower() for n in needles): hits.append((path, node[:300]))

def shape(j, name):
    print(f"\n##### {name}: {type(j).__name__}")
    if isinstance(j, dict):
        for k, v in j.items():
            if isinstance(v, (list, dict)): print(f"   {k}: {type(v).__name__} len {len(v)}; sample {json.dumps(v[0] if isinstance(v, list) and v else (list(v.items())[0] if v else None), ensure_ascii=False)[:300]}")
            else: print(f"   {k}: {str(v)[:150]}")

# 1. collection-authority.json: USIA series by name, lots 61D385 and 58D726, library collections
ca = load("collection-authority.json"); shape(ca, "collection-authority.json")
cols = ca["collections"]
def find_auth(pred, label):
    rows = [c for c in cols if pred(json.dumps(c, ensure_ascii=False))]
    print(f"\n-- authority rows for {label}: {len(rows)}")
    for c in rows[:12]:
        print("   ", json.dumps({k: c.get(k) for k in ("id","name","recordGroup","repository","naId","aliases","volumeIds") if k in c}, ensure_ascii=False)[:600])
    return rows
find_auth(lambda s: re.search(r"Director.s Subject Files", s) is not None, "Director's Subject Files")
find_auth(lambda s: "Office of Policy and Plans" in s, "Office of Policy and Plans")
find_auth(lambda s: "Office of the Director" in s and ("306" in s or "USIA" in s or "Information" in s), "Office of the Director (RG 306)")
find_auth(lambda s: "Executive Secretariat" in s and "306" in s, "Executive Secretariat (RG 306)")
find_auth(lambda s: re.search(r"A1[–-]42|P[–-]104|P[–-]207|UD WW 257|UD WW 193|UD[–-]UP 7", s) is not None, "RG 306 entry numbers A1-42/P-104/P-207/UD WW 257/UD WW 193/UD-UP 7")
find_auth(lambda s: "61D385" in s or "61 D 385" in s, "lot 61 D 385")
find_auth(lambda s: "58D726" in s or "58 D 726" in s, "lot 58 D 726")
find_auth(lambda s: "Marks Papers" in s, "Marks Papers")
find_auth(lambda s: "Kissinger Office Files" in s, "Kissinger Office Files")
find_auth(lambda s: "Robert F. Kennedy" in s or "Robert F.  Kennedy" in s, "Robert F. Kennedy papers")
usia = [c for c in cols if c.get("recordGroup") in ("306", 306) or "Information Agency" in json.dumps(c)]
print(f"\n-- authority rows with recordGroup 306 or naming the Information Agency: {len(usia)}; with naId: {sum(1 for c in usia if c.get('naId'))}")
print("-- authority rows in all:", len(cols), "; with naId:", sum(1 for c in cols if c.get("naId")))
print("-- sample of keys across rows:", sorted({k for c in cols for k in c})[:40])

# 2. central-files-index.json lotFiles
cf = load("central-files-index.json"); shape(cf, "central-files-index.json")
for lot in ("61D385", "58D726"):
    rows = [r for r in cf.get("lotFiles", []) if r.get("lotNumber") == lot or lot in json.dumps(r)]
    print(f"\n-- central-files lotFiles rows for {lot}: {len(rows)}")
    for r in rows[:5]: print("   ", json.dumps(r, ensure_ascii=False)[:900])
# any structure in central-files for decimal classes?
hits = []; walk(cf, "", ["511.90", "511.51G", "790.5", "792.5", "611.98"], hits, 20)
print(f"\n-- central-files nodes naming the five decimal files: {len(hits)}")
for h in hits[:10]: print("   ", h[0], h[1][:300])

# 3. series-facts-index.json byNaId 2544398
sf = load("series-facts-index.json"); shape(sf, "series-facts-index.json")
def facts(n):
    r = sf["byNaId"].get(n)
    if not r: return None
    out = {}
    for k, v in r.items():
        lg = sf["legend"]["keys"].get(k, {}); f = lg.get("field", k); into = lg.get("into")
        if into and isinstance(v, int): v = sf[into][v]
        elif into and isinstance(v, list): v = [sf[into][i] if isinstance(i, int) else i for i in v]
        out[f] = v
    return out
print("\n-- series-facts byNaId 2544398 (decoded):", json.dumps(facts("2544398"), ensure_ascii=False))
print("-- raw row:", json.dumps(sf["byNaId"].get("2544398")))

# 4. presidential-library-catalog.json
pl = load("presidential-library-catalog.json"); shape(pl, "presidential-library-catalog.json")
for needle in ["Marks Papers", "Kissinger Office Files", "National Security File", "Robert F. Kennedy", "NSC Files", "Country File, Indonesia", "Country File, Thailand"]:
    hits = []; walk(pl, "", [needle], hits, 6)
    print(f"\n-- presidential-library-catalog nodes naming '{needle}': {len(hits)} (first 4)")
    for h in hits[:4]: print("   ", h[0], h[1][:400])

# 5. external-citation-index.json
ec = load("external-citation-index.json"); shape(ec, "external-citation-index.json")
for needle in ["61D385", "61 D 385", "58D726", "58 D 726", "Kissinger Office Files", "Marks Papers"]:
    hits = []; walk(ec, "", [needle], hits, 6)
    print(f"\n-- external-citation-index nodes naming '{needle}': {len(hits)} (first 3)")
    for h in hits[:3]: print("   ", h[0], h[1][:400])

# 6. volume-sources-index.json for the USIA volumes
vs = load("volume-sources-index.json"); shape(vs, "volume-sources-index.json")
for needle in ["A1–42", "A1-42", "P–104", "P-104", "P–207", "UD WW 257", "UD WW 193", "UD–UP 7", "RG 305", "Director’s Subject Files", "Director's Subject Files"]:
    hits = []; walk(vs, "", [needle], hits, 6)
    print(f"\n-- volume-sources-index nodes naming '{needle}': {len(hits)} (first 3)")
    for h in hits[:3]: print("   ", h[0], h[1][:400])

# 7. decimal-class-labels.json glosses
dl = load("decimal-class-labels.json"); shape(dl, "decimal-class-labels.json")
cov = dl["coverage"]; print("\n-- glossableYears:", json.dumps(cov.get("glossableYears")))
def sched_for(y):
    for g in cov["glossableYears"]:
        if g["startYear"] <= y <= g["endYear"]: return g["scheduleId"]
for key, year in [("511.90", 1950), ("511.51G", 1952), ("790.5", 1953), ("792.5", 1953), ("611.98", 1962)]:
    sid = sched_for(year); s = next(x for x in dl["schedules"] if (x.get("id") or x.get("scheduleId")) == sid)
    cls = key[0]; cc = key[1:3]; sub = key.split(".")[1] if "." in key else ""
    countries = s.get("countries") or {}
    country = countries.get(cc) if isinstance(countries, dict) else None
    alt = (s.get("countryAlternates") or {}) if isinstance(s.get("countryAlternates"), dict) else {}
    alt_hit = {k: v for k, v in alt.items() if k.upper().startswith(cc.upper())} if alt else {}
    print(f"\n-- {key} ({year}) schedule {sid}: class {cls} = {s['classes'].get(cls)!r}; country {cc} = {country!r}; sub .{sub}: subjects has {len(s.get('subjects') or {})} keys; countryAlternates starting {cc}: {json.dumps(alt_hit, ensure_ascii=False)[:300]}")
    if key == "511.51G":
        print("   countries['51G'] =", countries.get("51G"), "| countryAlternates['51G'] =", alt.get("51G"))
    print("   schedule keys:", list(s.keys()))
