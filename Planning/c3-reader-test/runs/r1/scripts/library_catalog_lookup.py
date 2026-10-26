# Search presidential-library-catalog.json (bundled) for collections and series whose titles match a regex; print library, collection (identifier, NAID) and series (NAID, dates).
# usage: library_catalog_lookup.py LIBRARY_CITEDAS_REGEX TITLE_REGEX
import json, re, sys
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
d = json.load(open(R + "presidential-library-catalog.json"))
lr, tr = re.compile(sys.argv[1], re.I), re.compile(sys.argv[2], re.I)
print("libraries:", [l["citedAs"] for l in d["libraries"]])
for l in d["libraries"]:
    if not lr.search(l["citedAs"]): continue
    for ci, c in enumerate(l["collections"]):
        ct = c.get("title", "")
        hit = bool(tr.search(ct))
        if hit:
            print("%s | collection %d | %s | id %s | naId %s | series listed %s of stated %s" % (l["citedAs"], ci, ct, c.get("identifier"), c.get("naId"), len(c.get("series") or []), c.get("statedSeriesCount")))
        for s in (c.get("series") or []):
            st = s.get("title", "") if isinstance(s, dict) else str(s)
            if tr.search(st):
                print("   %s | coll %d (%s, naId %s) | series: %s | naId %s | %s" % (l["citedAs"], ci, ct[:60], c.get("naId"), st[:110], s.get("naId"), s.get("inclusiveDates")))
