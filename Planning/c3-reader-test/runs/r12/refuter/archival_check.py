import json,re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
J=lambda n: json.load(open(R+n))
cfi=J("central-files-index.json"); sfi=J("series-facts-index.json"); lci=J("lot-claimants-index.json")
eci=J("external-citation-index.json"); ca=J("collection-authority.json"); plc=J("presidential-library-catalog.json")
dcl=J("decimal-class-labels.json"); vsi=J("volume-sources-index.json")
print("== lots in central-files-index lotFiles")
want={"64D563","53D26","53D444","56D625","66D95","53D250","60D137"}
def lotnorm(s): return re.sub(r'[^0-9A-Z]','',s.upper())
bylot={}
for lf in cfi['lotFiles']:
    k=lotnorm(lf.get('lotNumber',''))
    bylot.setdefault(k,[]).append(lf)
for w in sorted(want):
    rows=bylot.get(w,[])
    print(w, "->", [(r['naId'], r.get('hmsMlrEntryNumbers'), r.get('title')[:70], r.get('recordGroup'), r.get('matchType')) for r in rows] or "NOT IN lotFiles")
print("== series-facts byNaId for the NAIDs named")
for naid in ["1136548","2108774","2168520","2092759","2839192"]:
    r=sfi['byNaId'].get(naid)
    print(naid, json.dumps(r,ensure_ascii=False)[:400] if r else "NOT IN series-facts")
print("legend:", json.dumps(sfi['legend'],ensure_ascii=False)[:800])
print("statuses:", sfi['statuses'])
print("== lot-claimants for 64D563")
for lot in lci['lots']:
    if lotnorm(lot.get('lot','') or lot.get('lotNumber','') or lot.get('lotFileNorm',''))=="64D563" or "64D563" in json.dumps(lot).replace(' ','').replace('-',''):
        print(json.dumps(lot,ensure_ascii=False)[:300]); print("claimants:",len(lot.get('claimants',[])), [ (c['naId'],c['title'][:40],c.get('hmsMlrEntryNumbers')) for c in lot.get('claimants',[])])
print("lots sample keys:", list(lci['lots'][0].keys()))
print("== countrySeries rolls named")
rolls={"188967467","189300896","189312130","149302787","149303924"}
for cs in cfi['countrySeries']:
    for r in cs['rolls']:
        if str(r.get('naId')) in rolls:
            print(cs['category'], cs['displayName'],'|',r.get('naId'), r.get('fileUnitNaId'), r.get('fileUnitTitle'), r.get('geoKeys'), r.get('startISO'), r.get('endISO'), r.get('title','')[:80])
print("countrySeries categories:", [(c['category'],c['displayName'],len(c['rolls'])) for c in cfi['countrySeries']])
print("== Venezuela instructions rolls?")
for cs in cfi['countrySeries']:
    if 'nstruction' in cs['displayName']:
        vz=[r for r in cs['rolls'] if 'venezuela' in (r.get('geoKeys') or []) or 'Venezuela' in r.get('fileUnitTitle','')]
        print(cs['displayName'], "venezuela rolls:", len(vz), [(r['naId'],r.get('startISO'),r.get('endISO')) for r in vz][:5])
print("== decimal-class-labels: 824.00 and 812.00")
print("coverage:", json.dumps(dcl['coverage'],ensure_ascii=False)[:600])
for sch in dcl['schedules']:
    print("schedule keys:", list(sch.keys()), "years:", sch.get('years') or sch.get('yearRange') or sch.get('label'))
    cl=sch.get('classes',{}); co=sch.get('countries',{}) or sch.get('countryNumbers',{})
    print("  class 8:", cl.get('8'), "| class 7:", cl.get('7'))
    for k in ('24','12'):
        print("  country",k,":", co.get(k) if isinstance(co,dict) else None)
    sub=sch.get('subclasses') or sch.get('subjects') or {}
    if isinstance(sub,dict):
        for k in ('00','.00','800','812.00','824.00'):
            if k in sub: print("  sub",k,":",sub[k])
print("== record group 59 in volume-sources-index")
print(json.dumps(vsi['recordGroups'].get('59'),ensure_ascii=False)[:300])
print("== Roosevelt library in presidential-library-catalog")
for lib in plc['libraries']:
    if 'oosevelt' in lib.get('citedAs','') or 'oosevelt' in json.dumps(lib)[:200]:
        print(lib.get('citedAs'), lib.get('name'), [k for k in lib.keys()], "collections:", len(lib.get('collections',[])))
print("== collection-authority entries for the lots")
for col in ca['collections']:
    if col.get('lotFileNorm') in want:
        print(col['id'], col['lotFileNorm'], col['name'][:90], col.get('repository'), len(col.get('volumeIds',[])))
