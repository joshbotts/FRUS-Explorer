import json
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
pl = json.load(open(R+"presidential-library-catalog.json"))
for lib in pl["libraries"]:
    name = lib.get("citedAs")
    if name not in ("Kennedy Library","Johnson Library","Carter Library","Nixon Library","Nixon"): continue
    print("==", name, "| collections:", len(lib.get("collections", [])), "| keys:", [k for k in lib if k != "collections"])
    for c in lib.get("collections", []):
        t = c.get("title", "")
        if any(w in t for w in ["National Security", "Recordings", "Brzezinski", "NSC", "Backchannel"]):
            print(f"   {t} | id={c.get('identifier')} naId={c.get('naId')} series={len(c.get('series',[]))} stated={c.get('statedSeriesCount')}")
            for s in c.get("series", [])[:80]:
                if any(w in s.get("title","") for w in ["Backchannel","Countries","Meetings and Memoranda","Staff Material","Brzezinski","Country File","Recordings"]):
                    print(f"       series: {s.get('title')} | naId={s.get('naId')} | {s.get('inclusiveDates')}")
print("\nlibraries citedAs:", [l.get("citedAs") for l in pl["libraries"]])
vs = json.load(open(R+"volume-sources-index.json"))
for rg in ["59","330"]:
    print("RG", rg, "=>", vs["recordGroups"].get(rg))
