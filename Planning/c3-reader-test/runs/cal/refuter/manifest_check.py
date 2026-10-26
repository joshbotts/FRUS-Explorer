import json, sys
m = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
print("top-level keys:", list(m.keys())[:20] if isinstance(m, dict) else type(m))
vols = m["volumes"] if isinstance(m, dict) and "volumes" in m else m
print("volume count:", len(vols))
sample = vols[0] if isinstance(vols, list) else next(iter(vols.values()))
print("sample keys:", list(sample.keys()))
nine = ["frus1961-63v10","frus1961-63v11","frus1961-63v12","frus1961-63v10-12mSupp","frus1964-68v32","frus1969-76ve10","frus1969-76ve11p1","frus1977-80v23","frus1977-80v24"]
byid = {v.get("id") or v.get("volumeId") or v.get("volume_id"): v for v in (vols if isinstance(vols, list) else vols.values())}
print("\n== the nine volumes ==")
for vid in nine:
    v = byid.get(vid)
    if not v: print(vid, "NOT IN MANIFEST"); continue
    print(vid, "|", v.get("title"), "|", {k: v.get(k) for k in v if k in ("publishedYear","published","publicationYear","dateRange","coverageStart","coverageEnd","documentCount","subseries","administration","startYear","endYear")})
print("\n== 1981-1988 subseries ==")
for vid, v in sorted(byid.items()):
    s = json.dumps(v)
    if vid.startswith("frus1981-88"):
        print(vid, "|", v.get("title"))
print("count frus1981-88*:", sum(1 for vid in byid if vid.startswith("frus1981-88")))
# any subseries field?
subs = {}
for vid, v in byid.items():
    for k in ("subseries","subseriesTitle","series"):
        if k in v: subs.setdefault(k, set()).add(str(v[k]))
for k, s in subs.items(): print(k, "distinct values:", len(s))
