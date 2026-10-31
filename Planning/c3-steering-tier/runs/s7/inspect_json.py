import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
for f in ["central-files-index.json","series-facts-index.json","decimal-class-labels.json","collection-usage-index.json","lot-claimants-index.json"]:
    j=json.load(open(R+f)); print("==",f,list(j.keys()))
    for k,v in j.items():
        s=json.dumps(v); print("  ",k,type(v).__name__, len(v) if hasattr(v,"__len__") else "", s[:300])
