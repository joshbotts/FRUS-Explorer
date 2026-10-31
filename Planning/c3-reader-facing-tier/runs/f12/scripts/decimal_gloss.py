# decimal-class-labels.json: read coverage gate, then try to gloss the scope's decimal files (doc dates 1950-03-28, 1953-09-14, 1953-12-07/09, 1962-09-14)
import json
j=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/decimal-class-labels.json"))
print(list(j.keys()))
cov=j.get("coverage",{}); print("glossableYears",cov.get("glossableYears")); print("keyOutside",str(cov.get("keyOutsideGlossableYears"))[:300])
for k in list(j.keys()):
    if k not in("coverage",): print(k, type(j[k]).__name__, str(j[k])[:300])
print("---- schedule shapes")
for s in j["schedules"]:
    print(s.get("id") or s.get("scheduleId"), list(s.keys()))
def sched(y):
    for g in j["coverage"]["glossableYears"]:
        if g["startYear"]<=y<=g["endYear"]: return g["scheduleId"]
for key,year in [("511.90",1950),("790.5",1953),("792.5",1953),("611.98",1962)]:
    sid=sched(year); s=[x for x in j["schedules"] if (x.get("id") or x.get("scheduleId"))==sid][0]
    cls=key[0]; rest=key.split(".")
    cc=key[1:3]
    print(key,year,sid,"class",cls,"=",s["classes"].get(cls),"| country",cc,"=",(s.get("countries") or {}).get(cc) if isinstance(s.get("countries"),dict) else "see keys", "| sub",rest[1] if len(rest)>1 else "")
