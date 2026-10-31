import json,collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
S=json.load(open("work/set.json"))
vols=sorted({v for f,v,d in S})
print("scope volumes (",len(vols),"):",vols)
u=json.load(open(R+"collection-usage-index.json")); e=json.load(open(R+"external-citation-index.json")); a=json.load(open(R+"collection-authority.json"))
auth={c["id"]:c for c in a["collections"]}
uv={v:i for i,v in enumerate(u["volumes"])}; ev={v:i for i,v in enumerate(e["volumes"])}
print("volumes missing from usage index:",[v for v in vols if v not in uv]); print("volumes absent from external-citation index volume list:",[v for v in vols if v not in ev])
came=collections.Counter()
for c in u["collections"]:
    for n,v in zip(c["n"],c["v"]):
        if u["volumes"][v] in vols: came[u["collectionIds"][c["k"]]]+=n
point=collections.Counter()
for c in e["targets"]:
    for n,v in zip(c["n"],c["v"]):
        if e["volumes"][v] in vols: point[e["targetIds"][c["k"]]]+=n
def nm(i): 
    x=auth.get(i); return (x["name"][:95]+" | "+x["repository"]) if x else "?"
print("\nCAME-FROM (collection-usage-index, notes citing the collection, in the scope volumes): total collections",len(came),"total notes",sum(came.values()))
for i,n in came.most_common(15): print(n,i,nm(i))
print("\nPOINTED-AT (external-citation-index targets, footnote references, in the scope volumes): total targets",len(point),"refs",sum(point.values()))
for i,n in point.most_common(15): print(n,i,nm(i))
# categories
cats=u["categories"]
tot=collections.Counter()
for c in u["volumeCategories"]:
    for n,v in zip(c["n"] if False else [],[]): pass
print("\nvolumeCategories sample keys",list(u["volumeCategories"][0].keys()))

print("\nCATEGORY totals (usage index volumeCategories) in scope volumes:")
cat=collections.Counter()
for c in u["volumeCategories"]:
    for n,v in zip(c["n"],c["v"]) if False else []: pass
# volumeCategories: k is volume index? inspect
vc=u["volumeCategories"]
print(len(vc), json.dumps(vc[0])[:200])
