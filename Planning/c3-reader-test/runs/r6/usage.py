# collection-usage-index.json over the scope's volume set (volumes of raw/scope_all.tsv); also pointed-at decimal glosses gated by document date.
import json, collections, sqlite3, re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
u=json.load(open(R+"collection-usage-index.json"))
vols=sorted({l.split("\t")[0] for l in open("raw/scope_all.tsv")})
vi={v:i for i,v in enumerate(u["volumes"])}
S={vi[v] for v in vols if v in vi}
print("scope volumes",len(vols),"found in usage index",len(S))
print("categories",u["categories"])
tot=collections.Counter()
for c in u["collections"]:
    n=sum(cnt for cnt,v in zip(c["n"],c["v"]) if v in S)
    if n: tot[u["collectionIds"][c["k"]]]+=n
print("collections reached in scope volumes:",len(tot)); [print("  ",n,k) for k,n in tot.most_common(15)]
ct=collections.Counter()
for c in u["classes"]:
    n=sum(cnt for cnt,v in zip(c["n"],c["v"]) if v in S)
    if n: ct[u["classKeys"][c["k"]]]+=n
print("class keys cited in scope volumes' notes:",len(ct)); [print("  ",n,k) for k,n in ct.most_common(15)]
