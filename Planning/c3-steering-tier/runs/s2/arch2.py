# resolve lots and series via the bundled JSON
import json
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(RES+"central-files-index.json")); sf=json.load(open(RES+"series-facts-index.json"))
print("central-files generated", cf["generated"], "schemaVersion", cf["schemaVersion"])
print("lotFiles row keys:", list(cf["lotFiles"][0].keys()))
print("numericalFile:", json.dumps(cf["numericalFile"])[:600]); print("countrySeries type", type(cf["countrySeries"]), json.dumps(cf["countrySeries"])[:400])
print("series-facts legend:", json.dumps(sf["legend"])[:1500])
want=["54D270","62D181","65F115","62D26","79F80"]
for r in cf["lotFiles"]:
    if r["lotNumber"] in want: print("LOT", json.dumps(r)[:700])
