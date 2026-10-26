import json, re, sqlite3
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cfi=json.load(open(R+"central-files-index.json"))
print("numericalFile:",json.dumps(cfi["numericalFile"],ensure_ascii=False)[:1200])
want={"63D127","64D16","65D330","66D95","71F154","82D100","66D149","84D241"}
print("\nlotFiles rows for the named lots:")
for row in cfi["lotFiles"]:
    if row.get("lotNumber") in want:
        print(json.dumps({k:row[k] for k in row if k in ("lotNumber","recordGroup","naId","hmsMlrEntryNumbers","title","creator","inclusiveDates","dateRange","matchType","accessRestriction","office","entryNumbers")},ensure_ascii=False))
        extra=[k for k in row if k not in ("lotNumber","recordGroup","naId","hmsMlrEntryNumbers","title","creator","inclusiveDates","dateRange","matchType","accessRestriction","office","entryNumbers")]
        print("    other keys:",extra)
found={r["lotNumber"] for r in cfi["lotFiles"] if r.get("lotNumber") in want}; print("not found:",sorted(want-found))
dups={}
for r in cfi["lotFiles"]:
    if r.get("lotNumber") in want: dups[r["lotNumber"]]=dups.get(r["lotNumber"],0)+1
print("rows per lot:",dups)
sf=json.load(open(R+"series-facts-index.json")); leg=sf["legend"]; km=leg["keys"]
print("\nseries-facts legend:",json.dumps(leg,ensure_ascii=False)[:1500])
def expand(row):
    d={}
    for k,v in row.items():
        m=km.get(k,{}); name=m.get("field",k) if isinstance(m,dict) else m; into=m.get("into") if isinstance(m,dict) else None
        if into and into in sf:
            v=[sf[into][i] for i in v] if isinstance(v,list) else sf[into][v]
        d[name]=v
    return d
print("\nseries-facts byNaId rows:",len(sf["byNaId"]))
for naid in ["654171","2363840","1750062","602231","610077","2839192","27023004","26309182","26309216","1164","193236","567979","567985","560131","560151"]:
    r=sf["byNaId"].get(naid); print(naid, json.dumps(expand(r),ensure_ascii=False)[:600] if r else "NOT IN series-facts-index")
cnt=sum(1 for n,r in sf["byNaId"].items() if re.search(r"central decimal",json.dumps(expand(r)),re.I))
print("series-facts rows naming 'Central Decimal':",cnt,"of",len(sf["byNaId"]))
pl=json.load(open(R+"presidential-library-catalog.json"))
print("\npresidential-library-catalog libraries:",[l.get("citedAs") for l in pl["libraries"]])
for lib in pl["libraries"]:
    for c in lib.get("collections",[]):
        hit=any(str(x) in ("1164","193236","567979","567985","560131","560151") for x in (c.get("naId"),c.get("identifier")))
        shits=[s for s in c.get("series",[]) if str(s.get("naId")) in ("1164","193236","567979","567985","560131","560151")]
        if hit or shits:
            print("LIB",lib.get("citedAs"),"| collection",c.get("identifier"),c.get("naId"),repr(c.get("title"))[:90],c.get("inclusiveDates") or c.get("dateRange"))
            for s in shits: print("     series",s.get("naId"),repr(s.get("title"))[:80],s.get("inclusiveDates") or s.get("dateRange"))
    if lib.get("citedAs")=="Nixon Library" or "Nixon" in str(lib.get("citedAs")):
        print("NIXON collections:",[(c.get("naId"),c.get("title")[:50]) for c in lib.get("collections",[])][:20])
dcl=json.load(open(R+"decimal-class-labels.json"))
for s in dcl["schedules"]:
    print("\nschedule",s.get("scheduleId") or s.get("id"),"keys:",list(s.keys()))
    if (s.get("scheduleId") or s.get("id"))=="1910-1949":
        cl=s.get("classes"); print(" class 8:",cl.get("8") if isinstance(cl,dict) else cl)
        co=s.get("countries") or s.get("countryNumbers"); 
        for n in ["12","37","18","16","24","14","23","39","35","31"]: print("  country",n,"=",co.get(n) if isinstance(co,dict) else None)
        sub=s.get("subclasses") or s.get("class8Subjects") or s.get("subjects")
        print(" subclass-like keys:",[k for k in s.keys() if k not in ("classes","countries","countryNumbers")])
        for k in s.keys():
            if k not in ("classes","countries","countryNumbers") and isinstance(s[k],dict):
                for kk in ("00","01",".00",".01","710.11","11"):
                    if kk in s[k]: print("   ",k,kk,"=",str(s[k][kk])[:120])
