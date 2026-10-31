import json, re, sqlite3
R="/Applications/FRUS Explorer.app/Contents/Resources/"
def load(n): return json.load(open(R+n))
def walk(o, path=""):
    if isinstance(o,dict):
        yield path,o
        for k,v in o.items(): yield from walk(v, f"{path}.{k}")
    elif isinstance(o,list):
        for i,v in enumerate(o): yield from walk(v, f"{path}[{i}]")
def strvals(d): return {k:(v if not isinstance(v,(dict,list)) else f"<{type(v).__name__}:{len(v)}>") for k,v in d.items()}
def find_val(o, target, limit=6):
    out=[]
    for p,d in walk(o):
        for k,v in d.items():
            if (isinstance(v,(str,int)) and str(v)==str(target)):
                out.append((p,k,strvals(d))); break
        if len(out)>=limit: break
    return out
def find_sub(o, sub, keys=None, limit=8):
    out=[]
    for p,d in walk(o):
        for k,v in d.items():
            if isinstance(v,str) and sub.lower() in v.lower() and (keys is None or k in keys):
                out.append((p,k,strvals(d))); break
        if len(out)>=limit: break
    return out
def show(title, rows):
    print(f"\n--- {title}: {len(rows)} ---")
    for p,k,d in rows: print(f"  {p} [{k}] {json.dumps(d, ensure_ascii=False)[:600]}")
sf=load("series-facts-index.json"); print("series-facts top keys:", list(sf.keys()) if isinstance(sf,dict) else type(sf), "| counts:", {k:(len(v) if isinstance(v,(list,dict)) else v) for k,v in sf.items()} if isinstance(sf,dict) else len(sf))
for naid in ("602875","2839192"):
    show(f"series-facts NAID {naid}", find_val(sf, naid, 3))
cf=load("central-files-index.json"); print("\ncentral-files top keys:", list(cf.keys()), "| sizes:", {k:(len(v) if isinstance(v,(list,dict)) else v) for k,v in cf.items()})
for lot in ("59D95","66D95","63D351","89D149"):
    show(f"central-files-index lot {lot}", find_val(cf, lot, 3))
cl=load("curated-lot-resolutions.json"); print("\ncurated-lot-resolutions top:", type(cl).__name__, list(cl.keys())[:10] if isinstance(cl,dict) else len(cl))
show("curated-lot-resolutions 59D95", find_val(cl,"59D95",3)+find_sub(cl,"59 D 95",None,3))
show("curated-lot-resolutions 89D149", find_val(cl,"89D149",3))
ca=load("collection-authority.json"); print("\ncollection-authority top keys:", list(ca.keys()) if isinstance(ca,dict) else type(ca), {k:(len(v) if isinstance(v,(list,dict)) else v) for k,v in ca.items()} if isinstance(ca,dict) else "")
show("collection-authority 89D149", find_val(ca,"89D149",4))
show("collection-authority 59D95", find_val(ca,"59D95",4))
show("collection-authority 'Conference Files'", find_sub(ca,"Conference Files",None,4))
lc=load("lot-claimants-index.json"); print("\nlot-claimants top keys:", list(lc.keys()) if isinstance(lc,dict) else type(lc))
show("lot-claimants 89D149", find_val(lc,"89D149",3))
pl=load("presidential-library-catalog.json"); print("\npresidential-library-catalog top keys:", list(pl.keys()) if isinstance(pl,dict) else type(pl), {k:(len(v) if isinstance(v,(list,dict)) else v) for k,v in pl.items()} if isinstance(pl,dict) else "")
for naid in ("567979","572235","1164","643447","1104"):
    show(f"presidential-library NAID {naid}", find_val(pl,naid,2))
for t in ("National Security Affairs","Brzezinski","Whitman","Rosenberg","National Security File","NSC Files","National Security Files (Nixon"):
    show(f"presidential-library title contains '{t}'", find_sub(pl,t,None,6))
ec=load("external-citation-index.json"); print("\nexternal-citation-index top keys:", list(ec.keys()) if isinstance(ec,dict) else type(ec), "schemaVersion:", ec.get("schemaVersion") if isinstance(ec,dict) else None)
vs=load("volume-sources-index.json"); print("volume-sources-index top keys:", list(vs.keys())[:8] if isinstance(vs,dict) else type(vs))
# the "11 of 695 bundled series" reach before 1940
rows=[]
for p,d in walk(sf):
    if any(k.lower().startswith("inclusive") or k in ("inclusiveStart","startYear","dateStart","inclusiveStartYear") for k in d): rows.append(d)
print("\nseries-facts dicts carrying an inclusive-date field:", len(rows), "| sample keys:", list(rows[0].keys())[:20] if rows else None)
def start_year(d):
    for k,v in d.items():
        if "inclusive" in k.lower() or "start" in k.lower():
            if isinstance(v,int): return v
            if isinstance(v,str):
                m=re.search(r'\b(1[6-9]\d\d|20\d\d)\b', v)
                if m: return int(m.group(1))
            if isinstance(v,dict):
                for kk,vv in v.items():
                    if isinstance(vv,int) and 1600<vv<2100: return vv
    return None
ys=[start_year(d) for d in rows]; ys=[y for y in ys if y]
print("series with a start year:", len(ys), "| start < 1940:", sum(1 for y in ys if y<1940))
# distinct decimal classes among the 450 centralFileClass citations over the hit docs
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
hits=json.load(open("/Users/jbotts/frus-analysis/c3s/runs/s5/refuter/hits_ed2suppressed.json"))
db.execute("CREATE TEMP TABLE hit(volume_id TEXT, document_id TEXT)"); db.executemany("INSERT INTO hit VALUES(?,?)",hits)
print("\ncentralFileClass citations over hits: rows, distinct decimal_class, distinct file_id:", db.execute("SELECT COUNT(*), COUNT(DISTINCT e.decimal_class), COUNT(DISTINCT e.file_id) FROM hit h JOIN external_citations e ON e.volume_id=h.volume_id AND e.document_id=h.document_id WHERE e.anchor='centralFileClass'").fetchone())
print("sample centralFileClass rows:", db.execute("SELECT e.decimal_class, e.file_id, substr(e.raw_text,1,60) FROM hit h JOIN external_citations e ON e.volume_id=h.volume_id AND e.document_id=h.document_id WHERE e.anchor='centralFileClass' LIMIT 5").fetchall())
# lot 59D95 / 66D95 / 63D351 / 89D149 in document_sources and external_citations: raw forms
print("\nlot_file_norm forms in external_citations over hits for 66D95/63D351:", db.execute("SELECT e.lot_file_norm, e.lot_file, COUNT(*) FROM hit h JOIN external_citations e ON e.volume_id=h.volume_id AND e.document_id=h.document_id WHERE e.lot_file_norm IN ('66D95','63D351') GROUP BY 1,2").fetchall())
