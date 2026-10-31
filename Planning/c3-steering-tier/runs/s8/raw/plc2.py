# Match the set's library series by title in presidential-library-catalog.json
import json,re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
p=json.load(open(R+"presidential-library-catalog.json"))
want={"Kennedy Library":["President's Office Files","President’s Office Files","National Security Files"],
      "Johnson Library":["National Security File","Meeting Notes","Tom Johnson"],
      "Ford Library":["National Security Adviser","Presidential Country Files","Presidential Correspondence"],
      "Carter Library":["National Security Affairs","Brzezinski"]}
for lib in p["libraries"]:
    if lib["citedAs"] not in want: continue
    print("LIB",lib["citedAs"],"collections",len(lib["collections"]))
    for c in lib["collections"]:
        hay=[c["title"]]+[s["title"] for s in c.get("series",[])]
        for w in want[lib["citedAs"]]:
            if any(w.lower() in h.lower() for h in hay):
                ser=[s for s in c.get("series",[]) if w.lower() in s["title"].lower()] or c.get("series",[])[:2]
                print("  ",c.get("identifier"),c["naId"],c["title"],"|",[(s["naId"],s["title"],s.get("inclusiveDates")) for s in ser[:3]])
                break
