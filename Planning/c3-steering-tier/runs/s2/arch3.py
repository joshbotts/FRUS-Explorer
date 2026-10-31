import json
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
for f in ["lot-claimants-index.json","curated-lot-resolutions.json"]:
    j=json.load(open(RES+f)); print(f, list(j.keys()), j.get("generated"))
    for r in j["lots"]:
        s=json.dumps(r)
        if any(w in s for w in ["54D270","62D181","65F115","79F80","54 D 270","62 D 181","65 F 115","79F80"]): print("  ", s[:600])
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
print("series-facts generated", sf["generated"])
print("1965953:", facts(1965953))
cu=json.load(open(RES+"collection-usage-index.json"))
print("collection-usage generated", cu["generated"], "schemaVersion", cu["schemaVersion"])
print("collections[0]:", json.dumps(cu["collections"][0])[:500])
print("volumes type", type(cu["volumes"]), json.dumps(cu["volumes"])[:600] if isinstance(cu["volumes"],list) else json.dumps(list(cu["volumes"].items())[:1])[:600])
print("coverage:", json.dumps(cu["coverage"])[:500])
print("collectionIds[:3]", cu["collectionIds"][:3], "categories", cu["categories"][:10] if isinstance(cu["categories"],list) else cu["categories"])
