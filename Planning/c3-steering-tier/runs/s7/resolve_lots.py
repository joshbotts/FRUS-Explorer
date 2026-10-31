import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json")); sf=json.load(open(R+"series-facts-index.json")); lc=json.load(open(R+"lot-claimants-index.json"))
leg=sf["legend"]["keys"]
def facts(naid):
    r=sf["byNaId"].get(str(naid))
    if not r: return "no series-facts row"
    out={}
    for k,v in r.items():
        L=leg.get(k,{}); f=L.get("field",k); into=L.get("into")
        if into:
            voc=sf[into]; out[f]=[voc[i] for i in v] if isinstance(v,list) else voc[v]
        else: out[f]=v
    return out
lots={r["lotNumber"]:r for r in cf["lotFiles"]}
claim={r.get("lotNumber",r.get("lot")):r for r in lc["lots"]}
for lot in ["54D270","63D351","59D95","62D430","66D95","62D1","62D181","67D548"]:
    r=lots.get(lot)
    print("==",lot, "central-files:", json.dumps({k:r[k] for k in r if k in("title","recordGroup","naId","hmsMlrEntryNumbers","matchType","levelOfDescription")}) if r else "ABSENT")
    if r: print("   facts:",json.dumps(facts(r["naId"])))
    if lot in claim: print("   claimants:",json.dumps(claim[lot])[:600])
dl=json.load(open(R+"decimal-class-labels.json"))
print(json.dumps(dl["coverage"])[:600])
s=dl["schedules"]; print([ (x.get("id"),list(x.keys())) for x in s])
