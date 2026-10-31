import json, re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
sf=json.load(open(R+"series-facts-index.json")); cf=json.load(open(R+"central-files-index.json")); pl=json.load(open(R+"presidential-library-catalog.json"))
def facts(nid):
    r=sf["byNaId"].get(str(nid))
    if not r: return "no facts row"
    return "status=%s restr=%s extent=%s years=%s-%s creator=%s facility=%s"%(sf["statuses"][r["as"]] if "as" in r else None,[sf["restrictions"][i] for i in r.get("ar",[])],r.get("x"),r.get("y0"),r.get("y1"),sf["headings"][r["c"]] if "c" in r else None,sf["referenceUnits"][r["ru"]] if "ru" in r else None)
for ln in ["66D193","72D192","65D330","85D240"]:
    rows=[r for r in cf["lotFiles"] if r["lotNumber"]==ln]
    for r in rows: print(ln,"|",r["title"][:80],"| NAID",r["naId"],"| entry",r["hmsMlrEntryNumbers"],"| RG",r["recordGroup"],"|",r["matchType"],"|",facts(r["naId"]))
    if not rows: print(ln,"not in central-files lotFiles")
for lib in pl["libraries"]:
    print("LIB",lib["citedAs"],[ (c["identifier"],c["naId"]) for c in lib["collections"]][:6])
for lib in pl["libraries"]:
    if lib["citedAs"] in ("Johnson Library","Kennedy Library","Ford Library","Carter Library"):
        for c in lib["collections"]:
            for s in c.get("series",[]):
                if re.search(r"National Security (File|Affairs|Adviser|Advisor|Files)|^Country File",s["title"],re.I): print(lib["citedAs"],"|",c["identifier"],"|",s["title"],"| NAID",s["naId"],"|",s["inclusiveDates"])
