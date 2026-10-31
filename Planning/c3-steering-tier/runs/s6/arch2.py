import json, re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
sf=json.load(open(R+"series-facts-index.json"))
print("legend keys:",json.dumps(sf["legend"])[:1200])
for nid in ["619160","2131131"]:
    r=sf["byNaId"].get(nid); print(nid,r)
    if r:
        print("  status:",sf["statuses"][r["as"]] if "as" in r else None,"| restrictions:",[sf["restrictions"][i] for i in r.get("ar",[])],"| refunit:",sf["referenceUnits"][r["ru"]] if "ru" in r else None,"| extent",r.get("x"),"| years",r.get("y0"),r.get("y1"),"| creator", sf["headings"][r["c"]] if "c" in r else None)
cf=json.load(open(R+"central-files-index.json"))
for r in cf["lotFiles"]:
    if r["lotNumber"] in ("78D443","91D414"): print(json.dumps(r)[:700])
ca=json.load(open(R+"collection-authority.json"))
for c in ca["collections"]:
    if re.search(r"Central Foreign Policy|CFPF",json.dumps(c)): print("AUTH",c["id"],c["name"][:90],c.get("recordGroup"),len(c["volumeIds"])); break
vs=json.load(open(R+"volume-sources-index.json"))
print([ (k,v) for k,v in vs["recordGroups"].items() if k in ("59","84")])
