import json,re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
SF=json.load(open(R+"series-facts-index.json"))
print("legend:",json.dumps(SF["legend"],ensure_ascii=False)[:1500])
print("restrictions:",json.dumps(SF["restrictions"],ensure_ascii=False)[:600])
print("findingAidTypes:",json.dumps(SF["findingAidTypes"],ensure_ascii=False)[:300])
H=SF["headings"]
naids=["40967285","1257679","2839191","193936","50827304","50809179","1487627","1127750","721251","1257657"]
print("\n== series-facts byNaId rows ==")
for n in naids:
    r=SF["byNaId"].get(n)
    if not r: print(n,"-> NO ROW"); continue
    creator=H[r["c"]] if isinstance(r.get("c"),int) and r["c"]<len(H) else r.get("c")
    print(n,"->",json.dumps(r,ensure_ascii=False)[:300]); print("     creator heading:",creator)
print("\n== accession-series-index entries holding each NAID ==")
A=json.load(open(R+"accession-series-index.json"))
print("legend:",json.dumps(A["legend"],ensure_ascii=False)[:600]); print("note:",str(A["note"])[:400])
for n in naids:
    hits=[]
    for rg,accs in A["byAccession"].items():
        for acc,lst in accs.items():
            for s in lst:
                if str(s.get("n"))==n: hits.append((rg,acc,s.get("t"),s.get("a"),len(lst)))
    print(n,"->",hits)
print("\n== presidential-library-catalog: libraries and title searches for the 'not resolved' collections ==")
P=json.load(open(R+"presidential-library-catalog.json"))
for i,lib in enumerate(P["libraries"]): print(i,{k:v for k,v in lib.items() if k!="collections"},"collections:",len(lib.get("collections",[])))
def search(libidx,pat):
    out=[]
    for col in P["libraries"][libidx]["collections"]:
        if re.search(pat,col.get("title",""),re.I): out.append((col.get("identifier"),col.get("naId"),col["title"],col.get("statedSeriesCount")))
        for s in col.get("series",[]):
            if re.search(pat,s.get("title",""),re.I): out.append(("  series of "+str(col.get("identifier")),s.get("naId"),s["title"],s.get("inclusiveDates")))
    return out
libs={l.get("name") or l.get("identifier") or l.get("library"):i for i,l in enumerate(P["libraries"])}
print(libs)
for i,lib in enumerate(P["libraries"]):
    nm=json.dumps({k:v for k,v in lib.items() if k!="collections"})
    for pat,lab in [(r"National Security Files?","Kennedy NSF"),(r"White House Central Files","Nixon WHCF"),(r"National Security Council|NSC","NSC Files"),(r"National Security Advis","Ford NSA"),(r"Kissinger","Kissinger"),(r"Marks","Marks"),(r"Robert F\. Kennedy","RFK")]:
        h=search(i,pat)
        if h: print("lib",i,nm[:60],"|",lab,"->",len(h),"hits; first 4:",h[:4])
print("\n== lot-claimants 81D113 ==")
L=json.load(open(R+"lot-claimants-index.json"))
for lot in L["lots"]:
    if lot.get("lot") in ("81D113","62D430") or lot.get("lotFileNorm") in ("81D113","62D430") or "81D113" in json.dumps(lot) or "62D430" in json.dumps(lot):
        print(json.dumps({k:v for k,v in lot.items() if k!="claimants"},ensure_ascii=False)[:200]); 
        for cl in lot.get("claimants",[]): print("    ",json.dumps(cl,ensure_ascii=False)[:220])
