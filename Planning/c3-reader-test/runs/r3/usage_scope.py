import json,collections
R='/Applications/FRUS Explorer.app/Contents/Resources/'
u=json.load(open(R+'collection-usage-index.json'))
a=json.load(open(R+'collection-authority.json'))['collections']
byid={c['id']:c for c in a}
pairs=[l.split() for l in open('/Users/jbotts/frus-analysis/c3/runs/r3/pairs.txt')]
S=sorted(set(p[0] for p in pairs))
vi={v:i for i,v in enumerate(u['volumes'])}
Sidx={vi[v] for v in S}
print('scope volumes',len(S),'all in index:',all(v in vi for v in S))
def agg(entries,names):
    tot=collections.Counter(); 
    for e in entries:
        s=sum(n for n,v in zip(e['n'],e['v']) if v in Sidx)
        if s: tot[e['k']]+=s
    return tot
cat=agg(u['volumeCategories'],u['categories'])
print('NOTE CITATIONS BY CATEGORY (pointed-at, scope volumes):')
for k,n in cat.most_common(): print(' ',u['categories'][k],n)
print('total notes in scope volumes (volumeNoteCounts sum):',sum(u['volumeNoteCounts'][i] for i in Sidx))
col=agg(u['collections'],None)
print('TOP COLLECTIONS:')
for k,n in col.most_common(25):
    cid=u['collectionIds'][k]; c=byid.get(cid,{})
    print(' ',n,cid,'|',(c.get('name') or '')[:110],'|RG',c.get('recordGroup'),'|NAID',c.get('naId'),'|',c.get('repository'))
cls=agg(u['classes'],None)
print('TOP DECIMAL/CLASS KEYS:')
for k,n in cls.most_common(25): print(' ',n,u['classKeys'][k])
print('distinct collections reached',len(col))
