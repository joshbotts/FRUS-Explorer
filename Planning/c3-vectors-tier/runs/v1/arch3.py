import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ci=json.load(open(R+"central-files-index.json")); sf=json.load(open(R+"series-facts-index.json")); lc=json.load(open(R+"lot-claimants-index.json"))
lots={r["lotNumber"]:r for r in ci["lotFiles"]}; st=sf["statuses"]
claim={r.get("lotNumber"):r for r in lc["lots"]}
print("lot-claimants keys sample:",list(lc["lots"][0].keys()))
for w in ["65D438","62D24","62D418","66D501","64D199","65D330","66D95","66D204","65D212","57D295"]:
    r=lots.get(w); 
    if not r: print(w,"not in lotFiles"); continue
    f=sf["byNaId"].get(r["naId"]); 
    print(w,"|",r["title"],"| NAID",r["naId"],"| entry",r["hmsMlrEntryNumbers"],"| RG",r["recordGroup"],"| creator",sf["headings"][f["c"]] if f and "c" in f else None,"| inclusive",f and (f.get("y0"),f.get("y1")),"coverage",f and (f.get("cy0"),f.get("cy1")),"| access",f and "as" in f and st[f["as"]],"| extent",f and f.get("x"),"| lot-claimants row:", w in claim)
