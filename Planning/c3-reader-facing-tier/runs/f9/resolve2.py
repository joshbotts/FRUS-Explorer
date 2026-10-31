# unresolved lots in curated-lot-resolutions / lot-claimants; RG 306 series in series-facts; RG 306 accessions in accession-series-index
import json,re,os
P="/Applications/FRUS Explorer.app/Contents/Resources/"
sf=json.load(open(P+'series-facts-index.json')); L=sf['legend']['keys']
def facts(naid):
    r=sf['byNaId'].get(str(naid)); o={}
    if not r: return None
    for k,v in r.items():
        s=L.get(k)
        if not s: o[k]=v
        elif s['kind']=='index': o[s['field']]=sf[s['into']][v]
        elif s['kind']=='indexList': o[s['field']]=[sf[s['into']][i] for i in v]
        else: o[s['field']]=v
    return o
for f in ['curated-lot-resolutions.json','lot-claimants-index.json']:
    j=json.load(open(P+f))
    for row in j['lots']:
        s=json.dumps(row)
        if re.search(r'61\s*D\s*385|60\s*D\s*627',s): print(f,s[:600])
print('--- series-facts rows with creator naming Information Agency')
for naid in sf['byNaId']:
    f=facts(naid)
    if 'Information Agency' in str(f.get('creator','')): print(naid,{k:f.get(k) for k in ['creator','inclusiveStartYear','inclusiveEndYear','accessStatus','extent']})
a=P+'accession-series-index.json'
print('accession-series-index exists:',os.path.exists(a))
if os.path.exists(a):
    j=json.load(open(a)); print(list(j.keys()))
    for key in ['306/72A5121','306/69A3445','306/68A4933','306/67A222','84/66A335']:
        hit=None
        for container in j.values():
            if isinstance(container,dict) and key in container: hit=container[key]
        print(key, json.dumps(hit)[:500] if hit else 'NOT FOUND')
