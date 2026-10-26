# Resolve archival targets through the bundled JSON only: lot numbers via central-files-index.json (lotFiles) + series-facts-index.json (byNaId) + lot-claimants-index.json;
# library collections via curated-library-resolutions.json. Prints what each file says; it adds nothing from outside the bundle.
import json, sys, re
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
cf = json.load(open(R + "central-files-index.json"))
sf = json.load(open(R + "series-facts-index.json"))
lc = json.load(open(R + "lot-claimants-index.json"))
cur = json.load(open(R + "curated-lot-resolutions.json"))
lib = json.load(open(R + "curated-library-resolutions.json"))
print("keys: central-files lotFiles row:", sorted(cf["lotFiles"][0].keys()))
print("lot-claimants keys:", list(lc.keys()), "| row keys:", sorted(lc["lots"][0].keys()) if isinstance(lc.get("lots"), list) else type(lc.get("lots")))
print("curated-lot-resolutions keys:", list(cur.keys()), "| row keys:", sorted(cur["lots"][0].keys()) if isinstance(cur.get("lots"), list) else "")
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
lots = sys.argv[1].split(",") if len(sys.argv) > 1 else []
for lot in lots:
    rows = [r for r in cf["lotFiles"] if r["lotNumber"] == lot]
    print("== lot", lot, "| central-files-index rows:", len(rows))
    for r in rows:
        print("   naId %s | RG %s | %s | level %s | entries %s | match %s | %s" % (r["naId"], r["recordGroup"], r["title"], r.get("levelOfDescription"), r.get("hmsMlrEntryNumbers"), r.get("matchType"), r.get("catalogURL")))
        fa = facts(r["naId"])
        print("      series-facts:", json.dumps(fa, ensure_ascii=False)[:420] if fa else "none")
    cl = [r for r in lc["lots"] if r.get("lotNumber") == lot or r.get("lot") == lot]
    print("   lot-claimants rows:", json.dumps(cl, ensure_ascii=False)[:500] if cl else "none")
    cr = [r for r in cur["lots"] if r.get("lotNumber") == lot or r.get("lot") == lot]
    print("   curated-lot-resolutions rows:", json.dumps(cr, ensure_ascii=False)[:400] if cr else "none")
libs = sys.argv[2].split(";") if len(sys.argv) > 2 else []
for item in libs:
    repo, coll = item.split("|")
    hit = [e for e in lib["entries"] if e["repository"] == repo and e["collection"] == coll]
    print("== library", repo, "/", coll, "| curated entries:", len(hit))
    for e in hit[:3]:
        print("   sub:", e.get("subCollection"), "| ", json.dumps(e["resolution"], ensure_ascii=False)[:520])
