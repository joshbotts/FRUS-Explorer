import json, collections
from docs_list import SECTIONS
R="/Applications/FRUS Explorer.app/Contents/Resources/"
S=sorted({a.split("/")[0] for s,l in SECTIONS for a in l})
print("SCOPE S: %d volumes: %s"%(len(S),", ".join(S)))
u=json.load(open(R+"collection-usage-index.json")); e=json.load(open(R+"external-citation-index.json"))
ca={c["id"]:c for c in json.load(open(R+"collection-authority.json"))["collections"] if "id" in c}
cf={r["lotNumber"]:r for r in json.load(open(R+"central-files-index.json"))["lotFiles"]}
sf=json.load(open(R+"series-facts-index.json"))
def rank(idx, ids, vols, inS):
    pos={v:i for i,v in enumerate(vols)}; sidx={pos[v] for v in inS if v in pos}
    tot=collections.Counter()
    for c in idx:
        n=sum(nn for nn,vv in zip(c["n"],c["v"]) if vv in sidx)
        if n: tot[ids[c["k"]]]+=n
    return tot, len(sidx)
def desc(cid):
    c=ca.get(cid,{}); nm=c.get("name","?"); 
    lot=c.get("lotFileNorm"); r=cf.get(lot) if lot else None
    s=f"{cid} | {nm[:90]} | RG {c.get('recordGroup')} | {c.get('repository')}"
    if r:
        f=sf["byNaId"].get(r["naId"],{})
        acc=sf["statuses"][f["as"]] if "as" in f else "n/a"
        s+=f" | NAID {r['naId']} entry {r.get('hmsMlrEntryNumbers')} | series '{r['title'][:70]}' | {f.get('y0')}-{f.get('y1')} | access {acc}"
    return s
print("\n== CAME-FROM channel (collection-usage-index.json, source notes), ranked over scope S")
t,n=rank(u["collections"],u["collectionIds"],u["volumes"],S); print("scope volumes found in index:",n)
for cid,k in t.most_common(14): print(f"{k:5d}  {desc(cid)}")
print("total notes mapped to a collection in scope:",sum(t.values()))
print("\n== POINTED-AT channel (external-citation-index.json targets), ranked over scope S")
t2,n2=rank(e["targets"],e["targetIds"],e["volumes"],S); print("scope volumes found in index:",n2)
for cid,k in t2.most_common(14): print(f"{k:5d}  {desc(cid)}")
print("total citations in scope:",sum(t2.values()))
