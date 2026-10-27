import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
for f in ['central-files-index.json','series-facts-index.json','decimal-class-labels.json','lot-claimants-index.json','collection-usage-index.json','external-citation-index.json']:
    j=json.load(open(R+f))
    print(f, {k:(type(v).__name__, len(v) if hasattr(v,'__len__') else v) for k,v in j.items()})
j=json.load(open(R+'central-files-index.json'))
print(json.dumps(j['lotFiles'][0])[:600])
for k in j:
    if k!='lotFiles' and isinstance(j[k],(list,dict)): print(k, json.dumps(j[k])[:500])
s=json.load(open(R+'series-facts-index.json')); print('legend',json.dumps(s['legend'])[:1500])
