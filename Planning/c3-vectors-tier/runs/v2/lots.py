# [JSON] Resolve lots through central-files-index.json lotFiles (list keyed on lotNumber), then series-facts-index.json byNaId (legend keys).
import json
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
cf = json.load(open(R + "central-files-index.json")); sf = json.load(open(R + "series-facts-index.json"))
print("lotFiles row keys:", list(cf["lotFiles"][0].keys())); print("legend:", json.dumps(sf["legend"])[:1200])
idx = {r["lotNumber"]: r for r in cf["lotFiles"]}
for lot in ["65D438", "74D272", "66D501", "62D24", "62D418", "66D95", "70D149", "65A987", "66D204"]:
    r = idx.get(lot); print("==", lot, json.dumps(r)[:600] if r else "NOT IN central-files-index")
    if r:
        for k in ("seriesNaId", "naId", "seriesNAID", "naid"):
            if k in r and r[k]:
                f = sf["byNaId"].get(str(r[k])); print("   series-facts:", json.dumps(f)[:500] if f else "none")
