import json,collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
u=json.load(open(R+"collection-usage-index.json"))
auth={c["id"]:c for c in json.load(open(R+"collection-authority.json"))["collections"]}
print("usage coverage",u["coverage"]); print("categories",u["categories"])
vols=u["volumes"];vi={v:i for i,v in enumerate(vols)}
def rank(S,label):
    S={vi[v] for v in S if v in vi};tot=collections.Counter()
    for c in u["collections"]:
        for n,v in zip(c["n"],c["v"]):
            if v in S: tot[c["k"]]+=n
    print("==",label,"volumes",len(S),"collections",len(tot))
    for k,n in tot.most_common(14):
        cid=u["collectionIds"][k];a=auth.get(cid,{})
        print("  %4d  %s | %s | %s"%(n,cid,(a.get("name") or "")[:90],a.get("repository")))
pd=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30']
rank(pd,"PUBLIC DIPLOMACY volumes (usage index = came-from, per source note)")
ea=[l.strip() for l in open("work/ea_vols_list.txt")]
rank(ea,"74 EAST ASIA volumes")
