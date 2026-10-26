import json
from collections import defaultdict
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
d = json.load(open(R+"external-citation-index.json"))
auth = json.load(open(R+"collection-authority.json"))
A = {c["id"]: c for c in auth["collections"]}
# sample authority records of each id prefix
pref = defaultdict(list)
for c in auth["collections"]: pref[c["id"].split(":")[0]].append(c)
print("authority id prefixes:", {k: len(v) for k, v in pref.items()})
for k, v in pref.items():
    print("  sample", k, json.dumps(v[0])[:600])
allkeys = set()
for c in auth["collections"]: allkeys |= set(c.keys())
print("authority record keys:", sorted(allkeys))
nine = ["frus1961-63v10","frus1961-63v11","frus1961-63v12","frus1961-63v10-12mSupp","frus1964-68v32","frus1969-76ve10","frus1969-76ve11p1","frus1977-80v23","frus1977-80v24"]
vidx = {v: i for i, v in enumerate(d["volumes"])}
nine_idx = {vidx[v] for v in nine if v in vidx}
by_target = defaultdict(int)
for t in d["targets"]:
    for cnt, vi in zip(t["n"], t["v"]):
        if vi in nine_idx:
            by_target[d["targetIds"][t["k"]]] += cnt
total = sum(by_target.values())
print("\nNINE: external refs total =", total, "; distinct targets =", len(by_target))
for tid, n in sorted(by_target.items(), key=lambda x: -x[1])[:25]:
    a = A.get(tid, {})
    print(f"  {n:4d}  {tid}  | {a.get('name','?')[:90]} | repo={a.get('repository')} | naId={a.get('naId') or a.get('naid') or a.get('seriesNaId')}")
# how many target units are never named by the nine volumes' own source notes (usage index)
u = json.load(open(R+"collection-usage-index.json"))
uvidx = {v: i for i, v in enumerate(u["volumes"])}
unine = {uvidx[v] for v in nine if v in uvidx}
named = set()
for c in u["collections"]:
    for cnt, vi in zip(c["n"], c["v"]):
        if vi in unine: named.add(u["collectionIds"][c["k"]])
never = [t for t in by_target if t not in named]
print("targets never named by the nine's source notes:", len(never), never[:20])
json.dump({"by_target": by_target}, open("ecx_nine.json","w"), indent=1)
