# Resolve the scope's archival units against the bundled JSON (no SQL).
import json
B="/Applications/FRUS Explorer.app/Contents/Resources/"
sf=json.load(open(B+"series-facts-index.json"))
print("legend:",json.dumps(sf["legend"])[:1500])
ca=json.load(open(B+"collection-authority.json"))
print("authority row example:",json.dumps(ca["collections"][0])[:600])
hits=[c for c in ca["collections"] if any(s in json.dumps(c) for s in ["Information Agency","RG 306","\"306\"","USIA","OCB","61D385","58D726","Marks Papers","Kissinger Office"])]
print("authority hits:",len(hits))
for c in hits[:40]: print("  ",json.dumps(c)[:400])
cf=json.load(open(B+"central-files-index.json"))
for r in cf["lotFiles"]:
    if r.get("lotNumber") in ("61D385","58D726"): print("LOT",json.dumps(r)[:900])
