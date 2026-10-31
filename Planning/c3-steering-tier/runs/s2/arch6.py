import json
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
vs=json.load(open(RES+"volume-sources-index.json")); print("volume-sources keys", list(vs.keys()), vs.get("generated"))
mc=vs.get("majorCollections")
s=json.dumps(mc); print("majorCollections type", type(mc), s[:300])
items = mc if isinstance(mc,list) else list(mc.values()) if isinstance(mc,dict) else []
for it in items:
    t=json.dumps(it)
    if "Decimal" in t or "Marshall" in t or "Kissinger" in t: print("  MC:", t[:400])
dc=json.load(open(RES+"decimal-class-labels.json")); print("decimal-class keys", list(dc.keys()), dc.get("generated"))
print("coverage:", json.dumps(dc["coverage"])[:900])
