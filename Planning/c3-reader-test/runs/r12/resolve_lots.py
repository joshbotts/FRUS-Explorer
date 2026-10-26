import json, sys
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json")); sf=json.load(open(R+"series-facts-index.json"))
lc=json.load(open(R+"lot-claimants-index.json")); cur=json.load(open(R+"curated-lot-resolutions.json"))
print("curated keys",list(cur.keys()), "lots rows", len(cur['lots']), json.dumps(cur['lots'][0])[:300])
lots={r['lotNumber']:r for r in cf['lotFiles']}
claim={r.get('lotNumber') or r.get('lot'):r for r in lc['lots']}
print("claimant row keys",list(lc['lots'][0].keys()))
def vocab(row):
    out={}
    for k,v in row.items():
        sp=sf['legend']['keys'].get(k)
        if not sp: out[k]=v; continue
        into=sp.get('into')
        if sp['kind']=='index': out[sp['field']]=sf[into][v]
        elif sp['kind']=='indexList': out[sp['field']]=[sf[into][i] for i in v]
        else: out[sp['field']]=v
    return out
for L in sys.argv[1:]:
    r=lots.get(L)
    print("==",L, json.dumps(r)[:600] if r else "NOT in central-files-index.lotFiles")
    if r:
        f=sf['byNaId'].get(r['naId'])
        print("   series-facts:", json.dumps(vocab(f))[:700] if f else "none")
    if L in claim: print("   claimants:",json.dumps(claim[L])[:600])
    for c in cur['lots']:
        if (c.get('lotNumber') or c.get('lot'))==L: print("   curated:",json.dumps(c)[:500])
