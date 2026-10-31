import json, sys
R="/Applications/FRUS Explorer.app/Contents/Resources"
sf=json.load(open(R+"/series-facts-index.json"))
L=sf["legend"]["keys"]
def deref(row):
    out={}
    for k,v in row.items():
        spec=L.get(k)
        if not spec: out[k]=v; continue
        if "into" in spec:
            arr=sf[spec["into"]]
            out[spec["field"]]=[arr[i] for i in v] if spec["kind"]=="indexList" else arr[v]
        else: out[spec["field"]]=v
    return out
for n in sys.argv[1:]:
    r=sf["byNaId"].get(n); print(n, json.dumps(deref(r)) if r else None)
# pre-1940 share
ys=[r.get("y0") for r in sf["byNaId"].values() if r.get("y0") is not None]
print("series with inclusiveStartYear:",len(ys),"starting before 1940:",sum(1 for y in ys if y<1940))
for f in ["curated-lot-resolutions.json","lot-claimants-index.json"]:
    j=json.load(open(R+"/"+f)); 
    for row in j["lots"]:
        if "54D270" in json.dumps(row): print(f, json.dumps(row)[:500])
ca=json.load(open(R+"/collection-authority.json"))
for c in ca["collections"]:
    s=json.dumps(c)
    if "54D270" in s or "54 D 270" in s: print("authority", s[:600])
