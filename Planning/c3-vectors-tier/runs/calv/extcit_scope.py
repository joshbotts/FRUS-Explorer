# [JSON] external-citation-index.json restricted to the 38 scope volumes: POINTED-AT channel (what the editors cited and did not print), volume-scoped.
import json,collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
e=json.load(open(R+'external-citation-index.json'))
a=json.load(open(R+'collection-authority.json')); auth={c['id']:c for c in a['collections']}
vols=e['volumes']; vi={v:i for i,v in enumerate(vols)}
scope=sorted({l.split()[0] for l in open('/Users/jbotts/frus-analysis/c3/runs/r5/scope_docs.tsv')})
si={vi[v] for v in scope if v in vi}
print('scope volumes',len(scope),'present in external-citation-index volumes list',len(si)); print('coverage',json.dumps(e['coverage'])[:900])
tot=collections.Counter()
for t in e['targets']:
    tid=e['targetIds'][t['k']]
    n=sum(nn for nn,vv in zip(t['n'],t['v']) if vv in si)
    if n: tot[tid]=n
print('lot/library targets cited',len(tot),'citations',sum(tot.values()))
for tid,n in tot.most_common(20): print(n,tid,'|',(auth.get(tid,{}).get('name') or '')[:100])
ct=collections.Counter()
for t in e['classTargets']:
    cid=e['classTargetKeys'][t['k']]
    n=sum(nn for nn,vv in zip(t['n'],t['v']) if vv in si)
    if n: ct[cid]=n
print('decimal class targets cited',len(ct),'citations',sum(ct.values()))
print(ct.most_common(25))
