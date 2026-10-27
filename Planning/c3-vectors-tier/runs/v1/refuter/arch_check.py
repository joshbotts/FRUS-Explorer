# Refuter: the bottom line's second paragraph's archival identifiers against the bundled JSON and the index rows.
import json, sqlite3, re, collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ci=json.load(open(R+"central-files-index.json")); sf=json.load(open(R+"series-facts-index.json")); lc=json.load(open(R+"lot-claimants-index.json"))
print("central-files-index keys:",list(ci.keys()))
print("series-facts keys:",list(sf.keys()))
print("lot-claimants keys:",list(lc.keys()), "lots[0] keys:", list(lc["lots"][0].keys()))
lots=collections.defaultdict(list)
for r in ci["lotFiles"]: lots[r["lotNumber"]].append(r)
print("lotFiles rows:",len(ci["lotFiles"]),"lotFiles[0] keys:",list(ci["lotFiles"][0].keys()))
st=sf["statuses"]; hd=sf["headings"]
print("statuses:",st)
claims=collections.defaultdict(list)
for r in lc["lots"]: claims[r.get("lotNumber")].append(r)
want={"65D438":("Missile Crisis","A1 3053","27022950","1962–1963","Restricted - Partly"),
      "64D199":("Memcons","A1 1566","602231","1953–1964","Unrestricted"),
      "65D330":("Memcons","A1 1566","602231","1953–1964","Unrestricted"),
      "62D24":("Special Assistant on Communism","A1 3148","2363836","1958–1961","Restricted - Partly"),
      "66D501":("Mongoose","UD-UP 293-B","648748","1963–1965","Unrestricted"),
      "66D95":("NSC Policy Papers","A1 1586E","2839192","1947–1979","Restricted - Partly"),
      "65D212":("Sugar","UD-UP 215","27022874","1955–1962 cov 1932","Restricted - Fully")}
for lot,(label,entry,naid,yrs,acc) in want.items():
    print("\n==",lot,label,"| overview says entry",entry,"NAID",naid,yrs,acc)
    for r in lots.get(lot,[]):
        f=sf["byNaId"].get(str(r["naId"])) or sf["byNaId"].get(r["naId"])
        print("  lotFiles:",json.dumps({k:r[k] for k in r if k in ("lotNumber","title","naId","hmsMlrEntryNumbers","recordGroup","creator","bureau","office")},ensure_ascii=False))
        if f: print("  series-facts:",json.dumps(f),"| creator heading:",hd[f["c"]] if "c" in f else None,"| access:",st[f["as"]] if "as" in f else None)
        else: print("  series-facts: none for NAID",r["naId"])
    if not lots.get(lot): print("  NOT in lotFiles")
    for cr in claims.get(lot,[]): print("  lot-claimants:",json.dumps(cr,ensure_ascii=False)[:600])
# decimal class labels
dl=json.load(open(R+"decimal-class-labels.json"))
print("\ndecimal-class-labels keys:",list(dl.keys()))
print("coverage:",json.dumps(dl.get("coverage"))[:800])
def find(o,path=""):
    # print entries naming Cuba / country 37 and class 8 subjects 00, 51, 61351
    if isinstance(o,dict):
        for k,v in o.items():
            if isinstance(v,str) and ("Cuba" in v or k in ("37",)) and len(path)<80: print("  ",path+"/"+k,"=",v[:80])
            find(v,path+"/"+k)
    elif isinstance(o,list):
        for i,v in enumerate(o[:5000]): find(v,path+"[%d]"%i)
find(dl)
for k in dl:
    v=dl[k]
    if isinstance(v,dict): print(k,"dict keys sample:",list(v.keys())[:12])
    elif isinstance(v,list): print(k,"list len",len(v),"first:",json.dumps(v[0])[:300])
