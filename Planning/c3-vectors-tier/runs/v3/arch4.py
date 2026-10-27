import json, collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cu=json.load(open(R+"collection-usage-index.json"))
ca=json.load(open(R+"collection-authority.json"))
lc=json.load(open(R+"lot-claimants-index.json"))
cur=json.load(open(R+"curated-lot-resolutions.json"))
vols=cu["volumes"]; vi={v:i for i,v in enumerate(vols)}
setA=[l.rstrip("\n").split("\t") for l in open("setA.tsv")]
scope=sorted({v for v,d,dt,t in setA}); print("scope volumes",len(scope))
sidx={vi[v] for v in scope}
tot=collections.Counter(); nv=collections.Counter()
for k,c in enumerate(cu["collections"]):
    for n,v in zip(c["n"],c["v"]):
        if v in sidx: tot[k]+=n; nv[k]+=1
auth={c["id"]:c for c in ca["collections"]}
print("collection-usage-index coverage",cu["coverage"], "generated",cu["generated"])
print("authority keys sample",list(ca["collections"][0].keys()))
rows=[]
for k,n in tot.most_common(30):
    cid=cu["collectionIds"][k]; a=auth.get(cid,{})
    print(n,nv[k],cid,"|",(a.get("name") or "")[:90],"|",a.get("repository"), a.get("naIds") or a.get("naId"))
print("note categories:",cu["categories"])
cl={r["lotNumber"]:r for r in lc["lots"]}
for l in ["65D438","74D272","66D501","62D24","62D418","66D95","73D191","64D199","65D330","70D149","66D204"]:
    print("claimants",l, [ (c["title"],c["naId"],c["dateRange"]) for c in cl[l]["claimants"]] if l in cl else None)
print("curated 70D149:",[r for r in cur["lots"] if str(r.get("lotNumber"))=="70D149"][:1])
