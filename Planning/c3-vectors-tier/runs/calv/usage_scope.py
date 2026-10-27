# [JSON] collection-usage-index.json: ranked archival targets for the 38 scope volumes (volume-level, all source notes of those volumes). Label: CAME-FROM channel (source notes), volume-scoped.
import json,collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
u=json.load(open(R+'collection-usage-index.json'))
a=json.load(open(R+'collection-authority.json'))
auth={c['id']:c for c in a['collections']}
vols=u['volumes']; vi={v:i for i,v in enumerate(vols)}
scope=sorted({l.split()[0] for l in open('/Users/jbotts/frus-analysis/c3/runs/r5/scope_docs.tsv')})
si={vi[v] for v in scope if v in vi}
print('scope volumes',len(scope),'in usage index',len(si))
print('coverage',u['coverage']); print('categories',u['categories'])
tot=collections.Counter(); byc={}
for c in u['collections']:
    cid=u['collectionIds'][c['k']]
    n=sum(nn for nn,vv in zip(c['n'],c['v']) if vv in si)
    if n: tot[cid]=n
print('collections reached',len(tot),'notes',sum(tot.values()))
for cid,n in tot.most_common(25):
    ac=auth.get(cid,{})
    print(n,cid,'|',(ac.get('name') or '')[:110])
# category-level (volumeCategories)
print('volumeCategories sample',u['volumeCategories'][0].keys() if isinstance(u['volumeCategories'][0],dict) else '')
vc=collections.Counter()
for k,cat in enumerate(u['categories']):
    d=u['volumeCategories'][k]
    n=sum(nn for nn,vv in zip(d['n'],d['v']) if vv in si) if 'v' in d else 0
    vc[cat]=n
print(vc.most_common())
