# Resolve lot numbers from channels.json against central-files-index.json lotFiles (lotNumber), lot-claimants-index.json lots, curated-lot-resolutions.json lots, and series-facts-index.json byNaId.
import json, os
D = "/Applications/FRUS Explorer.app/Contents/Resources"
cf = {r['lotNumber']: r for r in json.load(open(os.path.join(D, 'central-files-index.json')))['lotFiles']}
lc = {r.get('lotNumber'): r for r in json.load(open(os.path.join(D, 'lot-claimants-index.json')))['lots']}
cu = {r['lotNumber']: r for r in json.load(open(os.path.join(D, 'curated-lot-resolutions.json')))['lots']}
sf = json.load(open(os.path.join(D, 'series-facts-index.json')))
leg = sf['legend']['keys']
def facts(naid):
    f = sf['byNaId'].get(str(naid))
    if not f: return 'no series facts'
    out = {}
    for k, v in f.items():
        L = leg.get(k, {}); fld = L.get('field', k); into = L.get('into')
        if into and L.get('kind') == 'index': v = sf[into][v]
        elif into and L.get('kind') == 'indexList': v = [sf[into][i] for i in v]
        out[fld] = v
    return out
ch = json.load(open('/Users/jbotts/frus-analysis/c3/runs/r4/channels.json'))
for chan in ('came_lots', 'pointed_lots'):
    print('==', chan)
    for lot, n in ch[chan]:
        r = cf.get(lot)
        line = '%s (%d docs/rows): ' % (lot, n)
        if r: line += 'RG %s | %s | NAID %s | entry %s | match %s | %s' % (r.get('recordGroup'), r.get('title'), r.get('naId'), ','.join(r.get('hmsMlrEntryNumbers') or []), r.get('matchType'), json.dumps(facts(r.get('naId')))[:300])
        else: line += 'NOT in central-files-index lotFiles'
        if lot in lc: line += ' | CLAIMANTS: ' + '; '.join('%s NAID %s %s' % (c.get('title'), c.get('naId'), c.get('dateRange')) for c in lc[lot]['claimants'])
        if lot in cu: line += ' | CURATED: ' + json.dumps(cu[lot])[:200]
        print(' ', line)
print('legend', json.dumps(leg)[:800])
