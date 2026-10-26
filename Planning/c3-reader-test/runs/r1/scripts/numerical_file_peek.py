# Print the structure of central-files-index.json numericalFile and the countrySeries categories with their date spans, to see what the bundle says about 1906-1910 and about the 19th-century instructions and despatches.
import json
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
d = json.load(open(R + "central-files-index.json"))
nf = d["numericalFile"]
print({k: (v if not isinstance(v, (list, dict)) else type(v).__name__ + str(len(v))) for k, v in nf.items()})
print(json.dumps(nf["rolls"][0])[:300]); print(json.dumps(nf["rolls"][-1])[:300])
cs = d["countrySeries"]
print(type(cs).__name__, (list(cs.keys())[:10] if isinstance(cs, dict) else len(cs)))
if isinstance(cs, dict):
    for k, v in list(cs.items())[:3]:
        print(k, json.dumps(v)[:300])
else:
    print(json.dumps(cs[0])[:400])
