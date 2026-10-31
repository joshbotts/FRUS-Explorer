# Resolve lot numbers through central-files-index.json lotFiles, then series-facts-index.json byNaId
import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json")); sf=json.load(open(R+"series-facts-index.json"))
print("central-files keys:",list(cf.keys())); print("series-facts keys:",list(sf.keys())); print("legend:",json.dumps(sf.get("legend"))[:900])
rows=cf["lotFiles"]; print("lotFiles rows:",len(rows)); print("sample row:",json.dumps(rows[0])[:500])
want=["63D351","54D270","59D95","66D95","62D26","81D113","79F80","62D1","69D121"]
for w in want:
    hit=[r for r in rows if r.get("lotNumber")==w]
    print("\nLOT",w,"rows:",len(hit))
    for r in hit[:2]: print("  ",json.dumps(r,ensure_ascii=False)[:700])
