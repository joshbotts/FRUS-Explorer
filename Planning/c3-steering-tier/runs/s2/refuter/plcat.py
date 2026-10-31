# Refuter: does presidential-library-catalog.json resolve the cited presidential-library collections to identifiers?
import json
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
pl = json.load(open(RES + "/presidential-library-catalog.json"))
print("generated", pl["generated"], "source", str(pl.get("source"))[:200])
wanted = {
 "Johnson Library": ["National Security File"],
 "Kennedy Library": ["President's Office Files", "National Security Files", "National Security File"],
 "Ford Library": ["Presidential Correspondence with Foreign Leaders", "Presidential Country Files for the Middle East", "National Security Adviser"],
 "Carter Library": ["White House Central Files", "Brzezinski"],
 "Eisenhower Library": ["Herter"],
}
for lib in pl["libraries"]:
    cited = lib.get("citedAs")
    if cited not in wanted: continue
    print(f"\n== {cited}: {len(lib.get('collections', []))} collections (keys {list(lib.keys())})")
    for c in lib.get("collections", []):
        title = c.get("title", "")
        series = c.get("series", [])
        hits = [n for n in wanted[cited] if n.lower() in title.lower()]
        ser_hits = [s for s in series if any(n.lower() in (s.get("title") or "").lower() for n in wanted[cited])]
        if hits or ser_hits:
            print(f"   collection naId={c.get('naId')} identifier={c.get('identifier')} title={title[:110]!r} statedSeriesCount={c.get('statedSeriesCount')} series listed={len(series)}")
            for s in ser_hits[:6]: print(f"      series naId={s.get('naId')} {s.get('inclusiveDates')} {s.get('title')[:100]!r}")
            # Vietnam / Korea / Japan / Middle East within those series
            for s in series:
                t = (s.get("title") or "").lower()
                if any(k in t for k in ("vietnam", "korea", "japan", "middle east", "country file", "countries")):
                    print(f"      (country) series naId={s.get('naId')} {s.get('inclusiveDates')} {s.get('title')[:100]!r}")
