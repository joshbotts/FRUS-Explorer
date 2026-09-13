"""Independent store counts: count ROWS in each layer file (not head.json sums); docs from the R-0 text layer."""
import gzip, json, os, glob, collections
H=os.path.expanduser
def nrows(p):
    op=gzip.open if p.endswith('.gz') else open
    n=0; keys=collections.Counter()
    with op(p,'rt',encoding='utf-8') as f:
        for l in f:
            if l.strip():
                n+=1
                if n<=3: keys.update(json.loads(l).keys())
    return n, keys
out={}
scope=json.load(open(H('~/frus-ner-raw/scope.json')))
out['scope_json_volumes']=len(scope['volumes']); out['scope_keys']=list(scope.keys())
# marked layer rows + corresp presence
mk=sorted(glob.glob(H('~/frus-ner-raw/marked/*.jsonl*')))
tot=0; corresp=0; keyset=collections.Counter(); typed=collections.Counter()
for p in mk:
    op=gzip.open if p.endswith('.gz') else open
    with op(p,'rt',encoding='utf-8') as f:
        for l in f:
            if not l.strip(): continue
            r=json.loads(l); tot+=1; keyset.update(r.keys())
            if r.get('corresp') or r.get('c'): corresp+=1
            typed[r.get('type',r.get('ty','?'))]+=1
out['marked']={'files':len(mk),'rows':tot,'rows_with_corresp':corresp,'keys':dict(keyset),'by_type':dict(typed)}
# docs in scope from text layer
docs=0; missing=[]
for v in scope['volumes']:
    p=None
    for suf in ('.jsonl','.jsonl.gz'):
        q=H('~/frus-semantic-raw/text/')+v+suf
        if os.path.exists(q): p=q
    if p is None: missing.append(v); continue
    n,_=nrows(p); docs+=n
out['text_layer_docs_in_scope']={'docs':docs,'missing_volumes':missing}
out['text_layer_volume_files']=len(glob.glob(H('~/frus-semantic-raw/text/*.jsonl*')))
# detected layers
for name,d in [('sweep_raw_studio','/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw'),
               ('sweep_filtered',H('~/frus-ner-raw-filtered')),('sweep_boundary',H('~/frus-ner-raw-filtered-boundary')),
               ('control',H('~/frus-ner-raw-control')),('control_filtered',H('~/frus-ner-raw-control-filtered')),
               ('local_frus_ner_raw_detected',H('~/frus-ner-raw'))]:
    files=sorted(glob.glob(os.path.join(d,'detected','*.jsonl*'))); heads=sorted(glob.glob(os.path.join(d,'detected','*.head.json')))
    rows=0; hm=0; hd=0; sampled=collections.Counter()
    for p in files: rows+=nrows(p)[0]
    for h in heads:
        j=json.load(open(h)); hm+=j.get('mentions',0) or 0; hd+=j.get('docs',0) or 0; sampled[str(j.get('sampled'))]+=1
    out[name]={'jsonl_files':len(files),'head_files':len(heads),'rows':rows,'head_mentions_sum':hm,'head_docs_sum':hd,'sampled':dict(sampled),'all_files_in_dir':len(glob.glob(os.path.join(d,'detected','*')))}
json.dump(out,open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'count_stores.json'),'w'),indent=1)
print(json.dumps(out,indent=1))
