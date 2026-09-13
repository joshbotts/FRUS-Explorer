import json,collections as C,random,math
S='/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/chapter-context/label-validation/'
rows=[json.loads(l) for l in open(S+'scored-mentions.jsonl')]
PRE={'frus1873p1v1','frus1873p1v2'}
pre=[r for r in rows if r['v'] in PRE]
print('1873 linked',len(pre))
def g(r,k): return (r.get(k) or {})
for rule,get in [('S',lambda r:r['S_j']),('CH STRIP',lambda r:g(r,'STRIP|primary(0,60d)').get('CH_j')),('COMB STRIP',lambda r:g(r,'STRIP|primary(0,60d)').get('COMB_j')),('CH SHOWN',lambda r:g(r,'SHOWN|primary(0,60d)').get('CH_j')),('COMB SHOWN',lambda r:g(r,'SHOWN|primary(0,60d)').get('COMB_j'))]:
    c=C.Counter((r['gold_route'] or ('foreign' if r['gold_foreign'] else 'noslug'),get(r)) for r in pre)
    print(rule,sorted(c.items(),key=str))
# entity clustering for S agree
ag=[r for r in pre if r['S_j']=='agree']
ent=C.Counter(r['gold_slug'] for r in ag); print('S agree distinct slugs',len(ent),ent.most_common(8))
cag=[r for r in pre if g(r,'STRIP|primary(0,60d)').get('COMB_j')=='agree']
e2=C.Counter(r['gold_slug'] for r in cag); print('COMB agree distinct slugs',len(e2),e2.most_common(6))
docs=C.Counter((r['v'],r['d']) for r in ag); print('S agree distinct docs',len(docs))
# route-B entry definition check: how many route-B mentions have S pick == route-B slug
# SHOWN picks docs
sh=[r for r in pre if g(r,'SHOWN|primary(0,60d)').get('CH_j')]
print('SHOWN pick rows',len(sh),'docs',len({(r['v'],r['d']) for r in sh}), C.Counter(r['pos'] for r in sh), C.Counter(r['t'] for r in sh))
# any shown key rows (doc has shown) linked
anyshown=[r for r in pre if g(r,'SHOWN|primary(0,60d)').get('cats')]
print('linked rows in shown docs',len(anyshown))
# post1905 proxy per-volume S precision and cluster bootstrap
proxyv=set(json.load(open(S+'score.json'))['chapter_bearing_volumes_STRIP'])-PRE
px=[r for r in rows if r['v'] in proxyv]
def rate(rs,get):
    a=sum(1 for r in rs if get(r)=='agree'); d=sum(1 for r in rs if get(r)=='disagree'); return a,d
byv=C.defaultdict(list)
for r in px: byv[r['v']].append(r)
random.seed(234)
for name,get in [('S',lambda r:r['S_j']),('COMB',lambda r:g(r,'STRIP|primary(0,60d)').get('COMB_j')),('COMBone_head',lambda r:g(r,'STRIP|primary(0,60d)').get('COMB_j') if (r['S_class']=='one' and r['pos']=='head') else None),('S_undec_wrong',lambda r:('disagree' if r['S_j']=='undecided' else r['S_j']))]:
    a,d=rate(px,get); vs=list(byv)
    bs=[]
    for _ in range(2000):
        smp=[random.choice(vs) for _ in vs]; A=D=0
        for v in smp:
            x,y=rate(byv[v],get);A+=x;D+=y
        if A+D: bs.append(A/(A+D))
    bs.sort()
    print(name,a,d,round(a/(a+d),4),'volume-bootstrap 95%',round(bs[50],3),round(bs[1949],3),'min per-vol',min((rate(byv[v],get)[0]/max(1,sum(rate(byv[v],get))),v) for v in vs))
# 1873 per volume by entity for CH STRIP disagreements share by entity
