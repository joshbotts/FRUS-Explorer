import json, sqlite3
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json")); sf=json.load(open(R+"series-facts-index.json"))
plc=json.load(open(R+"presidential-library-catalog.json")); ca=json.load(open(R+"collection-authority.json"))
vsi=json.load(open(R+"volume-sources-index.json")); eci=json.load(open(R+"external-citation-index.json"))
print("volume-sources-index keys:",list(vsi.keys())[:12]); print("external-citation-index keys:",list(eci.keys())[:12])
def facts(n):
    r=sf["byNaId"].get(str(n))
    if r is None: return None
    out={}
    for k,v in r.items():
        spec=sf["legend"]["keys"].get(k,{}); into=spec.get("into")
        if into and spec["kind"]=="index": v=sf[into][v]
        elif into and spec["kind"]=="indexList": v=[sf[into][i] for i in v]
        out[spec.get("field",k)]=v
    return out
print("\n== LOTS in central-files-index.json lotFiles ==")
for lot in ["81D113","62D26","63D351","66D95","62D1","79F80"]:
    hit=[r for r in cf["lotFiles"] if r.get("lotNumber")==lot]
    for r in hit: print(lot,"->",r["naId"],r["recordGroup"],r["hmsMlrEntryNumbers"],r["title"],"| facts:",json.dumps(facts(r["naId"]),ensure_ascii=False)[:260])
    if not hit: print(lot,"-> 0 rows")
print("\n== library NAIDs in presidential-library-catalog.json ==")
want={"1166":"JFK POF","1164":"JFK NSF","591194":"LBJ NSF Vietnam Country Files","23657995":"Tom Johnson Meeting Notes","572583":"Ford Pres. Correspondence w/ Foreign Leaders","568224":"Ford Pres. Country Files ME&SA","560131":"Carter NSA records","560151":"Brzezinski Country Files"}
found={}
for lib in plc["libraries"]:
    for c in lib["collections"]:
        if str(c["naId"]) in want: found[str(c["naId"])]=("COLLECTION",lib["citedAs"],c.get("identifier"),c["title"],c.get("inclusiveDates"))
        for s in c.get("series",[]):
            if str(s["naId"]) in want: found[str(s["naId"])]=("SERIES of "+str(c["naId"])+" "+c["title"],lib["citedAs"],s["title"],s.get("inclusiveDates"))
for k,v in want.items(): print(k,v,"->",found.get(k,"NOT FOUND"),"| series-facts:",facts(k))
# LBJ NSF Vietnam series: list series under 567979 containing Vietnam
for lib in plc["libraries"]:
    for c in lib["collections"]:
        if str(c["naId"])=="567979":
            print("LBJ-NSF series containing 'Vietnam':",[(s["naId"],s["title"],s.get("inclusiveDates")) for s in c["series"] if "vietnam" in s["title"].lower()])
        if str(c["naId"])=="560131":
            print("JC-NSA series containing 'Staff' or 'Country' or 'North/South':",[(s["naId"],s["title"],s.get("inclusiveDates")) for s in c["series"] if any(w in s["title"].lower() for w in ["staff","country","north/south","pastor"])][:12])
# Ford: NSC Operations Staff for the Middle East and South Asia (d50's real source), and Memoranda of Conversations
for lib in plc["libraries"]:
    if lib["citedAs"]=="Ford Library":
        for c in lib["collections"]:
            t=c["title"].lower()
            if "operations staff" in t or "memoranda of conversation" in t or "memcon" in t:
                print("FORD coll",c["naId"],c["title"],c.get("inclusiveDates"),[(s["naId"],s["title"]) for s in c.get("series",[])][:4])
print("\n== collection-authority.json: Central Decimal / Jidda / NSC Operations Staff ==")
for r in ca["collections"]:
    n=r.get("name","").lower()
    if any(k in n for k in ["central decimal","decimal central","jidda","operations staff","memoranda of conversation","kissinger papers"]):
        print("AUTH",json.dumps({k:r.get(k) for k in ["id","name","repository","naId","seriesNaId","recordGroup","entry","lotNumber"] if r.get(k) is not None},ensure_ascii=False)[:260])
print("authority records with a naId:",sum(1 for r in ca["collections"] if r.get("naId") or r.get("seriesNaId")),"of",len(ca["collections"]))
# does any authority record hold NAID 654171 or an entry for the CDF?
print("authority rows naming 'Central' with naId:",[(r["id"],r.get("naId"),r.get("seriesNaId")) for r in ca["collections"] if "central" in r.get("name","").lower() and (r.get("naId") or r.get("seriesNaId"))][:10])
print("central-files-index numericalFile.seriesNaId:",cf["numericalFile"].get("seriesNaId"),"facts:",facts(cf["numericalFile"].get("seriesNaId")))
# Jidda lot 79F80 in volume-sources-index / external-citation-index text?
s=json.dumps(vsi); e=json.dumps(eci)
print("'79F80' in volume-sources-index:", s.count("79F80"), "in external-citation-index:", e.count("79F80"), "in collection-authority:", json.dumps(ca).count("79F80"))
print("'Jidda' in volume-sources-index:", s.count("Jidda"))
