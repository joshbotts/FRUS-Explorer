import json,re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
a=json.load(open(R+"accession-series-index.json")); print("top keys",list(a.keys())[:8], "schemaVersion",a.get("schemaVersion"))
box=a.get("accessions") or a.get("rows") or a
ks=[k for k in (box.keys() if isinstance(box,dict) else [])]
print(len(ks),ks[:3])
for k in ["306/72A5121","306/69A3445","306/68A4933","306/66Y0274","306/72A5121".replace("306/","")]:
    if k in box: print(k, json.dumps(box[k])[:700])
    else: print(k,"absent")
ca=json.load(open(R+"collection-authority.json"))
for c in ca["collections"]:
    s=json.dumps(c)
    if "68 A 4933" in s: print("CA:",s[:700])
