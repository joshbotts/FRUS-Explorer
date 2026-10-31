import json,re,sqlite3
R="/Applications/FRUS Explorer.app/Contents/Resources/"
J=lambda n: json.load(open(R+n))
acc=J("accession-series-index.json"); lots=J("lot-claimants-index.json"); sf=J("series-facts-index.json")
plc=J("presidential-library-catalog.json"); cfi=J("central-files-index.json"); ca=J("collection-authority.json")
try: dcl=J("decimal-class-labels.json")
except Exception as e: dcl=None; print("decimal-class-labels:",e)
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
print("== accession-series-index ==")
for k in ["306/67A222","306/68A4933","306/72A5121","306/840003"]:
    rows=acc["byAccession"].get(k)
    print(k,"->",None if rows is None else [(r['n'],r['t']) for r in rows], "count",0 if rows is None else len(rows))
print("\n== series-facts-index (y0,y1,extent,accessStatus,creator) ==")
st=sf["statuses"]; hd=sf["headings"]
for n in ["2839192","2839193","2839191","2838992","1257679","40967285","1254251","42125423","48349732","5552237","5585931","645643","1164","567979","591194","587358","50809179","572235","1104"]:
    r=sf["byNaId"].get(n)
    if r: print(n,r.get('y0'),r.get('y1'),r.get('x'),st[r['as']] if 'as' in r else None,hd[r['c']] if 'c' in r else None)
    else: print(n,"NO ROW")
print("\n== lot-claimants-index ==")
for L in lots["lots"]:
    if L["lotNumber"] in ("63D351","66D95","62D430","62D1"):
        print(L["lotNumber"],[(c.get('naId'),c.get('title'),c.get('years') or (c.get('y0'),c.get('y1'))) for c in L["claimants"]])
print("lots present among the four:",[L["lotNumber"] for L in lots["lots"] if L["lotNumber"] in ("63D351","66D95","62D430","62D1")])
print("\n== central-files-index lotFiles ==")
for lf in cfi["lotFiles"]:
    if lf["lotNumber"] in ("63D351","66D95","62D430","62D1"):
        print(lf["lotNumber"],lf["naId"],lf["title"],lf.get("hmsMlrEntryNumbers"),lf.get("matchType"),lf.get("recordGroup"))
print("central-files-index keys:",list(cfi.keys()))
print("countrySeries:",[(c['category'],c.get('seriesNaId'),len(c['rolls'])) for c in cfi['countrySeries']])
for c in cfi['countrySeries']:
    yrs=[(r.get('yearStart'),r.get('yearEnd')) for r in c['rolls'][:2]]
    print("  ",c['category'],c.get('displayName'),list(c['rolls'][0].keys()) if c['rolls'] else None)
# any decimal-file series 1945-1963?
s=json.dumps(cfi)
for pat in ["Central Decimal","Decimal File","1945-49","1950-54","1955-59","1960-63","1945–1949","1950–1954","1955–1959","1960–1963"]:
    print("  cfi contains",repr(pat),":",len(re.findall(pat,s)))
print("\n== collection-authority ==")
for c in ca["collections"]:
    if c.get("lotFileNorm") in ("63D351","66D95","62D430","62D1") or re.search(r'67 ?A ?222|68 ?A ?4933|72 ?A ?5121|306.84.0003|P.?207|P.?104|UD WW 257',c.get('name','')):
        print(c['id'],c.get('lotFileNorm'),c['name'][:120],c.get('repository'),len(c.get('volumeIds',[])))
print("\n== presidential-library-catalog ==")
want={"567979","591194","587358","50809179","1164","572235","1104","645643"}
for lib in plc["libraries"]:
    for coll in lib["collections"]:
        cid=str(coll.get("naId"))
        if cid in want:
            print(lib["citedAs"],cid,coll.get("title")[:90],coll.get("prefix") or coll.get("identifier"),"series:",[(s.get('naId'),s.get('title')[:50],s.get('startYear') or s.get('y0'),s.get('endYear') or s.get('y1')) for s in coll.get("series",[])][:6])
        for s in coll.get("series",[]):
            if str(s.get("naId")) in want and str(coll.get("naId")) not in want:
                print("  series hit",lib["citedAs"],coll.get("naId"),coll.get("title")[:60],"->",s)
print("collection keys sample:",list(plc["libraries"][0]["collections"][0].keys()))
if plc["libraries"][0]["collections"][0].get("series"): print("series keys sample:",list(plc["libraries"][0]["collections"][0]["series"][0].keys()))
# Ford library: any 'Presidential Country Files for East Asia'?
for lib in plc["libraries"]:
    if 'Ford' in lib['citedAs']:
        hits=[(c.get('naId'),c.get('title')) for c in lib['collections'] if re.search(r'East Asia|Country Files|National Security Adviser',c.get('title',''),re.I)]
        print("Ford matches:",hits[:15])
print("\n== decimal-class-labels (country 90, 98) ==")
if dcl:
    s=json.dumps(dcl)
    print("keys:",list(dcl.keys())[:10])
    for pat in [r'"90"[^}]{0,80}', r'"98"[^}]{0,80}']:
        for m in re.findall(pat,s)[:6]: print("  ",m[:120])
print("\n== index rows: document_sources for the 27 (repository, record_group, lot, series) ==")
for v,d in json.load(open("cited_pairs.json")):
    r=con.execute("SELECT repository,record_group,lot_file,lot_file_norm,series_name,substr(raw_text,1,120) FROM document_sources WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    print(v,d,r)
print("\n== external_citations: lot rows exist? ==")
for lot in ("66D95","62D430","63D351","62D1"):
    print(lot,con.execute("SELECT count(*),count(distinct volume_id||document_id) FROM external_citations WHERE lot_file_norm=?",(lot,)).fetchone())
print("\n== R-10-65 in frus1964-68v02/d172 ==")
r=con.execute("SELECT instr(body_text,'R-10-65'), instr(body_text,'R–10–65'), instr(source_note,'R-10-65') FROM document_cache WHERE volume_id='frus1964-68v02' AND document_id='d172'").fetchone(); print(r)
r=con.execute("SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v02' AND document_id='d172'").fetchone()[0]
for m in re.finditer(r'R.10.65',r): print("   ...",r[max(0,m.start()-150):m.end()+100].replace("\n"," "))
