import json
from collections import defaultdict
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
u = json.load(open(R+"collection-usage-index.json"))
auth = json.load(open(R+"collection-authority.json"))
A = {c["id"]: c for c in auth["collections"]}
by_coll = json.load(open("usage_nine.json"))
ex = json.load(open("ecx_nine.json"))["by_target"]
for cid in ["txt:kennedy library|national security file","txt:nixon|nsc file","txt:johnson library|national security file","txt:department of state|central file","txt:carter library|national security affair"]:
    a = A[cid]
    ch = a.get("children") or []
    print("\n==", a["name"], "| children:", len(ch), "| sample:", json.dumps(ch[:2])[:400])
    # children may be ids or dicts
    cited = []
    for c in ch:
        key = c if isinstance(c, str) else (c.get("id") or c.get("key") or json.dumps(c))
        n = by_coll.get(key, 0) + ex.get(key, 0)
        if n: cited.append((n, key, (A.get(key, {}).get("name") if isinstance(c, str) else c.get("name"))))
    print("  children cited by the nine (came-from + pointed-at):", len(cited))
    for n, k, nm in sorted(cited, reverse=True)[:40]: print(f"    {n:4d} {k[:70]} | {nm}")
    if "nixon" in cid:
        bc = [c for c in ch if "backchannel" in json.dumps(c).lower()]
        print("  Backchannel children:", json.dumps(bc)[:600])
# Does the usage index key child collections directly?
child_ids = set()
for c in auth["collections"]:
    for ch in c.get("children") or []:
        child_ids.add(ch if isinstance(ch, str) else (ch.get("id") or ""))
in_usage = set(u["collectionIds"])
print("\nchild ids that appear as usage collectionIds:", len(child_ids & in_usage), "of", len(child_ids))
print("sample child ids:", list(child_ids)[:5])
# 1.1% weight: no-NAID lots over both channels
lots_all = {c for c in set(by_coll)|set(ex) if c.startswith("lot:")}
nonaid = {c for c in lots_all if not A.get(c,{}).get("naId")}
w_nonaid = sum(by_coll.get(c,0)+ex.get(c,0) for c in nonaid)
w_total = sum(by_coll.values())+sum(ex.values())
w_lots = sum(by_coll.get(c,0)+ex.get(c,0) for c in lots_all)
print(f"\nlots both channels: {len(lots_all)}, without NAID: {len(nonaid)}, weight {w_nonaid} of total {w_total} = {100*w_nonaid/w_total:.1f}% ; of lot weight {w_lots} = {100*w_nonaid/w_lots:.1f}%")
print("no-NAID lots:", sorted(nonaid))
