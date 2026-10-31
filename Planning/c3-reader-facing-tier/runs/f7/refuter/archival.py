import json,re,sqlite3
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json"))
sf=json.load(open(R+"series-facts-index.json"))
ca=json.load(open(R+"collection-authority.json"))
vs=json.load(open(R+"volume-sources-index.json"))
pl=json.load(open(R+"presidential-library-catalog.json"))
cu=json.load(open(R+"collection-usage-index.json"))
curated=json.load(open(R+"curated-lot-resolutions.json"))
def lotnorm(s): return re.sub(r"\s+","",s.upper())
lots={}
for l in cf["lotFiles"]:
    lots.setdefault(lotnorm(l.get("lotNumber","")),[]).append(l)
print("central-files lotFiles:",len(cf["lotFiles"]),"distinct lot keys:",len(lots))
print("sample lotFile keys:",list(cf["lotFiles"][0].keys()))
def sfrow(naid):
    r=sf["byNaId"].get(str(naid))
    if not r: return None
    L=sf["legend"]["keys"]
    out={}
    for k,v in r.items():
        spec=L.get(k,{})
        into=spec.get("into")
        if spec.get("kind")=="index" and into: out[spec["field"]]=sf[into][v]
        elif spec.get("kind")=="indexList" and into: out[spec["field"]]=[sf[into][i] for i in v]
        else: out[spec.get("field",k)]=v
    return out
print("series-facts byNaId count:",len(sf["byNaId"]),"legend fields:",{k:v.get("field") for k,v in sf["legend"]["keys"].items()})
for lot in ["61D167","61D385","65F98","84D204","78D295","78D184","66D95","63D351","58D726"]:
    rows=lots.get(lot,[])
    print(f"\nLOT {lot}: {len(rows)} row(s) in central-files-index")
    for l in rows:
        print("   naId",l.get("naId"),"RG",l.get("recordGroup"),"title:",l.get("title"),"| entry",l.get("hmsMlrEntryNumbers"),"| match",l.get("matchType"),"| dates",l.get("inclusiveDates") or l.get("dateRange"),"| creator",l.get("creator") or l.get("creatingOrganization"))
        print("   series-facts:",sfrow(l.get("naId")))
    print("   curated:",[c for c in (curated if isinstance(curated,list) else curated.get("resolutions",curated.get("lots",[]))) if isinstance(c,dict) and lotnorm(json.dumps(c)).find(lot)>=0][:2])
for naid in ["2198167","27022973","5038052","2839192","1254251","7542975","2544398"]:
    print(f"\nNAID {naid}: series-facts:",sfrow(naid))
    hits=[l for l in cf["lotFiles"] if str(l.get("naId"))==naid]
    print("   central-files rows:",[(l.get("lotNumber"),l.get("title"),l.get("recordGroup"),l.get("hmsMlrEntryNumbers")) for l in hits])
print("\nRECORD GROUPS in volume-sources-index:",sorted(vs["recordGroups"].keys()))
for rg in ["59","306","305","84"]:
    print("  RG",rg,":",vs["recordGroups"].get(rg))
print("\nPRESIDENTIAL LIBRARY CATALOG:")
for lib in pl["libraries"]:
    names=[c.get("title") or c.get("name") for c in lib["collections"]]
    want=[n for n in names if n and re.search(r"Robert F\. Kennedy|National Security File|Marks|NSC Files|National Security Council",n)]
    print("  ",lib["citedAs"],"collections:",len(names),"| matches:",want[:6])
print("  sample collection keys:",list(pl["libraries"][0]["collections"][0].keys()))
print("\nCOLLECTION AUTHORITY matches:")
for pat in [r"Robert F\. Kennedy",r"^Marks Papers|Marks Papers",r"National Security File\b",r"NSC Files",r"Director.s Subject Files",r"Office of Policy and Plans",r"Executive Secretariat",r"Records of the USIA|Office of the Director"]:
    hits=[c for c in ca["collections"] if re.search(pat,c["name"]) or any(re.search(pat,a) for a in c.get("aliases",[]))]
    print(f"  /{pat}/ -> {len(hits)}:",[(h["id"],h["name"][:70],h.get("repository")) for h in hits[:5]])
# USIA creator headings in series-facts
usia=[i for i,h in enumerate(sf["headings"]) if "Information Agency" in h or "U.S. Information" in h or "United States Information" in h]
print("\nUSIA creator headings:",[sf["headings"][i] for i in usia])
rows=[(n,r) for n,r in sf["byNaId"].items() if r.get("c") in usia]
print("series with a USIA creator heading:",len(rows))
print("series before 1940 (y0<1940):",sum(1 for n,r in sf["byNaId"].items() if r.get("y0") and r["y0"]<1940),"of",len(sf["byNaId"]),"; with cy0<1940:",sum(1 for n,r in sf["byNaId"].items() if r.get("cy0") and r["cy0"]<1940))
print("series with y1<1940:",sum(1 for n,r in sf["byNaId"].items() if r.get("y1") and r["y1"]<1940))
# entries in the 33 documents' source notes
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
db=sqlite3.connect(f"file:{DB}?mode=ro",uri=True)
coll=json.load(open("/Users/jbotts/frus-analysis/c3f/runs/f7/collection.fruscollection"))
docs=[(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"]
print("\nDOCUMENT_SOURCES for the 33 (record_group, repository, era, lot, series) + Entry strings in source_note:")
import collections
tally=collections.Counter()
for v,d in docs:
    r=db.execute("select record_group,repository,citation_era,lot_file_norm,series_name from document_sources where volume_id=? and document_id=?",(v,d)).fetchone()
    sn=db.execute("select source_note from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()[0] or ""
    ents=re.findall(r"Entry\s+[A-Z0-9–\-– ]+?(?=,|\.|;|$)",sn)
    print(f"  {v}/{d}: {r} | entries: {ents} | {sn[:160]}")
    tally[(r[0],r[2])]+=1
print("tally (rg,era):",dict(tally))
