import json, sys
R="/Applications/FRUS Explorer.app/Contents/Resources"
cf=json.load(open(R+"/central-files-index.json"))
sf=json.load(open(R+"/series-facts-index.json"))
print("cf schemaVersion",cf["schemaVersion"],"generated",cf["generated"]); print("sf schemaVersion",sf["schemaVersion"],"generated",sf["generated"])
print("lotFiles row keys:", list(cf["lotFiles"][0].keys()))
print("sf legend:", json.dumps(sf["legend"])[:1500])
want=sys.argv[1:]
rows={r["lotNumber"]:r for r in cf["lotFiles"] if r.get("lotNumber") in want}
for w in want: print(w, json.dumps(rows.get(w))[:600])
