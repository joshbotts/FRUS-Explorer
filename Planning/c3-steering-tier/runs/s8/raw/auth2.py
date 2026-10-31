# Find authority records for Central Files / CFPF / library series; and usage-index ranking for the set's volumes
import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ca=json.load(open(R+"collection-authority.json"))["collections"]; cu=json.load(open(R+"collection-usage-index.json"))
for r in ca:
    n=r.get("name","")
    if any(k in n for k in ["Central Decimal","Central Foreign Policy","Central Files","President’s Office Files","National Security File","Presidential Country Files","Jidda"]) and not r["id"].startswith("lot:"):
        print("AUTH",json.dumps({k:r.get(k) for k in ["id","name","repository","naId","seriesNaId","recordGroup","entry"] if r.get(k) is not None},ensure_ascii=False)[:300])
print("usage volumes type",type(cu["volumes"]), "collections type",type(cu["collections"]))
v=cu["volumes"]; 
ex = v.get("frus1947v07") if isinstance(v,dict) else None
print("frus1947v07 usage:",json.dumps(ex,ensure_ascii=False)[:800])
print("collections sample:",json.dumps(cu["collections"][:2] if isinstance(cu["collections"],list) else list(cu["collections"].items())[:2],ensure_ascii=False)[:800])
print("collectionIds sample", cu["collectionIds"][:5] if isinstance(cu["collectionIds"],list) else "")
