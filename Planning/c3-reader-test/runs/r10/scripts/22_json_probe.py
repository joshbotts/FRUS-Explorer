# Probe bundled JSON containers: print the coverage/notes blocks and a few rows of collection-usage-index.json,
# external-citation-index.json and central-files-index.json (countrySeries categories, numericalFile).
import json
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
cu = json.load(open(RES + "collection-usage-index.json"))
print("CU coverage:", json.dumps(cu["coverage"])[:2500])
print("CU categories:", cu["categories"])
print("CU first collections ids:", cu["collectionIds"][:12])
print("CU collections[0..2]:", cu["collections"][:3])
print("CU classes[0..2]:", cu["classes"][:3], cu["classKeys"][:3])
print("CU volumeCategories[0] keys:", list(cu["volumeCategories"][0].keys()), "len n", len(cu["volumeCategories"][0]["n"]))
ec = json.load(open(RES + "external-citation-index.json"))
print("EC coverage:", json.dumps(ec["coverage"])[:3000])
print("EC targets[0..2]:", ec["targets"][:3], ec["targetIds"][:3])
print("EC pairs[0..2]:", ec["pairs"][:3], " sourceIds[0..2]", ec["sourceIds"][:3])
cf = json.load(open(RES + "central-files-index.json"))
print("CF countrySeries categories:", [(c["category"], c["displayName"], len(c.get("rolls", []))) for c in cf["countrySeries"]])
print("CF numericalFile:", json.dumps(cf["numericalFile"])[:800])
print("CF lotFiles keys:", sorted(cf["lotFiles"][0].keys()))
