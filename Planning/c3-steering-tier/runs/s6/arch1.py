import json, re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json"))
print("numericalFile:",json.dumps(cf["numericalFile"])[:1500])
print("countrySeries categories:",[c["category"] for c in cf["countrySeries"]])
def find(rows,pat,keys=("title","lotNumber")):
    return [r for r in rows if re.search(pat," ".join(str(r.get(k,"")) for k in keys),re.I)]
print("--lot 79F80:",[ (r["lotNumber"],r["title"],r["naId"]) for r in cf["lotFiles"] if r["lotNumber"].replace(" ","")=="79F80"])
print("--Central Foreign Policy:",[ (r["lotNumber"],r["title"][:80],r["naId"],r.get("recordGroup")) for r in find(cf["lotFiles"],"Central Foreign Policy|Kissinger")][:10])
ca=json.load(open(R+"collection-authority.json"))
print("--authority 79F80:",[ (c["id"],c["name"][:100],c.get("naIds") or c.get("naId"), len(c["volumeIds"])) for c in ca["collections"] if "79F80" in c["id"]])
for c in ca["collections"]:
    if "79F80" in c["id"]: print(json.dumps(c)[:900])
