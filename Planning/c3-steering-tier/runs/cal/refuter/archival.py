import json, re
R='/Applications/FRUS Explorer.app/Contents/Resources/'
cf=json.load(open(R+'central-files-index.json'))
sf=json.load(open(R+'series-facts-index.json'))
lc=json.load(open(R+'lot-claimants-index.json'))
pl=json.load(open(R+'presidential-library-catalog.json'))
ca=json.load(open(R+'collection-authority.json'))
ec=json.load(open(R+'external-citation-index.json'))
print("central-files keys:",list(cf.keys()))
print("lotFiles row keys:",list(cf['lotFiles'][0].keys()))
print("series-facts keys:",list(sf.keys())); print(" legend:",json.dumps(sf['legend'])[:1500])
print("presidential-library keys:",list(pl.keys()) if isinstance(pl,dict) else type(pl))
print("lot-claimants keys:",list(lc.keys()))
print("collection-authority keys:",list(ca.keys()) if isinstance(ca,dict) else type(ca))
print("external-citation keys:",list(ec.keys()) if isinstance(ec,dict) else type(ec))
by={}
for r in cf['lotFiles']: by.setdefault(r['lotNumber'],[]).append(r)
def facts(naid):
    f=sf['byNaId'].get(str(naid))
    if not f: return None
    out={}
    for k,v in f.items():
        spec=sf['legend']['keys'].get(k,{})
        into=spec.get('into')
        if into and into in sf:
            v=[sf[into][i] for i in v] if isinstance(v,list) else sf[into][v]
        out[spec.get('field',k)]=v
    return out
claims={ # lot: (entry, naid, dates, access, extra) as the overview's second paragraph states them
 '65D438':('A1 3053','27022950','1962–1963','partly restricted','Executive Secretariat, records relating to the Cuban Missile Crisis'),
 '74D272':('A1 5175','614703','1961–1966','unrestricted','Records of Under Secretary George W. Ball'),
 '66D501':('UD-UP 293-B','648748','1963–1965','unrestricted','Operation Mongoose files, Coordinator of Cuban Affairs'),
 '62D24':('A1 3148','2363836','1958–1961','partly restricted','Special Assistant on Communism subject files'),
 '66D95':('A1 1586E','2839192','1947–1979','partly restricted','Executive Secretariat records relating to NSC policy papers; second series Subject Files 2839193'),
 '73D191':('A1-5758','1040618','1957–1975','partly restricted; 27 linear feet','Coordinator of Cuban Affairs, Records Relating to Cuba'),
 '65D212':('UD-UP 215','27022874','1955–1962','fully restricted','Records Relating to Sugar'),
 '66D204':('A1 1590','2538452','1953–1964','possibly restricted','correspondence with foreign heads of state'),
}
print("\n=== LOTS in central-files-index.json lotFiles ===")
for lot,(entry,naid,dates,access,desc) in claims.items():
    rows=by.get(lot,[])
    print(f"\nLOT {lot}  overview: entry={entry} naid={naid} dates={dates} access={access} | {desc}")
    for r in rows:
        print("   bundle row:", {k:r.get(k) for k in r.keys() if k in ('recordGroup','naId','title','hmsMlrEntryNumbers','matchType','levelOfDescription','creator','creators','dates','dateRange','inclusiveDates','accessRestriction','extent','lotNumber','lotNumberDisplay')})
        print("   facts:", facts(r.get('naId')))
    if not rows: print("   NOT IN lotFiles")
print("\n=== second claimant for 66D95 (NAID 2839193) ===")
print(" facts(2839193):", facts('2839193'))
for l in lc.get('lots',[]):
    s=json.dumps(l)
    if '66D95' in s or '66 D 95' in s: print(" lot-claimants entry:", s[:700])
print("\n=== presidential libraries ===")
txt=json.dumps(pl)
for naid,label in [('1164','Kennedy NSF'),('567979','Johnson NSF'),('560131','Carter NSA office')]:
    for m in re.finditer(r'"naId":\s*"?%s"?'%naid, txt):
        print(f" {label} NAID {naid}: ...{txt[max(0,m.start()-300):m.start()+200]}...")
        break
    else:
        hits=[m.start() for m in re.finditer(naid, txt)]
        print(f" {label} NAID {naid}: raw-text hits {len(hits)}", (txt[max(0,hits[0]-250):hits[0]+150] if hits else ''))
print("\n=== pre-1910 countrySeries ===")
cs=cf.get('countrySeries')
print(" countrySeries type:", type(cs).__name__, "len", len(cs) if cs else None)
s=json.dumps(cs)
for name in ['Ministers to Spain','to Cuba, 1902','Consuls in Havana','Cuban Legation']:
    for m in re.finditer(name, s):
        print(f" '{name}': ...{s[max(0,m.start()-200):m.start()+250]}...")
        break
    else: print(f" '{name}': NOT FOUND")
print("\n=== central decimal file NAID? ===")
allt=json.dumps(cf)+json.dumps(ca)+json.dumps(sf)
for m in list(re.finditer(r'[Cc]entral [Dd]ecimal [Ff]ile', allt))[:3]:
    print(" ...", allt[max(0,m.start()-200):m.start()+200].replace('\n',' '))
print(" rows in lotFiles titled 'Decimal Files':", [(r['lotNumber'],r.get('naId'),r.get('title')) for r in cf['lotFiles'] if 'Decimal' in (r.get('title') or '')])
