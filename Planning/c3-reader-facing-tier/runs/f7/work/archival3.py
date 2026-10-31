import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json"))["lotFiles"]
cl=json.load(open(R+"curated-lot-resolutions.json"))
print("curated keys",list(cl.keys()), type(cl["lots"]), len(cl["lots"]), str(cl["lots"][0])[:300])
lc=json.load(open(R+"lot-claimants-index.json")); print("claimants keys",list(lc.keys()))
sf=json.load(open(R+"series-facts-index.json"));H=sf["headings"];ST=sf["statuses"]
by={}
for l in cf: by.setdefault(l["lotNumber"],[]).append(l)
cur={}
for l in cl["lots"]: cur.setdefault(l.get("lotNumber") or l.get("lot") or l.get("lotFileNorm"),[]).append(l)
for lot in ["84D204","78D295","78D184","79D63","81D113","66D95","63D351","55D128","53D413","54D423","60D627"]:
    rows=by.get(lot,[])
    print("LOT",lot,"central-files rows:",len(rows),"curated:",len(cur.get(lot,[])))
    for r in rows[:3]:
        f=sf["byNaId"].get(r["naId"],{})
        print("   NAID",r["naId"],"RG",r["recordGroup"],r["levelOfDescription"],"|",r["title"][:80],"| entry",r.get("hmsMlrEntryNumbers"),"| match",r["matchType"],"| creator",H[f["c"]] if "c" in f else None,"| span",f.get("y0"),f.get("y1"),"| access",ST[f["as"]] if "as" in f else None,"| extent",f.get("x"))
    for r in cur.get(lot,[])[:2]: print("   CURATED",str(r)[:300])
