import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json"))["lotFiles"]
sf=json.load(open(R+"series-facts-index.json"));H=sf["headings"];ST=sf["statuses"]
cl=json.load(open(R+"curated-lot-resolutions.json"))
lc=json.load(open(R+"lot-claimants-index.json"))
by={}
for l in cf: by.setdefault(l["lotNumber"],[]).append(l)
for lot in ["61D167","61D385","58D726","65F98"]:
    rows=by.get(lot,[])
    print("LOT",lot,"rows",len(rows))
    for r in rows:
        f=sf["byNaId"].get(r["naId"],{})
        print("   NAID",r["naId"],"RG",r["recordGroup"],r["levelOfDescription"],"|",r["title"][:90],"| entry",r.get("hmsMlrEntryNumbers"),"| match",r["matchType"],"| creator",H[f["c"]] if "c" in f else None,"| inclusive",f.get("y0"),f.get("y1"),"| coverage",f.get("cy0"),f.get("cy1"),"| access",ST[f["as"]] if "as" in f else None,"| use",ST[f["us"]] if "us" in f else None,"| extent",f.get("x"),"| url",r.get("catalogURL"))
    for r in cl["lots"]:
        if r.get("lotNumber")==lot: print("   CURATED",str(r)[:400])
    for r in lc["lots"]:
        if r.get("lotNumber")==lot or r.get("lot")==lot: print("   CLAIMANTS",str(r)[:400])
