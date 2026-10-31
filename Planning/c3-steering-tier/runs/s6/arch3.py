import json, re, collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cu=json.load(open(R+"collection-usage-index.json")); ec=json.load(open(R+"external-citation-index.json")); ca=json.load(open(R+"collection-authority.json"))
print("CU coverage:",json.dumps(cu["coverage"])[:700])
print("EC coverage:",json.dumps(ec["coverage"])[:1200])
print("CU categories:",cu["categories"])
names={c["id"]:c for c in ca["collections"]}
SCOPE=sorted({k.split("/")[0] for k in open("scope_keys.txt").read().split()})
print("scope volumes",len(SCOPE),SCOPE)
vi={v:i for i,v in enumerate(cu["volumes"])}
tot=collections.Counter()
for r in cu["collections"]:
    s=sum(n for n,v in zip(r["n"],r["v"]) if cu["volumes"][v] in SCOPE)
    if s: tot[cu["collectionIds"][r["k"]]]+=s
print("== came-from (collection-usage-index) top 15 over scope")
for cid,n in tot.most_common(15):
    c=names.get(cid,{}); print(" ",n,cid,"|",(c.get("name") or "")[:90],"| RG",c.get("recordGroup"),"|",c.get("repository"))
evi={v:i for i,v in enumerate(ec["volumes"])}
print("scope volumes in ec.volumes:",sum(1 for v in SCOPE if v in evi),"of",len(SCOPE))
tt=collections.Counter()
for r in ec["targets"]:
    s=sum(n for n,v in zip(r["n"],r["v"]) if ec["volumes"][v] in SCOPE)
    if s: tt[ec["targetIds"][r["k"]]]+=s
print("== pointed-at (external-citation-index) top 15 over scope")
for cid,n in tt.most_common(15):
    c=names.get(cid,{}); print(" ",n,cid,"|",(c.get("name") or "")[:90],"| RG",c.get("recordGroup"),"|",c.get("repository"))
