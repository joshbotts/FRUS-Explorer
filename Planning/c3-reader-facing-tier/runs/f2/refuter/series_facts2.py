import json,re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
naids=["40967285","1257679","2839191","193936","50827304","50809179","1487627","1127750","721251","1257657"]
A=json.load(open(R+"accession-series-index.json"))
print("== accession-series-index entries holding each NAID (key = rg/accession) ==")
for n in naids:
    hits=[(key,s.get("t"),s.get("a"),len(lst)) for key,lst in A["byAccession"].items() for s in lst if str(s.get("n"))==n]
    print(n,"->",hits)
print("306/72A5121 count:",len(A["byAccession"].get("306/72A5121",[])),"| 306/72A5121C count:",len(A["byAccession"].get("306/72A5121C",[])),"| keys starting 306/72A5121:",[k for k in A["byAccession"] if k.startswith("306/72A5121")])
print("306/69A3445 count:",len(A["byAccession"].get("306/69A3445",[])),[ (s["n"],s["t"]) for s in A["byAccession"].get("306/69A3445",[])][:12])
print("\n== presidential-library-catalog ==")
P=json.load(open(R+"presidential-library-catalog.json"))
for i,lib in enumerate(P["libraries"]): print(i,json.dumps({k:v for k,v in lib.items() if k!="collections"},ensure_ascii=False)[:160],"| collections:",len(lib.get("collections",[])))
def search(lib,pat):
    out=[]
    for col in lib["collections"]:
        if re.search(pat,col.get("title",""),re.I): out.append((col.get("identifier"),col.get("naId"),col["title"][:70],col.get("statedSeriesCount")))
        for s in col.get("series",[]):
            if re.search(pat,s.get("title",""),re.I): out.append(("  series in "+str(col.get("identifier")),s.get("naId"),s["title"][:70],s.get("inclusiveDates")))
    return out
for i,lib in enumerate(P["libraries"]):
    nm=json.dumps({k:v for k,v in lib.items() if k!="collections"},ensure_ascii=False)[:50]
    for pat,lab in [(r"National Security Files?","NSF"),(r"White House Central Files","WHCF"),(r"National Security Council|\bNSC\b","NSC"),(r"National Security Advis","NSA"),(r"Kissinger","Kissinger"),(r"Marks","Marks"),(r"Robert F\. Kennedy","RFK")]:
        h=search(lib,pat)
        if h: print("lib",i,nm,"|",lab,"->",len(h),"hits:",h[:5])
print("\n== lot-claimants 62D430 / 81D113 ==")
L=json.load(open(R+"lot-claimants-index.json"))
print("lots sample keys:",list(L["lots"][0].keys()))
for lot in L["lots"]:
    js=json.dumps(lot,ensure_ascii=False)
    if '"62D430"' in js or '"81D113"' in js or lot.get("lot") in ("62D430","81D113") or lot.get("lotFileNorm") in ("62D430","81D113"):
        print(json.dumps({k:v for k,v in lot.items() if k!="claimants"},ensure_ascii=False)[:200])
        for cl in lot.get("claimants",[]): print("    ",json.dumps(cl,ensure_ascii=False)[:220])
print("\n== central-files-index lotFiles rows for 62D430, 81D113, 63D351 ==")
C=json.load(open(R+"central-files-index.json"))
for row in C["lotFiles"]:
    if row.get("lotNumber") in ("62D430","81D113","63D351"): print(json.dumps(row,ensure_ascii=False)[:300])
print("\n== volume-sources-index recordGroups 306 / 59 / 305 ==")
V=json.load(open(R+"volume-sources-index.json"))
print("recordGroups type",type(V["recordGroups"]).__name__, "sample:",json.dumps(V["recordGroups"][:2] if isinstance(V["recordGroups"],list) else list(V["recordGroups"].items())[:2],ensure_ascii=False)[:600])
for rg in (V["recordGroups"] if isinstance(V["recordGroups"],list) else [dict(k=k,**v) if isinstance(v,dict) else {"k":k,"v":v} for k,v in V["recordGroups"].items()]):
    js=json.dumps(rg,ensure_ascii=False)
    if re.search(r'"(recordGroup|key|k|rg)": ?"?(306|59|305)"?',js) or re.search(r'RG ?(306|59|305)\b',js): print(js[:260])
