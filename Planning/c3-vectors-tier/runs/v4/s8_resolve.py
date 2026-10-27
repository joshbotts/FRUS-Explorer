# Resolve top lots (came-from and pointed-at) and decimal classes for W through bundled JSON.
import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+'central-files-index.json'))
sf=json.load(open(R+'series-facts-index.json'))
def facts(na):
    r=sf['byNaId'].get(str(na))
    if not r: return None
    out={}
    for k,v in r.items():
        L=sf['legend']['keys'].get(k,{})
        if 'into' in L:
            arr=sf[L['into']]
            out[L['field']]= [arr[i] for i in v] if isinstance(v,list) else arr[v]
        else: out[L.get('field',k)]=v
    return out
lots={r['lotNumber']:r for r in cf['lotFiles']}
for lot in ['65D438','74D272','66D501','62D418','62D24','70D149','66D95','66D204','65D533','64D199','65D330','73D191']:
    r=lots.get(lot)
    if not r: print(lot,'NOT IN central-files-index'); continue
    print(lot,'| RG',r.get('recordGroup'),'| entry',r.get('hmsMlrEntryNumbers'),'| NAID',r.get('naId'),'|',r.get('title'),'|',r.get('matchType'))
    f=facts(r.get('naId'))
    if f: print('    facts:',{k:f.get(k) for k in ('creator','inclusiveStartYear','inclusiveEndYear','accessStatus','useStatus','extent','referenceUnit')})
# Central Decimal File: find series facts whose heading mentions decimal
print('\nnumericalFile keys',list(cf['numericalFile']))
print('countrySeries:',[ (s.get('displayName'),s.get('category'),len(s.get('rolls',[]))) for s in cf['countrySeries']])
cuba=[ (s['displayName'],r['title'],r['naId'],r.get('startISO'),r.get('endISO'),r.get('fileUnitTitle')) for s in cf['countrySeries'] for r in s.get('rolls',[]) if 'cuba' in r.get('geoKeys',[]) or 'cuba' in (r.get('fileUnitTitle') or '').lower()]
print('Cuba rolls:',len(cuba))
fu={}
for x in cuba: fu.setdefault((x[0],x[5]),[]).append(x)
for k,v in fu.items(): print(' ',k,len(v),'rolls',min(str(i[3]) for i in v),max(str(i[4]) for i in v),'e.g. NAID',v[0][2])
d=json.load(open(R+'decimal-class-labels.json'))
print('\ndecimal coverage:',json.dumps(d['coverage'])[:900])
