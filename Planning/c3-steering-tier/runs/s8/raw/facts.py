# series-facts lookups for chosen NAIDs, and the Central Files rows of central-files-index.json
import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json")); sf=json.load(open(R+"series-facts-index.json"))
def facts(n):
    r=sf["byNaId"].get(n)
    if r is None: return "NOT IN series-facts-index"
    out={}
    for k,v in r.items():
        spec=sf["legend"]["keys"].get(k,{}); into=spec.get("into")
        if into and spec["kind"]=="index": v=sf[into][v]
        elif into and spec["kind"]=="indexList": v=[sf[into][i] for i in v]
        out[spec.get("field",k)]=v
    return out
for n in ["2839192","1965953","1487627","2838992"]:
    print(n, json.dumps(facts(n),ensure_ascii=False)[:700])
nf=cf["numericalFile"]; cs=cf["countrySeries"]
print("numericalFile type",type(nf), (list(nf.keys())[:10] if isinstance(nf,dict) else json.dumps(nf[:3],ensure_ascii=False)[:1500]))
print("countrySeries type",type(cs), (list(cs.keys())[:10] if isinstance(cs,dict) else len(cs)))
print("numericalFile.seriesNaId", nf["seriesNaId"], json.dumps(facts(str(nf["seriesNaId"])),ensure_ascii=False)[:500])
for r in cs: print("CS", json.dumps({k:v for k,v in r.items() if k!='rolls'},ensure_ascii=False)[:400])
