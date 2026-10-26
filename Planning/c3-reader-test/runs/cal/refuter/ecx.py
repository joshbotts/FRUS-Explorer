import json
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
d = json.load(open(R+"external-citation-index.json"))
print("coverage:", json.dumps(d["coverage"], indent=1)[:3000])
print("legend/notes keys:", [k for k in d if k not in ("classPairs","classSourceKeys","classTargetKeys","classTargets","pairs","sourceIds","targetIds","targets","volumes","coverage")])
for k in d:
    if k not in ("classPairs","classSourceKeys","classTargetKeys","classTargets","pairs","sourceIds","targetIds","targets","volumes","coverage"):
        print(k, "=", json.dumps(d[k])[:1500])
print("volumes[:5]", d["volumes"][:5])
print("sourceIds[:5]", d["sourceIds"][:5])
print("targetIds[:5]", d["targetIds"][:5])
print("targets[:3]", json.dumps(d["targets"][:3])[:800])
print("pairs[:5]", d["pairs"][:5])
nine = ["frus1961-63v10","frus1961-63v11","frus1961-63v12","frus1961-63v10-12mSupp","frus1964-68v32","frus1969-76ve10","frus1969-76ve11p1","frus1977-80v23","frus1977-80v24"]
present = [v for v in nine if v in d["volumes"]]
print("nine present in volumes list:", len(present), present)
