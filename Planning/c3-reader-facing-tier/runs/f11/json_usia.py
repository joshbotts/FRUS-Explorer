import json,re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
sf=json.load(open(R+"series-facts-index.json"))
H=sf["headings"]
usia=[i for i,h in enumerate(H) if re.search(r"Information Agency|International Communication Agency",h)]
print("headings matching USIA/ICA:",[(i,H[i]) for i in usia])
hits=[(n,v) for n,v in sf["byNaId"].items() if v.get("c") in usia or any(p in usia for p in v.get("p",[]))]
print("series with USIA/ICA as creator/predecessor:",len(hits))
for n,v in hits[:15]:
    print(n,{"creator":H[v["c"]] if "c" in v else None,"extent":v.get("x"),"years":(v.get("y0"),v.get("y1")),"access":sf["statuses"][v["as"]] if "as" in v else None})
ca=json.load(open(R+"collection-authority.json")); print("collection-authority keys",list(ca.keys())[:10])
s=json.dumps(ca)
for m in list(re.finditer(r"Information Agency|USIA",s))[:5]: print(s[max(0,m.start()-200):m.start()+200]); print("--")
cf=json.load(open(R+"central-files-index.json"))
print("lotFiles",len(cf["lotFiles"]),cf["lotFiles"][0])
rg=[r for r in cf["lotFiles"] if str(r.get("recordGroup"))=="306" or "306" in json.dumps(r)[:200]]
print("lot rows mentioning 306:",len(rg)); print(rg[:3])
for key in ["72A5121","68A4933","69A3445","66Y0274"]:
    for r in cf["lotFiles"]:
        if r.get("lotNumber")==key: print("FOUND lot",key,r)
