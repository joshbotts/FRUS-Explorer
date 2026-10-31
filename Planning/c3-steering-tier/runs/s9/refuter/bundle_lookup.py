import json, re
RES="/Applications/FRUS Explorer.app/Contents/Resources"
cf=json.load(open(RES+"/central-files-index.json")); sf=json.load(open(RES+"/series-facts-index.json"))
lc=json.load(open(RES+"/lot-claimants-index.json")); pl=json.load(open(RES+"/presidential-library-catalog.json"))
ca=json.load(open(RES+"/collection-authority.json"))
print("central-files generated", cf.get("generated"), "| series-facts generated", sf.get("generated"), "| pres-lib generated", pl.get("generated") if isinstance(pl,dict) else None, "| lot-claimants keys", list(lc.keys())[:6], "| collection-authority keys", list(ca.keys())[:8])
def facts(na):
    r=sf["byNaId"].get(str(na))
    if not r: return None
    o={}
    for k,spec in sf["legend"]["keys"].items():
        if k not in r: continue
        v=r[k]
        if spec["kind"]=="index": v=sf[spec["into"]][v]
        elif spec["kind"]=="indexList": v=[sf[spec["into"]][i] for i in v]
        o[spec["field"]]=v
    return o
print("series-facts legend:", json.dumps(sf["legend"], ensure_ascii=False)[:1200])
print("\n=== central-files-index lotFiles rows for the lots ===")
for lot in ["66D193","81D134","91D414","63D351","66D95","62D430","62D1","54D270","59D95"]:
    rows=[r for r in cf["lotFiles"] if r.get("lotNumber")==lot]
    print("==",lot,"rows:",len(rows))
    for r in rows:
        print("  RG",r.get("recordGroup"),"| naId",r.get("naId"),"| entry",r.get("hmsMlrEntryNumbers"),"|",r.get("title"),"|",r.get("matchType"),"| dates",r.get("inclusiveDates") or r.get("dates"))
        print("   facts:", json.dumps(facts(r.get("naId")), ensure_ascii=False)[:700])
print("\n=== series-facts for NAIDs the overview names ===")
for na in [2131131,26309177,2658382,2839192,2839191,2838992,646663,594320960,2839193]:
    print(na, "->", json.dumps(facts(na), ensure_ascii=False)[:700])
print("\n=== lot-claimants for lots ===")
claim={l.get("lotNumber"):l for l in lc["lots"]}
for lot in ["66D193","81D134","91D414","63D351","66D95","62D430","62D1"]:
    l=claim.get(lot)
    print("==",lot,":", json.dumps(l, ensure_ascii=False)[:600] if l else "no row")
print("\n=== presidential-library-catalog ===")
s=json.dumps(pl, ensure_ascii=False)
print("top:", type(pl), list(pl.keys())[:8] if isinstance(pl,dict) else len(pl))
for needle in ["646663","Oksenberg","International Economic Affairs Staff"]:
    for m in re.finditer(re.escape(needle), s):
        print(needle, "...", s[max(0,m.start()-250):m.end()+200].replace("\n"," "))
        break
    else: print(needle, "-> NOT FOUND in presidential-library-catalog.json")
# walk for library names
def walk(o, path=""):
    if isinstance(o, dict):
        for k,v in o.items(): yield from walk(v, path+"/"+k)
    elif isinstance(o, list):
        for i,v in enumerate(o): yield from walk(v, path+f"[{i}]")
    else: yield path, o
carter=[(p,v) for p,v in walk(pl) if isinstance(v,str) and ("Carter" in v)]
print("Carter mentions:", len(carter), carter[:6])
print("\n=== collection-authority: Central Decimal File / CFPF / Entry 5403 ===")
s2=json.dumps(ca, ensure_ascii=False)
for needle in ["Entry 5403","91D414","91 D 414","Central Decimal File","Central Foreign Policy File"]:
    hits=[m.start() for m in re.finditer(re.escape(needle), s2)]
    print(needle, "hits:", len(hits))
    for h in hits[:2]: print("   ...", s2[max(0,h-300):h+250].replace("\n"," "))
