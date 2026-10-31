import json,re,sqlite3,os
R="/Applications/FRUS Explorer.app/Contents/Resources/"
def load(n): return json.load(open(R+n,encoding="utf-8"))
cf=load("central-files-index.json"); print("central-files-index keys:",list(cf.keys()))
lots={r["lotNumber"]:r for r in cf["lotFiles"]}
print("lotFiles count",len(lots))
for lot in ["63D351","62D430","66D95","62D1","54D270","59D95"]:
    r=lots.get(lot)
    print("LOT",lot,"->", json.dumps({k:r.get(k) for k in ("title","recordGroup","naId","hmsMlrEntryNumbers","matchType","levelOfDescription","dateRange","inclusiveDates")},ensure_ascii=False) if r else "ABSENT from lotFiles")
lc=load("lot-claimants-index.json"); print("lot-claimants keys:",list(lc.keys()))
claim={r.get("lotNumber",r.get("lot")):r for r in lc["lots"]}
for lot in ["63D351","62D430","66D95","62D1","54D270","59D95"]:
    r=claim.get(lot)
    if r: print("CLAIMANTS",lot,"->",[(c.get("naId"),c.get("hmsMlrEntryNumbers"),c.get("title"),c.get("dateRange")) for c in r["claimants"]])
    else: print("CLAIMANTS",lot,"-> ABSENT")
sf=load("series-facts-index.json"); print("series-facts keys:",list(sf.keys())); leg=sf["legend"]["keys"]
def facts(naid):
    r=sf["byNaId"].get(str(naid))
    if not r: return "no series-facts row"
    out={}
    for k,v in r.items():
        L=leg.get(k,{}); f=L.get("field",k); into=L.get("into")
        if into: voc=sf[into]; out[f]=[voc[i] for i in v] if isinstance(v,list) else voc[v]
        else: out[f]=v
    return out
for n in ["2839192","2839191","2839193","2838992"]:
    f=facts(n); print("NAID",n,"facts:",json.dumps({k:f[k] for k in f if k in ("accessStatus","accessRestrictions","creator","inclusiveStartYear","inclusiveEndYear","extent","title")} if isinstance(f,dict) else f,ensure_ascii=False))
pl=load("presidential-library-catalog.json")
def walk(o,path=""):
    if isinstance(o,dict):
        for k,v in o.items(): yield from walk(v,path+"/"+k)
    elif isinstance(o,list):
        for i,v in enumerate(o): yield from walk(v,path+"[%d]"%i)
    else: yield path,o
allkeys=set()
def keys(o):
    if isinstance(o,dict):
        for k,v in o.items(): allkeys.add(k); keys(v)
    elif isinstance(o,list):
        for v in o: keys(v)
keys(pl); print("presidential-library-catalog all keys:",sorted(allkeys))
for lib in pl["libraries"]:
    for c in lib["collections"]:
        if c.get("naId") in (567979,1166,572571) or c.get("identifier") in ("LBJ-NSF","JFK-3","GRF-0351"):
            print("CATALOG",lib["citedAs"],"|",c.get("title"),"|",c.get("identifier"),"| naId",c.get("naId"),"|",[(s.get("title"),s.get("inclusiveDates"),s.get("naId")) for s in c.get("series",[]) if s.get("naId") in (587358,193654,572583)], "| access keys:",[k for k in c if "access" in k.lower()])
# text search of every bundled json for the unresolved identifiers
for n in sorted(os.listdir(R)):
    if not n.endswith(".json"): continue
    try: t=open(R+n,encoding="utf-8").read()
    except Exception: continue
    for needle in ["Entry 5403","\"5403\"","GVN Corruption","54D270","59D95","2839192","567979","572571","193654","587358","572583","\"1166\""]:
        if needle in t: print("FOUND",repr(needle),"in",n, "count",t.count(needle))
ca=load("collection-authority.json"); print("collection-authority keys:",list(ca.keys())[:10] if isinstance(ca,dict) else type(ca))
vs=load("volume-sources-index.json"); print("volume-sources-index keys:",list(vs.keys())[:10] if isinstance(vs,dict) else type(vs))
ec=load("external-citation-index.json"); print("external-citation-index keys:",list(ec.keys())[:10] if isinstance(ec,dict) else type(ec))
# the index's own rows for the lots
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for lot in ["63D351","62D430","66D95","62D1","54D270","59D95"]:
    a=con.execute("SELECT COUNT(*) FROM document_sources WHERE lot_file_norm=?",(lot,)).fetchone()[0]
    b=con.execute("SELECT COUNT(DISTINCT volume_id||'/'||document_id) FROM external_citations WHERE lot_file_norm=?",(lot,)).fetchone()[0]
    print("INDEX lot",lot,"document_sources rows",a,"external_citations docs",b)
print("Entry 5403 in document_sources raw_text:",con.execute("SELECT COUNT(*) FROM document_sources WHERE raw_text LIKE '%Entry 5403%'").fetchone()[0])
print("GVN Corruption in document_sources raw_text:",con.execute("SELECT COUNT(*) FROM document_sources WHERE raw_text LIKE '%GVN Corruption%'").fetchone()[0])
