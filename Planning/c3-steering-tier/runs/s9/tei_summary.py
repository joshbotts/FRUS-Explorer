import json, collections
R="/Users/jbotts/frus-analysis/c3s/runs/s9"
recs=[json.loads(l) for l in open(R+"/tei_scan.jsonl")]
skip={"frus1951-54IranEd2","frus1969-76ve15p2Ed2"}
print("volumes scanned", len(recs), "| Ed2 dropped from totals:", sorted(skip))
recs=[r for r in recs if r["vol"] not in skip]
tot=collections.defaultdict(lambda: collections.Counter()); vols=collections.Counter()
for r in recs:
    for k,c in r["counts"].items():
        if c: vols[k]+=1
        for s,x in c.items():
            tot[k][s]+=x["n"]; tot[k][s+"_lower"]+=x["lower"]; tot[k][s+"_upper"]+=x["upper"]; tot[k][s+"_mixed"]+=x["mixed"]
print("%-26s %7s %7s %6s %6s | %6s %6s %6s | vols"%("variant","DOC","NOTE","FRONT","BACK","lower","Cap","UPPER"))
for k in json.loads(open(R+"/tei_scan.jsonl").readline())["counts"]:
    t=tot[k]; L=sum(t[s+"_lower"] for s in ("DOC","NOTE","FRONT","BACK")); U=sum(t[s+"_upper"] for s in ("DOC","NOTE","FRONT","BACK")); M=sum(t[s+"_mixed"] for s in ("DOC","NOTE","FRONT","BACK"))
    print("%-26s %7d %7d %6d %6d | %6d %6d %6d | %d of %d"%(k,t["DOC"],t["NOTE"],t["FRONT"],t["BACK"],L,M,U,vols[k],len(recs)))
