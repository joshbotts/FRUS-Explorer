import json,collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
u=json.load(open(R+"collection-usage-index.json")); a=json.load(open(R+"collection-authority.json"))
auth={c["id"]:c for c in a["collections"]}
vols=u["volumes"]
def scope(names): return set(vols.index(n) for n in names)
info4=scope("frus1917-72PubDipv06 frus1917-72PubDipv07 frus1917-72PubDipv08 frus1977-80v30".split())
eap=scope(open(R and "/Users/jbotts/frus-analysis/c3f/runs/f10/eap_vols.txt").read().split(","))
def top(sc,label,k=12):
    tot=collections.Counter()
    for c in u["collections"]:
        cid=u["collectionIds"][c["k"]]
        for n,v in zip(c["n"],c["v"]):
            if v in sc: tot[cid]+=n
    print("\n##",label,"| volumes",len(sc),"| notes in a collection:",sum(tot.values()))
    for cid,n in tot.most_common(k):
        x=auth.get(cid,{})
        print("  %4d %s | %s | %s"%(n,cid,(x.get("name") or "")[:90],x.get("repository")))
top(info4,"CAME-FROM channel: collection-usage-index, 4 public-diplomacy volumes (PubDip v06-08, 1977-80 v30)")
top(eap,"CAME-FROM channel: collection-usage-index, 99 EAP volumes",15)
# category totals
cats=u["categories"]
def cat(sc,label):
    tot=collections.Counter()
    for vc in u["volumeCategories"]:
        for n,v in zip(vc["n"],vc["v"]) if "v" in vc else []:
            pass
    print()
for vc in u["volumeCategories"][:1]: print(list(vc.keys()))
