import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
auth=json.load(open(R+"collection-authority.json"))["collections"]
for c in auth:
    if c["id"] in ("txt:national archives|director's subject file","txt:national archives|usia historical collection","txt:national archives|office of the director"):
        print(json.dumps(c,ensure_ascii=False)[:700])
sf=json.load(open(R+"series-facts-index.json"))
print(sf["legend"]["keys"])
H=sf["headings"]; 
ix=[i for i,h in enumerate(H) if "Information Agency" in h or "USIA" in h]
print("creator headings matching:",[(i,H[i]) for i in ix])
rows=[(nid,r) for nid,r in sf["byNaId"].items() if r.get("c") in ix]
print("series with USIA creator:",len(rows))
for nid,r in rows[:15]:
    print(nid,{k:(sf[{"as":"statuses"}.get(k,"")][v] if k=="as" else v) for k,v in r.items()})
# lot/central files: anything with recordGroup 306
cf=json.load(open(R+"central-files-index.json"))
print("lotFiles rg306:",[ (l['lotNumber'],l['naId'],l['title'][:60]) for l in cf["lotFiles"] if str(l.get("recordGroup"))=="306"][:10])
print("majorCollections" in cf, [k for k in cf.keys()])
