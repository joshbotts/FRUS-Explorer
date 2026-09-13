"""Independent re-derivation of the M2a score (read-only, stdlib). Own matcher, own readers.
Strict hit = distinct predicted (s,e) also in gold (s,e). Relaxed = maximum-cardinality one-to-one
matching over positive-overlap pairs, computed here by augmenting paths seeded from the PREDICTION side
(the scorer seeds from the gold side; cardinality is order-invariant, so equality is a real check)."""
import gzip, json, os, sys, collections
M2A='/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a'
STUDIO='/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw'
H=os.path.expanduser
STORES=[('editor',H('~/frus-ner-raw'),'marked'),('sweep_raw',STUDIO,'detected'),
        ('sweep_boundary',H('~/frus-ner-raw-filtered-boundary'),'detected'),
        ('sweep_filtered',H('~/frus-ner-raw-filtered'),'detected'),
        ('control',H('~/frus-ner-raw-control'),'detected'),
        ('control_filtered',H('~/frus-ner-raw-control-filtered'),'detected')]
def rows(path):
    op=gzip.open if path.endswith('.gz') else open
    with op(path,'rt',encoding='utf-8') as f:
        return [json.loads(l) for l in f if l.strip()]
def find(d,v):
    for suf in ('.jsonl','.jsonl.gz'):
        p=os.path.join(d,v+suf)
        if os.path.exists(p): return p
    return None
# gold
gold=collections.defaultdict(list); band={}
for r in rows(f'{M2A}/m2a-ground-truth.jsonl'):
    gold[(r['v'],r['d'])].append((r['s'],r['e'],r['n'])); band[(r['v'],r['d'])]=r['band']
listed=0
for r in rows(f'{M2A}/m2a-ground-truth-documents.jsonl'):
    k=(r['v'],r['d']); listed+=1; band[k]=r['band']; gold.setdefault(k,[])
    assert r['mentions']==len(gold[k]),k
out={'gold_docs':len(gold),'gold_docs_listed':listed,'gold_mentions':sum(len(v) for v in gold.values()),
     'gold_docs_no_mentions':sum(1 for v in gold.values() if not v),
     'gold_by_band':{b:{'docs':sum(1 for k in gold if band[k]==b),'mentions':sum(len(gold[k]) for k in gold if band[k]==b)} for b in sorted(set(band.values()))}}
def maxmatch(g,p):
    # bipartite: preds -> golds with overlap>0
    adj=[[gi for gi,(gs,ge,_) in enumerate(g) if min(ge,pe)-max(gs,ps)>0] for (ps,pe,_) in p]
    mg={}  # gold index -> pred index
    def aug(pi,seen):
        for gi in adj[pi]:
            if gi in seen: continue
            seen.add(gi)
            if gi not in mg or aug(mg[gi],seen):
                mg[gi]=pi; return True
        return False
    return sum(1 for pi in range(len(p)) if aug(pi,set()))
def prf(h,pc,gc):
    P=h/pc if pc else 0; R=h/gc if gc else 0; F=2*P*R/(P+R) if P+R else 0
    return {'P':round(P,4),'R':round(R,4),'F1':round(F,4),'hits':h,'pred':pc,'gold':gc}
vols=sorted({k[0] for k in gold})
for name,d,layer in STORES:
    tot={'s':0,'r':0,'p':0,'g':0}; bb=collections.defaultdict(lambda:{'s':0,'r':0,'p':0,'g':0,'n':0}); scored=0; refused=[]
    for v in vols:
        p=find(os.path.join(d,layer),v)
        if p is None: refused.append(v); continue
        if layer=='detected':
            head=json.load(open(os.path.join(d,layer,v+'.head.json')))
            assert head.get('sampled') is False,(name,v,head.get('sampled'))
        by=collections.defaultdict(set)
        for r in rows(p): by[r['d']].add((r['s'],r['e'],r['n']))
        for k in [k for k in gold if k[0]==v]:
            pred=sorted(by.get(k[1],set())); g=gold[k]; scored+=1
            s=len({(a,b) for a,b,_ in pred}&{(a,b) for a,b,_ in g}); r=maxmatch(g,pred)
            for T in (tot,bb[band[k]]):
                T['s']+=s; T['r']+=r; T['p']+=len(pred); T['g']+=len(g)
            bb[band[k]]['n']+=1
    out[name]={'docs_scored':scored,'refused':refused,'strict':prf(tot['s'],tot['p'],tot['g']),'relaxed':prf(tot['r'],tot['p'],tot['g']),
               'by_band':{b:{'docs':x['n'],'strict':prf(x['s'],x['p'],x['g']),'relaxed':prf(x['r'],x['p'],x['g'])} for b,x in sorted(bb.items())}}
# post-hoc unions (editor ∪ X): union of distinct spans per doc
def union_score(a,b):
    tot={'r':0,'p':0,'g':0}
    for v in vols:
        ba=collections.defaultdict(set); bbb=collections.defaultdict(set)
        for r in rows(find(os.path.join(a[0],a[1]),v)): ba[r['d']].add((r['s'],r['e'],r['n']))
        for r in rows(find(os.path.join(b[0],b[1]),v)): bbb[r['d']].add((r['s'],r['e'],r['n']))
        for k in [k for k in gold if k[0]==v]:
            pred=sorted(ba[k[1]]|bbb[k[1]]); tot['r']+=maxmatch(gold[k],pred); tot['p']+=len(pred); tot['g']+=len(gold[k])
    return prf(tot['r'],tot['p'],tot['g'])
out['union_editor_control_filtered_relaxed']=union_score((H('~/frus-ner-raw'),'marked'),(H('~/frus-ner-raw-control-filtered'),'detected'))
out['union_editor_sweep_filtered_relaxed']=union_score((H('~/frus-ner-raw'),'marked'),(H('~/frus-ner-raw-filtered'),'detected'))
json.dump(out,open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'rescore.json'),'w'),indent=1)
print(json.dumps(out,indent=1))
