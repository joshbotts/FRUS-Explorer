import json, sys
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
cf = json.load(open(RES + "/central-files-index.json")); sf = json.load(open(RES + "/series-facts-index.json"))
lc = json.load(open(RES + "/lot-claimants-index.json"))
def facts(na):
    r = sf["byNaId"].get(str(na))
    if not r: return None
    o = {}
    for k, spec in sf["legend"]["keys"].items():
        if k not in r: continue
        v = r[k]
        if spec["kind"] == "index": v = sf[spec["into"]][v]
        elif spec["kind"] == "indexList": v = [sf[spec["into"]][i] for i in v]
        o[spec["field"]] = v
    return o
claim = {l.get("lotNumber"): l for l in lc["lots"]}
for lot in sys.argv[1:]:
    rows = [r for r in cf["lotFiles"] if r["lotNumber"] == lot]
    print("==", lot, "rows:", len(rows), "| lot-claimants:", "yes" if lot in claim else "no")
    for r in rows:
        print("  RG", r["recordGroup"], "| naId", r["naId"], "| entry", r.get("hmsMlrEntryNumbers"), "|", r["title"], "|", r.get("matchType"))
        f = facts(r["naId"])
        if f: print("   facts:", json.dumps(f, ensure_ascii=False)[:600])
        else: print("   facts: none in series-facts-index")
print("lot-claimants sample keys:", list(lc["lots"][0].keys()))
print("central-files generated", cf["generated"], "series-facts generated", sf["generated"])
