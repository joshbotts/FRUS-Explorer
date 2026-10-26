# Print every claimant series of lot 62D1 (and 64D563) from lot-claimants-index.json with its series-facts row (access, creator, extent, dates). Bundled JSON only.
import json, sys
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
sf = json.load(open(R + "series-facts-index.json"))
lc = json.load(open(R + "lot-claimants-index.json"))
def facts(naid):
    r = sf["byNaId"].get(str(naid))
    if not r: return None
    out = {}
    for k, v in r.items():
        f = sf["legend"]["keys"][k]
        if f["kind"] == "index": v = sf[f["into"]][v]
        elif f["kind"] == "indexList": v = [sf[f["into"]][i] for i in v]
        out[f["field"]] = v
    return out
for lot in sys.argv[1].split(","):
    rows = [r for r in lc["lots"] if r.get("lotNumber") == lot]
    print("== lot", lot, "| rows:", len(rows), "| note:", lc.get("note", "")[:200])
    for r in rows:
        for c in r["claimants"]:
            fa = facts(c["naId"]) or {}
            print("  naId %s | %s | entries %s | dates %s | evidence %s | access %s | creator %s | extent %s | reference unit %s" % (c["naId"], c["title"], c.get("hmsMlrEntryNumbers"), c.get("dateRange"), c.get("evidence"), fa.get("accessStatus"), fa.get("creator"), fa.get("extent"), fa.get("referenceUnit")))
