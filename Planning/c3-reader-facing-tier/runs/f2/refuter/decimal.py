import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
D=json.load(open(R+"decimal-class-labels.json"))
print("coverage:",json.dumps(D["coverage"],ensure_ascii=False)[:600])
S=D["schedules"]; print("schedules type",type(S).__name__, "keys/len:", list(S.keys())[:10] if isinstance(S,dict) else len(S))
items=S.items() if isinstance(S,dict) else enumerate(S)
for k,sch in items:
    print("\nschedule",k,"| keys:",list(sch.keys())[:12] if isinstance(sch,dict) else type(sch))
    if isinstance(sch,dict):
        for kk in sch:
            v=sch[kk]
            if isinstance(v,dict):
                print("   ",kk,"-> dict",len(v),"| sample:",json.dumps(dict(list(v.items())[:2]),ensure_ascii=False)[:200])
                for want in ("90","96","6","7","790","696","790.5","696.00"):
                    if want in v: print("      [%s] %s = %s"%(kk,want,json.dumps(v[want],ensure_ascii=False)[:200]))
            elif isinstance(v,list): print("   ",kk,"-> list",len(v),"| sample:",json.dumps(v[:2],ensure_ascii=False)[:200])
            else: print("   ",kk,"=",json.dumps(v,ensure_ascii=False)[:120])
