import json, collections
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
cur=json.load(open(RES+"curated-lot-resolutions.json"))
for r in cur["lots"]:
    if r["lotNumber"]=="54D270": print("54D270 candidates:", [(c["naId"],c["title"]) for c in r["candidates"]])
print("curated series conferenceFiles:", json.dumps(cur["series"].get("conferenceFiles") if isinstance(cur["series"],dict) else [s for s in cur["series"] if "onference" in json.dumps(s)])[:700])
cu=json.load(open(RES+"collection-usage-index.json"))
vols=sorted({l.split("/")[0] for l in open("cited.txt") if l.strip()})
vix={v:i for i,v in enumerate(cu["volumes"])}
want={vix[v] for v in vols}
tot=collections.Counter()
for c in cu["collections"]:
    for n,v in zip(c["n"],c["v"]):
        if v in want: tot[cu["collectionIds"][c["k"]]]+=n
print("scope volumes (the cited documents' 12):", vols)
print("top pointed-at collections (footnote notes naming them), over those 12 volumes:")
for k,n in tot.most_common(15): print("  ", k, n)
