import json
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
auth = json.load(open(R+"collection-authority.json"))
A = {c["id"]: c for c in auth["collections"]}
nine = set(["frus1961-63v10","frus1961-63v11","frus1961-63v12","frus1961-63v10-12mSupp","frus1964-68v32","frus1969-76ve10","frus1969-76ve11p1","frus1977-80v23","frus1977-80v24"])
for cid, memo in [("txt:kennedy library|national security file","18 named sub-series"),("txt:nixon|nsc file","15 of 40"),("txt:johnson library|national security file","29 of 100"),("txt:department of state|central file","101 of 1,164 classes"),("txt:carter library|national security affair","(Brzezinski and Staff Material)")]:
    a = A[cid]; ch = a.get("children") or []
    hit = [c["name"] for c in ch if nine & set(c.get("volumeIds", []))]
    print(f"{a['name']:30s} children={len(ch):5d} cited-by-nine={len(hit):4d}  memo: {memo}")
    if len(hit) <= 40: print("   ", hit)
    print("    volumeIds on parent:", sorted(set(a.get('volumeIds',[])) & nine))
# series-facts for the three NAIDs
sf = json.load(open(R+"series-facts-index.json"))
print("\nseries-facts byNaId count:", len(sf["byNaId"]), "; generated", sf["generated"])
print("statuses:", sf["statuses"]); print("restrictions:", sf["restrictions"]); print("useRestrictions:", sf["useRestrictions"]); print("findingAidTypes:", sf["findingAidTypes"]); print("referenceUnits:", sf["referenceUnits"])
for naid in ["27022950","614703","1487627"]:
    r = sf["byNaId"].get(naid)
    if not r: print(naid, "NOT IN series-facts"); continue
    out = {}
    for k, v in r.items():
        leg = sf["legend"]["keys"].get(k, {})
        if leg.get("kind") == "index": out[leg["field"]] = sf[leg["into"]][v]
        elif leg.get("kind") == "indexList": out[leg["field"]] = [sf[leg["into"]][i] for i in v]
        else: out[leg.get("field", k)] = v
    print(naid, json.dumps(out, ensure_ascii=False))
pre = [n for n, r in sf["byNaId"].items() if r.get("y1", 9999) < 1940]
pre0 = [n for n, r in sf["byNaId"].items() if r.get("y0", 9999) < 1940]
print("series ending before 1940:", len(pre), "; starting before 1940:", len(pre0), "; memo: 11 of 695")
# central-files-index for the three lots
cf = json.load(open(R+"central-files-index.json"))
print("\ncentral-files-index keys:", list(cf.keys())[:20])
def find(o, needle, path="", hits=None, depth=0):
    if hits is None: hits = []
    if len(hits) > 6 or depth > 6: return hits
    if isinstance(o, dict):
        for k, v in o.items():
            if needle in str(k): hits.append((path+"/"+str(k), json.dumps(v, ensure_ascii=False)[:500]))
            find(v, needle, path+"/"+str(k), hits, depth+1)
    elif isinstance(o, list):
        for i, v in enumerate(o[:50000]):
            if isinstance(v, (dict, list)): find(v, needle, path+f"[{i}]", hits, depth+1)
            elif needle in str(v): hits.append((path+f"[{i}]", str(v)[:200]))
    return hits
for lot in ["65D438","74D272","81D113"]:
    print("\n--", lot)
    for p, s in find(cf, lot)[:4]: print("  ", p, "=>", s[:500])
