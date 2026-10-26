# refuter: the archival identifiers named in the bottom line's second paragraph, against the bundled artifacts and the index.
import json, re, sqlite3, collections
B='/Applications/FRUS Explorer.app/Contents/Resources/'
cf=json.load(open(B+'central-files-index.json')); sf=json.load(open(B+'series-facts-index.json'))
sn=json.load(open(B+'subject-numeric-labels.json')); dl=json.load(open(B+'decimal-class-labels.json'))
leg=sf['legend']['keys']
def decode(row):
    out={}
    for k,v in row.items():
        spec=leg.get(k)
        if not spec: out[k]=v; continue
        f=spec['field']
        if spec['kind']=='index': out[f]=sf[spec['into']][v]
        elif spec['kind']=='indexList': out[f]=[sf[spec['into']][i] for i in v]
        else: out[f]=v
    return out
lots={re.sub(r'\s+','',l['lotNumber']).upper():l for l in cf['lotFiles']}
print('lotFiles rows:',len(cf['lotFiles']),'byNaId rows:',len(sf['byNaId']))
claims={ # lot -> (entry, naid, dates, extent words, access words) as the overview states them
 '81D64':('UD-14D 61','27499857','1978–1981','9 linear feet','fully restricted'),
 '53D26':('A1 1130','2108774','1949–1953','6 linear feet','unrestricted'),
 '59D573':('A1 1135','2108779','1957–1959','7 linear feet','unrestricted'),
 '81D121':('UD-UP 313','26309351','1964–1970','2 linear feet','fully restricted'),
 '81D113':('P 14','1487627','1975–1981','14 linear feet','partly restricted'),
}
for lot,(entry,naid,dates,ext,acc) in claims.items():
    l=lots.get(lot); print(f'\nLOT {lot}: claim entry {entry}, NAID {naid}, {dates}, {ext}, {acc}')
    if not l: print('  NOT in lotFiles'); continue
    print('  lotFiles:',json.dumps({k:l[k] for k in ('lotNumber','naId','hmsMlrEntryNumbers','recordGroup','title','matchType','levelOfDescription')}))
    r=sf['byNaId'].get(l['naId']); 
    if not r: print('  no series-facts row'); continue
    dr=decode(r); print('  series-facts:',json.dumps(dr,ensure_ascii=False))
    print('  entry ok:',entry in l.get('hmsMlrEntryNumbers',[]),'| naid ok:',l['naId']==naid,'| RG 59:',l.get('recordGroup')=='59',
          '| years:',dr.get('inclusiveStartYear'),dr.get('inclusiveEndYear'),'| extent:',dr.get('extent'),'| access:',dr.get('accessStatus'),dr.get('accessRestrictions'),'| ref unit:',dr.get('referenceUnit'),'| creator:',dr.get('creator'))
# pre-1906 country series
print('\nCOUNTRY SERIES (file units):')
want={'177380741':'Despatches from U.S. Ministers to Mexico, 1823–1906','149324017':'Diplomatic Instructions, Mexico, vol. 19, 1873–1879','177380736':'Despatches from U.S. Ministers to Venezuela, 1835–1906','177380753':'Despatches from U.S. Ministers to Ecuador, 1848–1906','216919721':'Notes to Foreign Missions, Mexico 1873–1884 (memo only)'}
found=collections.defaultdict(list)
for cat in cf['countrySeries']:
    for roll in cat.get('rolls',[]):
        for key in ('fileUnitNaId','naId'):
            if roll.get(key) in want: found[roll[key]].append((cat['category'],key,roll.get('fileUnitTitle'),roll.get('title'),roll.get('geoKeys'),roll.get('startISO'),roll.get('endISO'),roll.get('catalogURL')))
for naid,label in want.items():
    rows=found.get(naid,[])
    print(f'  {naid} ({label}): {len(rows)} roll rows;', 'sample:' , rows[:2] if rows else 'NOT FOUND')
    fu={r[2] for r in rows}; print('    fileUnitTitles:',fu)
# the Central Decimal File itself
print('\nCENTRAL DECIMAL FILE in series-facts? rows whose decoded creator/title mention it:')
hits=[]
for naid,r in sf['byNaId'].items():
    dr=decode(r); s=json.dumps(dr,ensure_ascii=False).lower()
    if 'decimal' in s or naid=='302021': hits.append((naid,dr))
print('  ',len(hits),hits[:5])
print('  302021 in byNaId:', '302021' in sf['byNaId'])
print('  lotFiles titles mentioning "Central Decimal":',[ (l['lotNumber'],l['naId'],l['title']) for l in cf['lotFiles'] if 'decimal' in l['title'].lower()][:5])
# POL 16
print('\nSUBJECT-NUMERIC POL 16:')
for s in sn['schedules']:
    subs=s.get('subjects',{}); pol=subs.get('POL',{})
    v=pol.get('16') if isinstance(pol,dict) else None
    print('  schedule',s.get('years') or s.get('name') or list(s.keys())[:5],'POL.16 =',v if v is not None else ('(POL keys sample '+str(list(pol.keys())[:5])+')' if isinstance(pol,dict) else pol))
# decimal class labels
print('\nDECIMAL CLASS LABELS:')
for s in dl['schedules']:
    name=s.get('years') or s.get('name') or s.get('label'); subs=s.get('subjects',{}); cl=s.get('classes',{}); co=s.get('countries',{})
    print('  schedule',name,'| keys',list(s.keys()))
    print('    class 8:',cl.get('8') if isinstance(cl,dict) else None,'| class 7:',cl.get('7') if isinstance(cl,dict) else None)
    s8=subs.get('8') if isinstance(subs,dict) else None
    if isinstance(s8,dict): print('    subjects 8 .00:',s8.get('00') or s8.get('.00'),'| .01:',s8.get('01') or s8.get('.01'),'| sample keys',list(s8.keys())[:6])
    else: print('    subjects keys sample:',list(subs.keys())[:8] if isinstance(subs,dict) else subs)
    if isinstance(co,dict): print('    countries 12,17,24,16,38,23:',{k:co.get(k) for k in ('12','17','24','16','38','23')})
print('coverage:',json.dumps(dl['coverage'])[:400])
