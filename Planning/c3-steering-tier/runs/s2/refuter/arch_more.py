import json, sqlite3, re
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
pl = json.load(open(RES + "/presidential-library-catalog.json"))
print("== Ford Library: collections whose title or series mention 'National Security Adviser' / 'Country Files' + Middle East")
for lib in pl["libraries"]:
    if lib.get("citedAs") != "Ford Library": continue
    for c in lib["collections"]:
        t = c.get("title", "")
        ser = c.get("series", [])
        if "national security adviser" in t.lower() or "nsa" in t.lower().split() or any("country files" in (s.get("title") or "").lower() and "middle east" in (s.get("title") or "").lower() for s in ser):
            print(f"   naId={c.get('naId')} id={c.get('identifier')} {t[:120]!r} series={len(ser)}")
            for s in ser:
                st = (s.get("title") or "")
                if "middle east" in st.lower() or "country" in st.lower(): print(f"      series naId={s.get('naId')} {s.get('inclusiveDates')} {st[:110]!r}")
print("\n== collection-authority.json: lot:65F115, lot:79F80 full records; Central Decimal records")
ca = json.load(open(RES + "/collection-authority.json"))["collections"]
for r in ca:
    if r.get("id") in ("lot:65F115", "lot:79F80", "lot:62D26", "lot:62D181", "lot:54D270"):
        print("  ", r.get("id"), "keys:", sorted(r.keys()), "naId:", r.get("naId"), "catalogURL:", r.get("catalogURL"), "recordGroup:", r.get("recordGroup"))
cd = [r for r in ca if "central decimal" in (r.get("name") or "").lower() or any("central decimal" in a.lower() for a in r.get("aliases", []))]
print("   records naming 'Central Decimal':", len(cd))
for r in cd[:12]: print("     ", r.get("id"), "| name:", (r.get("name") or "")[:80], "| naId:", r.get("naId"), "| catalogURL:", r.get("catalogURL"), "| volumes:", len(r.get("volumeIds", [])))
print("\n== accession-series-index.json")
ac = json.load(open(RES + "/accession-series-index.json"))
print("  top keys:", list(ac.keys()) if isinstance(ac, dict) else type(ac))
s = json.dumps(ac)
for needle in ("65F115", "65 F 115", "79F80", "Central Decimal", "302021"):
    i = s.find(needle); print(f"  {needle!r} at {i}: …{s[max(0,i-300):i+300]}…" if i >= 0 else f"  {needle!r}: absent")
print("\n== lot-claimants-index.json")
lc = json.load(open(RES + "/lot-claimants-index.json"))
print("  keys:", list(lc.keys()), "note:", str(lc.get("note"))[:300])
lots = lc["lots"]
print("  lots type:", type(lots).__name__, "count:", len(lots))
for k in ("65F115", "79F80", "62D26", "62D181", "54D270"):
    v = lots.get(k) if isinstance(lots, dict) else [l for l in lots if l.get("lotNumber") == k]
    print("  ", k, "->", json.dumps(v)[:400] if v else None)
print("\n== documents under frus1958-60v01's corruption chapter")
sj = json.loads(con.execute("SELECT structure_json FROM volume_structures WHERE volume_id='frus1958-60v01'").fetchone()[0])
def walk(node, under, out):
    title = node.get("title") or ""
    hit = under or ("CAN LAO PARTY, CORRUPTION" in title.upper())
    if hit: out.extend(node.get("documentIds", []))
    for sub in node.get("subsections", []) or node.get("sections", []): walk(sub, hit, out)
out = []
for sec in sj["sections"]: walk(sec, False, out)
print("   documents under the chapter:", len(out), "first/last:", out[:3], out[-3:], "; d131 in it:", "d131" in out, "; d135 in it:", "d135" in out)
print("\n== d161: are the names withheld as 'not declassified'?")
b = con.execute("SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve09p2' AND document_id='d161'").fetchone()[0]
print("   occurrences of 'not declassified':", len(re.findall(r"not declassified", b, re.I)))
for m in list(re.finditer(r".{0,120}not declassified.{0,80}", b, re.I))[:3]: print("   …" + m.group(0).replace("\n", " ") + "…")
print("\n== d395: 'first on its list of priorities'? ")
b = con.execute("SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v05' AND document_id='d395'").fetchone()[0]
for m in list(re.finditer(r".{0,200}anti-corruption.{0,200}", b, re.I))[:3]: print("   …" + m.group(0).replace("\n", " ") + "…")
print("\n== d204: 'Within nine days' (d202 1961-03-06, d204 1961-03-15) and 'does not use any of the words'")
for v, d in (("frus1961-63v22", "d202"), ("frus1961-63v22", "d204")):
    print("  ", v, d, con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?", (v, d)).fetchone())
print("\n== d248: 'second most significant disincentive'")
b = con.execute("SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v03' AND document_id='d248'").fetchone()[0]
for m in list(re.finditer(r".{0,200}second most.{0,200}", b, re.I))[:2]: print("   …" + m.group(0).replace("\n", " ") + "…")
