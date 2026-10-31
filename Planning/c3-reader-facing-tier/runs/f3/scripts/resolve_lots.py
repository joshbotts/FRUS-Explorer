# resolve_lots.py: lot number -> central-files-index.json lotFiles (lotNumber spaces folded) -> naId -> series-facts-index.json byNaId (legend dereferenced)
import json,sys
R=sys.argv[1]
cf=json.load(open(R+'/central-files-index.json')); sf=json.load(open(R+'/series-facts-index.json'))
L=sf['legend']['keys']
def facts(na):
    row=sf['byNaId'].get(str(na))
    if not row: return None
    out={}
    for k,v in row.items():
        spec=L.get(k,{}); f=spec.get('field',k)
        if 'into' in spec:
            arr=sf[spec['into']]; out[f]=[arr[i] for i in v] if isinstance(v,list) else arr[v]
        else: out[f]=v
    return out
by={}
for r in cf['lotFiles']: by.setdefault(r['lotNumber'],[]).append(r)
for lot in sys.argv[2:]:
    rows=by.get(lot)
    if not rows: print(lot,'NOT IN central-files-index'); continue
    for r in rows:
        print(lot,'| RG',r.get('recordGroup'),'| entry',r.get('hmsMlrEntryNumbers'),'| NAID',r.get('naId'),'|',r.get('title'),'|',r.get('catalogURL'))
        f=facts(r.get('naId')); print('    facts:',json.dumps(f,ensure_ascii=False) if f else 'no series-facts row')
