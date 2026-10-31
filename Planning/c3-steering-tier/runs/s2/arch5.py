import json
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
sf=json.load(open(RES+"series-facts-index.json"))
def facts(n):
    r=sf["byNaId"].get(str(n))
    if not r: return None
    out={}
    for k,v in r.items():
        spec=sf["legend"]["keys"].get(k,{})
        if spec.get("kind")=="index": v=sf[spec["into"]][v]
        elif spec.get("kind")=="indexList": v=[sf[spec["into"]][i] for i in v]
        out[spec.get("field",k)]=v
    return out
for n in [302021, 602875, 871815, 872084, 872088, 872091, 1965953]:
    print(n, facts(n))
rows=sf["byNaId"]; tot=len(rows); pre=sum(1 for r in rows.values() if r.get("y0") is not None and r["y0"]<1940); dated=sum(1 for r in rows.values() if r.get("y0") is not None)
print("series-facts rows %d; with inclusive start year %d; starting before 1940: %d of %d" % (tot, dated, pre, dated))
pc=json.load(open(RES+"presidential-library-catalog.json")); print("presidential-library-catalog generated", pc["generated"], "libraries", [l.get("name", l.get("id")) for l in pc["libraries"]][:20] if isinstance(pc["libraries"],list) else list(pc["libraries"].keys())[:20])
