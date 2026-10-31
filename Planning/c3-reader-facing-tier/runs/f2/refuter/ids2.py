import json,re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SF=json.load(open(R+"series-facts-index.json"))
print("statuses:",SF.get("statuses")); print("useRestrictions:",SF.get("useRestrictions")); print("referenceUnits:",SF.get("referenceUnits")[:3] if SF.get("referenceUnits") else None)
for n in ["40967285","1257679","2839191","1487627"]:
    r=SF["byNaId"][n]; st=SF.get("statuses") or []
    print(n,"accessStatus:",st[r["as"]] if r.get("as") is not None and r["as"]<len(st) else r.get("as"),"| useStatus:",st[r["us"]] if r.get("us") is not None and r["us"]<len(st) else r.get("us"),"| access restrictions:",[SF["restrictions"][i] for i in r.get("ar",[])],"| extent:",r.get("x"),"| years:",r.get("y0"),r.get("y1"))
P=json.load(open(R+"presidential-library-catalog.json"))
col=P["libraries"][4]["collections"][394]; print("\nJFK collections[394]:",json.dumps({k:v for k,v in col.items() if k!="series"},ensure_ascii=False)[:300],"| series:",[(s.get("naId"),s.get("title"),s.get("inclusiveDates")) for s in col.get("series",[])][:5])
print("\nFord library titles matching Advis/Adviser/Scowcroft/NSA:")
for c in P["libraries"][7]["collections"]:
    if re.search(r"Advis|Scowcroft|\bNSA\b",c.get("title",""),re.I): print("  ",c.get("identifier"),c.get("naId"),c["title"][:100],c.get("statedSeriesCount"))
    for s in c.get("series",[]):
        if re.search(r"Advis",s.get("title",""),re.I): print("     series in",c.get("identifier"),s.get("naId"),s["title"][:100],s.get("inclusiveDates"))
print("\nNixon library collection titles (all 212, first 60 chars) containing NSC/National Security/White House Central/Kissinger:")
for c in P["libraries"][6]["collections"]:
    if re.search(r"National Security|NSC|White House Central|Kissinger",c.get("title",""),re.I):
        print("  ",c.get("identifier"),c.get("naId"),c["title"][:90],"| series:",[(s.get("naId"),s["title"][:60],s.get("inclusiveDates")) for s in c.get("series",[])][:6])
print("\nKennedy JFK-4 series (first 20):")
for c in P["libraries"][4]["collections"]:
    if c.get("identifier")=="JFK-4": print("  ",c.get("naId"),c["title"]); [print("     ",s.get("naId"),s["title"][:80],s.get("inclusiveDates")) for s in c.get("series",[])[:20]]
CA=json.load(open(R+"collection-authority.json"))
for c in CA["collections"]:
    if c.get("id") in ("lot:81D113","lot:62D430"): print("\ncollection-authority",c["id"],"naId",c.get("naId"),"rg",c.get("recordGroup"),"name",c.get("name")[:80],"| volumes:",len(c.get("volumeIds",[])))
D=json.load(open(R+"decimal-class-labels.json"))
print("\ndecimal-class-labels top keys:",list(D.keys())[:10])
def find(o,path,depth=0):
    if depth>6: return
    if isinstance(o,dict):
        for k,v in o.items():
            if str(k) in ("90","96") and isinstance(v,(str,dict)): print("  ",path+"/"+k,"=",json.dumps(v,ensure_ascii=False)[:160])
            if str(k) in ("6","7") and isinstance(v,(str,dict)) and "class" in path.lower(): print("  ",path+"/"+k,"=",json.dumps(v,ensure_ascii=False)[:160])
            find(v,path+"/"+str(k),depth+1)
find(D,"")
