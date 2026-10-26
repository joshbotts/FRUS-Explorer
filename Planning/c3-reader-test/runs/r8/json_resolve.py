import json,re,collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
out={}
# --- decimal class labels, gated on glossableYears
dcl=json.load(open(R+"decimal-class-labels.json"))
cov=dcl["coverage"]; print("glossableYears:",cov["glossableYears"]); print("renumberedAt:",cov["renumberedAt"]); print("keyOutside:",str(cov["keyOutsideGlossableYears"])[:200]); print("notShipped:",str(cov["notShipped"])[:300])
for i,s in enumerate(dcl["schedules"]): print("schedule",i,"keys:",list(s.keys()), {k:(str(v)[:150]) for k,v in s.items() if k!="classes" and k!="countries" and k!="countryNumbers"})
out["decimal_coverage"]=cov
sch=dcl["schedules"]
def gloss(key,year):
    cls,rest=key.split(".",1) if "." in key else (key,"")
    for s in sch:
        y0,y1=s.get("years",[None,None]) if isinstance(s.get("years"),list) else (s.get("from"),s.get("to"))
        try:
            if y0 and y1 and not (int(y0)<=year<=int(y1)): continue
        except: pass
        c=s.get("classes",{}); countries=s.get("countries") or s.get("countryNumbers") or {}
        if cls[0] in c:
            cn=cls[1:]; cname=countries.get(cn) if isinstance(countries,dict) else None
            return f"{c[cls[0]]} / country {cn}={cname} / subclass .{rest}"
    return None
keys=[("812.00",1913),("837.00",1933),("818.00",1917),("816.01",1932),("824.00",1944),("814.00",1920),("823.00",1930),("839.00",1916),("835.00",1944),("831.01",1945),("710.11",1936)]
for k,y in keys: print("gloss",k,y,"->",gloss(k,y))
# --- central files index: the decimal file series and the lots
cfi=json.load(open(R+"central-files-index.json"))
print("numericalFile:",{k:(str(v)[:200]) for k,v in cfi["numericalFile"].items()})
want={"63D127","64D16","65D330","66D95","71F154","82D100","66D149","84D241"}
for row in cfi["lotFiles"]:
    if row.get("lotNumber") in want: print("LOT",row["lotNumber"],"| RG",row.get("recordGroup"),"| NAID",row.get("naId"),"| entry",row.get("hmsMlrEntryNumbers"),"|",row.get("title","")[:90],"|",row.get("matchType"))
found={r["lotNumber"] for r in cfi["lotFiles"] if r.get("lotNumber") in want}; print("lots not in central-files-index:",sorted(want-found))
# --- series facts: central decimal / central foreign policy files
sf=json.load(open(R+"series-facts-index.json")); leg=sf["legend"]; print("legend:",json.dumps(leg)[:900])
keys_map=leg["keys"]
def expand(row):
    d={}
    for k,v in row.items():
        m=keys_map.get(k,{}) if isinstance(keys_map,dict) else {}
        name=m.get("name",k) if isinstance(m,dict) else m
        into=m.get("into") if isinstance(m,dict) else None
        if into and into in sf:
            if isinstance(v,list): v=[sf[into][i] for i in v]
            elif isinstance(v,int): v=sf[into][v]
        d[name]=v
    return d
hits=[]
for naid,row in sf["byNaId"].items():
    e=expand(row); t=json.dumps(e)
    if re.search(r"Central Decimal|Central Foreign Policy|Decimal File|Subject-Numeric|Numerical File",t,re.I): hits.append((naid,e))
print("series-facts rows naming the central files:",len(hits))
for naid,e in hits[:20]: print("  ",naid,json.dumps(e)[:330])
out["series_facts_central"]=[(n,e) for n,e in hits]
# --- presidential libraries
pl=json.load(open(R+"presidential-library-catalog.json"))
for lib in pl["libraries"]:
    if lib["citedAs"] in ("Nixon Library","Carter Library","Johnson Library","Kennedy Library","Eisenhower Library"):
        for c in lib["collections"]:
            if re.search(r"National Security|NSC|Whitman|Brzezinski",c.get("title","")+" ".join(s.get("title","") for s in c.get("series",[])),re.I):
                print("LIB",lib["citedAs"],"| coll",c.get("identifier"),c.get("naId"),c.get("title","")[:70],"| series",[(s["title"][:40],s.get("naId"),s.get("inclusiveDates")) for s in c.get("series",[]) if re.search(r"National Security|NSC|Country|Subject",s.get("title",""))][:4])
json.dump(out,open("json_resolve.out.json","w"),indent=1)
