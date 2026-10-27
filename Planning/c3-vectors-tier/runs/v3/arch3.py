import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json"))
sf=json.load(open(R+"series-facts-index.json"))
lc=json.load(open(R+"lot-claimants-index.json"))
cl=json.load(open(R+"curated-lot-resolutions.json"))
print("lot-claimants keys",list(lc.keys())); print("curated keys",list(cl.keys()))
print("lotFiles row keys",list(cf["lotFiles"][0].keys()))
print("sf legend keys", {k:v for k,v in sf["legend"]["keys"].items()})
lots=["65D438","74D272","66D501","62D24","62D418","70D149","66D95","66D204","64D199","73D191","61D411","65D330","67D548","66D65","65D212","72D192","77D163"]
by={}
for r in cf["lotFiles"]: by.setdefault(r["lotNumber"],[]).append(r)
def facts(naid):
    f=sf["byNaId"].get(str(naid))
    if not f: return None
    out={}
    for k,v in f.items():
        spec=sf["legend"]["keys"].get(k,{})
        into=spec.get("into")
        if into and into in sf:
            if isinstance(v,list): v=[sf[into][i] for i in v]
            else: v=sf[into][v]
        out[spec.get("field",k)]=v
    return out
for l in lots:
    rows=by.get(l,[])
    print("LOT",l,len(rows),"row(s)")
    for r in rows[:3]:
        print("   ",{k:r.get(k) for k in ("recordGroup","naId","title","hmsMlrEntryNumbers","matchType","levelOfDescription")})
        print("   facts:",facts(r["naId"]))
for r in lc["lots"][:2]: print("claimant sample",r)
