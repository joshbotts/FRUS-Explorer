import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
for f in ["series-facts-index.json","central-files-index.json","collection-usage-index.json","external-citation-index.json","presidential-library-catalog.json","lot-claimants-index.json"]:
    j=json.load(open(R+f)); print("\n##",f, "schemaVersion",j.get("schemaVersion") if isinstance(j,dict) else None, "top keys:",list(j.keys())[:14] if isinstance(j,dict) else type(j))
j=json.load(open(R+"series-facts-index.json"))
print("legend",j.get("legend"))
print({k:(type(v).__name__,len(v) if hasattr(v,'__len__') else v) for k,v in j.items()})
b=j["byNaId"]; k0=list(b.keys())[0]; print(k0,b[k0])
for k in j:
    if isinstance(j[k],list): print(k,j[k][:6])
