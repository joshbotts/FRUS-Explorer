import json, re
from collections import defaultdict
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
u = json.load(open(R+"collection-usage-index.json"))
auth = json.load(open(R+"collection-authority.json"))
A = {c["id"]: c for c in auth["collections"]}
print("usage keys:", list(u.keys()))
print("categories:", u["categories"])
print("volumeCategories[0]:", json.dumps(u["volumeCategories"][0])[:300])
print("classes[0]:", u["classes"][0], "classKeys[:5]:", u["classKeys"][:5])
print("coverage:", u["coverage"])
nine = ["frus1961-63v10","frus1961-63v11","frus1961-63v12","frus1961-63v10-12mSupp","frus1964-68v32","frus1969-76ve10","frus1969-76ve11p1","frus1977-80v23","frus1977-80v24"]
vidx = {v: i for i, v in enumerate(u["volumes"])}
nine_idx = {vidx[v]: v for v in nine if v in vidx}
print("nine in usage volumes:", len(nine_idx))
print("volumeNoteCounts for nine:", {v: u["volumeNoteCounts"][i] for i, v in nine_idx.items()}, "sum", sum(u["volumeNoteCounts"][i] for i in nine_idx))
# notes in a collection, by collection
by_coll = defaultdict(int)
for c in u["collections"]:
    for cnt, vi in zip(c["n"], c["v"]):
        if vi in nine_idx: by_coll[u["collectionIds"][c["k"]]] += cnt
in_coll = sum(by_coll.values())
print("NINE notes in a collection:", in_coll, "distinct collections:", len(by_coll), "pct of 4213:", round(100*in_coll/4213,1), "pct of 4368:", round(100*in_coll/4368,1))
# classes (central file classes) for the nine
by_class = defaultdict(int)
for c in u["classes"]:
    for cnt, vi in zip(c["n"], c["v"]):
        if vi in nine_idx: by_class[u["classKeys"][c["k"]]] += cnt
print("NINE notes with a class key:", sum(by_class.values()), "distinct classes:", len(by_class), "of", len(u["classKeys"]))
# corpus baseline
cov = u["coverage"]
print("baseline notesInACollection/noteCount =", round(100*cov["notesInACollection"]/cov["noteCount"],1), "; /documents 320646 =", round(100*cov["notesInACollection"]/320646,1), "; (inColl+classKey)/noteCount=", round(100*(cov["notesInACollection"]+cov["notesWithAClassKey"])/cov["noteCount"],1))
# top collections for the nine, with naId
print("\nTop came-from collections for the nine:")
for cid, n in sorted(by_coll.items(), key=lambda x: -x[1])[:40]:
    a = A.get(cid, {})
    print(f"  {n:4d}  {cid[:60]:60s} | {a.get('name','?')[:70]} | repo={a.get('repository')} | naId={a.get('naId')} | rg={a.get('recordGroup')} | children={len(a.get('children',[]) or [])}")
# cluster by repository + root name heuristics
def cluster(cid):
    a = A.get(cid, {})
    return (a.get("repository"), a.get("name","?").split(":")[0][:50])
by_cluster = defaultdict(int)
for cid, n in by_coll.items(): by_cluster[cluster(cid)] += n
print("\nBy (repository, name head):")
for k, n in sorted(by_cluster.items(), key=lambda x: -x[1])[:25]: print(f"  {n:4d}  {k}")
# lots among the nine's came-from collections: NAID coverage
lots = {cid: n for cid, n in by_coll.items() if cid.startswith("lot:")}
nolot_naid = {cid: n for cid, n in lots.items() if not A.get(cid, {}).get("naId")}
print("\nlots cited (came-from):", len(lots), "; without NAID:", len(nolot_naid), "; weight without NAID:", sum(nolot_naid.values()), "of", sum(lots.values()), "=", round(100*sum(nolot_naid.values())/max(1,sum(lots.values())),1), "%")
txts = {cid: n for cid, n in by_coll.items() if cid.startswith("txt:")}
print("txt (named) collections cited:", len(txts), "; with NAID:", sum(1 for c in txts if A.get(c,{}).get('naId')))
# both channels union
ex = json.load(open("ecx_nine.json"))["by_target"]
units = set(by_coll) | set(ex)
print("\nunits across both channels:", len(units), "; with NAID:", sum(1 for c in units if A.get(c,{}).get('naId')))
alllots = {c for c in units if c.startswith("lot:")}
print("lots across both channels:", len(alllots), "; without NAID:", sum(1 for c in alllots if not A.get(c,{}).get('naId')))
print("named (txt) across both channels:", len(units-alllots), "; with NAID:", sum(1 for c in units-alllots if A.get(c,{}).get('naId')))
json.dump({k: v for k, v in by_coll.items()}, open("usage_nine.json","w"), indent=1)
