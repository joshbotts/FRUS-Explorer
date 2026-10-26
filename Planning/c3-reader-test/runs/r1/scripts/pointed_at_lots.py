# Resolve the lot numbers cited in the footnotes of the family C candidates (list given as arguments) through central-files-index.json and series-facts-index.json;
# print title, creator heading, inclusive dates and access status for each, and count how many creators name the Bureau of Inter-American Affairs.
import json, sys
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
cf = json.load(open(R + "central-files-index.json"))
sf = json.load(open(R + "series-facts-index.json"))
lc = json.load(open(R + "lot-claimants-index.json"))
claim = {r["lotNumber"]: r["claimants"] for r in lc["lots"]}
def facts(naid):
    r = sf["byNaId"].get(str(naid))
    if not r: return {}
    out = {}
    for k, v in r.items():
        f = sf["legend"]["keys"][k]
        if f["kind"] == "index": v = sf[f["into"]][v]
        elif f["kind"] == "indexList": v = [sf[f["into"]][i] for i in v]
        out[f["field"]] = v
    return out
lots = sys.argv[1].split(",")
ara = 0; unresolved = 0
for lot in lots:
    rows = [r for r in cf["lotFiles"] if r["lotNumber"] == lot]
    if not rows:
        unresolved += 1; print(lot, "| not in central-files-index"); continue
    r = rows[0]; fa = facts(r["naId"])
    cr = fa.get("creator") or ""
    isara = "Inter-American" in cr
    ara += isara
    print("%s | NAID %s | %s | creator: %s | %s-%s | %s | claimants: %s" % (lot, r["naId"], r["title"][:70], cr[:90], fa.get("inclusiveStartYear"), fa.get("inclusiveEndYear"), fa.get("accessStatus"), len(claim.get(lot, [])) or 1))
print("lots:", len(lots), "| resolved:", len(lots) - unresolved, "| creator names Inter-American Affairs:", ara)
