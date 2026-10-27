import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
d=json.load(open(R+'decimal-class-labels.json'))
s=d['schedules'][0]; print({k:(type(v).__name__) for k,v in s.items()})
print(json.dumps(s)[:800])
cf=json.load(open(R+'central-files-index.json'))
print('numericalFile seriesNaId',cf['numericalFile']['seriesNaId'])
for s in cf['countrySeries']:
    for r in s['rolls']:
        if 'Havana' in (r.get('fileUnitTitle') or '') or 'Ministers to Cuba' in (r.get('fileUnitTitle') or '') or 'Cuban Legation' in (r.get('fileUnitTitle') or ''):
            print(s['displayName'],'|',r['fileUnitTitle'],'| fileUnitNaId',r['fileUnitNaId']); break
sf=json.load(open(R+'series-facts-index.json'))
for na in ['302021','2124670']:
    print(na, na in sf['byNaId'])
