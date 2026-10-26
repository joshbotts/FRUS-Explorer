import json, re
B='/Applications/FRUS Explorer.app/Contents/Resources/'
J=lambda f: json.load(open(B+f))
ca=J('collection-authority.json')
hits=[x for x in ca['collections'] if 'central decimal file' in x['name'].lower() or 'central decimal file' in x['id'].lower()]
print('collection-authority: central decimal file entries:',[(x['id'],x['name'],x['repository'],x.get('lotFileNorm'),len(x['volumeIds'])) for x in hits])
print('  keys present on such an entry:',sorted(hits[0].keys()) if hits else None, '| any naId-like key anywhere in these entries:',[k for x in hits for k in x if 'na' in k.lower()])
for term in ['central foreign policy','subject-numeric','subject numeric']:
    h=[(x['id'],x['name'],x['repository']) for x in ca['collections'] if term in x['name'].lower()]
    print(f'  collection-authority entries matching {term!r}:',len(h),h[:4])
cf=J('central-files-index.json')
nf=cf['numericalFile']; print('numericalFile: microfilm',nf['microfilm'],'seriesNaId',nf['seriesNaId'],'rolls',len(nf['rolls']))
print('  roll keys:',sorted(nf['rolls'][0].keys()), nf['rolls'][0])
def roll_match(s): return [r for r in nf['rolls'] if s in json.dumps(r)]
for s in ['7357','3691','6775']:
    print(f'  rolls mentioning {s}:',[(r.get('naId'),r.get('title')) for r in roll_match(s)][:6])
lots=[x for x in cf['lotFiles'] if x['lotNumber'].replace(' ','').replace('-','').upper() in ('64D563',)]
print('central-files lotFiles 64D563:',lots)
lc=J('lot-claimants-index.json')
L=[x for x in lc['lots'] if x['lotNumber'].replace(' ','').replace('-','').upper()=='64D563']
print('lot-claimants 64D563:',len(L),'lot entries;')
for x in L:
    print('  claimants:',len(x['claimants']))
    for cl in x['claimants']: print('    ',cl)
sf=J('series-facts-index.json')
print('series-facts legend keys:',{k:v for k,v in sf['legend']['keys'].items()} )
by=sf['byNaId']; print('byNaId rows:',len(by))
for n in ['1151288','1136548','654171','567979','572235']:
    row=by.get(n); print(f'  {n}:',row, '| heading:',sf['headings'][row['c']] if row and 'c' in row else None)
print('  rows with y0<1940:',sum(1 for r in by.values() if isinstance(r.get('y0'),int) and r['y0']<1940),'| y1<1940:',sum(1 for r in by.values() if isinstance(r.get('y1'),int) and r['y1']<1940))
pl=J('presidential-library-catalog.json')
for lib in pl['libraries']:
    for col in lib['collections']:
        s=json.dumps(col)
        if any(k in s for k in ['567979','572235','1164"','Clean']): print('  presidential-library:',lib['citedAs'],lib['prefix'],col)
print('  Eisenhower collections with Clean in title:',[c for lib in pl['libraries'] if 'isenhower' in lib['citedAs'] for c in lib['collections'] if 'clean' in json.dumps(c).lower()])
print('  Eisenhower library present:',[lib['citedAs'] for lib in pl['libraries'] if 'isenhower' in lib['citedAs']], 'n collections', [len(lib['collections']) for lib in pl['libraries'] if 'isenhower' in lib['citedAs']])
sn=J('subject-numeric-labels.json')
for sch in sn['schedules']:
    print('subject-numeric schedule',sch['id'],sch['startYear'],sch['endYear'],'| POL 16 ->',sch['subjects'].get('POL 16'),'| POL ->',sch['categories'].get('POL'),'| DOM REP ->',sch['areas'].get('DOM REP'))
dl=J('decimal-class-labels.json')
print('decimal coverage:',dl['coverage'])
for sch in dl['schedules']:
    print('decimal schedule',sch['id'],sch['startYear'],sch['endYear'])
    if sch['startYear']==1910:
        print('   class 8:',sch['classes'].get('8'))
        for k in ['38','24','16','18','12','35','17','39','23','34']: print('   country',k,'->',sch['countries'].get(k))
        for k in ['00','01','51']: print('   subject',k,'->',sch['subjects'].get(k))
        print('   countryArrangedClasses:',sch['countryArrangedClasses'])
