# Print the curated-library-resolutions.json entries for a repository and a collection regex, and the library-catalog series of a collection by identifier.
# usage: library_curated_lookup.py REPOSITORY_REGEX COLLECTION_REGEX [CATALOG_LIBRARY_CITEDAS CATALOG_COLLECTION_IDENTIFIER]
import json, re, sys
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
cur = json.load(open(R + "curated-library-resolutions.json"))
print("curated keys:", list(cur.keys()), "| note:", str(cur.get("note", ""))[:300])
rr, cr = re.compile(sys.argv[1], re.I), re.compile(sys.argv[2], re.I)
n = 0
for e in cur["entries"]:
    if rr.search(e.get("repository", "")) and cr.search(e.get("collection", "")):
        n += 1
        print(json.dumps(e, ensure_ascii=False)[:900])
print("entries matched:", n)
if len(sys.argv) > 4:
    cat = json.load(open(R + "presidential-library-catalog.json"))
    for l in cat["libraries"]:
        if l["citedAs"] == sys.argv[3]:
            for c in l["collections"]:
                if c.get("identifier") == sys.argv[4]:
                    print("catalog collection:", {k: v for k, v in c.items() if k != "series"})
                    for s in c.get("series") or []:
                        print("   ", json.dumps(s, ensure_ascii=False)[:200])
