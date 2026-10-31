import json,re
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(RES+"central-files-index.json"))
print("central-files keys:",list(cf.keys()))
lots=cf.get("lotFiles")
print("lotFiles type",type(lots).__name__,"len",len(lots))
def fold(s): return re.sub(r'\s+','',s or '')
want={"63D351","69D260","93D82","53D413","66D95","71D273","60D627","54D270"}
found={}
items=lots if isinstance(lots,list) else list(lots.values())
if items: print("sample lot row keys:",list(items[0].keys()))
for row in items:
    ln=fold(row.get("lotNumber"))
    if ln in want: found.setdefault(ln,[]).append(row)
for ln in sorted(want):
    rs=found.get(ln)
    if not rs: print(ln,"-> NOT in lotFiles"); continue
    for r in rs: print(ln,"->",json.dumps(r)[:400])
sf=json.load(open(RES+"series-facts-index.json"))
print("\nseries-facts keys:",list(sf.keys()))
by=sf.get("byNaId") or {}
for naid in ["2839192","27022536","2225592","2127212","1257679","5634081","40967113","40967285","2839193"]:
    print(naid,"->",json.dumps(by.get(naid))[:400])
pl=json.load(open(RES+"presidential-library-catalog.json"))
print("\npres-lib keys:",list(pl.keys()))
txt=json.dumps(pl)
for naid in ["567979","1164","50809179","1104"]:
    m=[x for x in re.finditer(r'"naId":\s*"?%s"?'%naid,txt)]
    print(naid,"occurrences:",len(m), (txt[max(0,m[0].start()-250):m[0].start()+60].replace("\n"," ") if m else ""))
vs=json.load(open(RES+"volume-sources-index.json"))
t=json.dumps(vs)
print("\nvolume-sources RG 306 mentions:",len(re.findall(r'Record Group 306|RG ?306',t)))
for e in ["UD WW 257","UD WW 193","A1-42","A1 42","P-104","P 104","P-142","P 142","1257679"]:
    print("  ",e,"in volume-sources:",e in t, "| in series-facts:",e in json.dumps(sf), "| in central-files:", e in json.dumps(cf))
ec=json.load(open(RES+"external-citation-index.json"))
print("\nexternal-citation-index keys:",list(ec.keys())[:12])
lc=json.load(open(RES+"lot-claimants-index.json"))
for l in lc.get("lots",[]):
    if fold(l.get("lotNumber")) in ("66D95","63D351","69D260","93D82","53D413"): print("claimants",l.get("lotNumber"),[(c.get("naId"),c.get("title")) for c in l.get("claimants",[])])
