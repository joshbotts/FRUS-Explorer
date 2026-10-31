import json,sys
m=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
vols = m["volumes"] if isinstance(m,dict) and "volumes" in m else m
if len(sys.argv)>1 and sys.argv[1]=="keys":
    print(type(m), list(m.keys())[:20] if isinstance(m,dict) else len(m)); print(json.dumps(vols[0])[:800]); sys.exit()
ids=[l.strip().split("|")[0] for l in open(sys.argv[1])]
by={v.get("id") or v["filename"][:-4]:v for v in vols}
for i in ids:
    v=by.get(i,{}); print(i,"|"," ".join((v.get("title") or "").split()),"|",v.get("dateRange",{}).get("earliest","")[:4],v.get("dateRange",{}).get("latest","")[:4])
