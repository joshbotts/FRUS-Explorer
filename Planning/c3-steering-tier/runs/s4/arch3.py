import json,collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
S=json.load(open("work/set.json")); vols=sorted({v for f,v,d in S})
u=json.load(open(R+"collection-usage-index.json")); a=json.load(open(R+"collection-authority.json"))
cf=json.load(open(R+"central-files-index.json")); sf=json.load(open(R+"series-facts-index.json"))
lc=json.load(open(R+"lot-claimants-index.json"))
cat=collections.Counter()
for c in u["volumeCategories"]:
    for n,v in zip(c["n"],c["v"]):
        if u["volumes"][v] in vols: cat[u["categories"][c["k"]]]+=n
print("CATEGORY (notes per citation form, collection's 21 volumes; usage index, came-from channel):",dict(cat.most_common()), "sum",sum(cat.values()))
lots={r["lotNumber"]:r for r in cf["lotFiles"]}
claim={}
print("lot-claimants top keys:",[k for k in lc if k!="lots"], "n lots",len(lc["lots"]), json.dumps(lc["lots"][0])[:300])
want=["55D36","66D193","81D113","85D240","65D330","72D192","80D177","85D366"]
for w in want:
    r=lots.get(w)
    if not r: print(w,"NOT in central-files lotFiles"); continue
    na=r["naId"]; f=sf["byNaId"].get(na)
    out={"lot":w,"title":r["title"][:110],"rg":r["recordGroup"],"naId":na,"matchType":r.get("matchType"),"hmsMlr":r.get("hmsMlrEntryNumbers")}
    if f:
        out.update({"creator":sf["headings"][f["c"]] if "c" in f else None,"extent":f.get("x"),"years":(f.get("y0"),f.get("y1")),"access":sf["statuses"][f["as"]] if "as" in f else None,"restr":[sf["restrictions"][i] for i in f.get("ar",[])]})
    print(json.dumps(out))
