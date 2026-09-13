import json, gzip, os, glob, collections, statistics
H=os.path.expanduser
REPO='/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5'
STUDIO='/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw'
scope=json.load(open(H('~/frus-ner-raw/scope.json')))
vols=scope['volumes']
man={v['volumeId']:v for v in json.load(open(REPO+'/FRUSExplorer/Resources/manifest.json'))}
def year(v):
    return int(man[v]['dateRange']['earliest'][:4])
def band(y):
    return '1861-1899' if y<1900 else '1900-1929' if y<1930 else '1930-1945' if y<1946 else '1946-'
def head(p):
    return json.load(open(p))
def rows(pattern):
    for p in glob.glob(pattern):
        if p.endswith('.gz'):
            f=gzip.open(p,'rt',encoding='utf-8')
        else:
            f=open(p,encoding='utf-8')
        with f:
            for line in f:
                if line.strip(): yield json.loads(line)
agg=collections.defaultdict(lambda: collections.Counter())
keys=['vols','docs','chars','marked','ctrl_raw','ctrl_filt','sweep_raw','sweep_filt','sweep_boundary','sweep_secs','ctrl_secs']
names_all=set(); names_pre=set()
triples_marked=collections.Counter(); triples_ctrl=collections.Counter(); triples_sweep=collections.Counter()
nlen=[]
for v in vols:
    y=year(v); b=band(y); pre = y<1910
    groups=['ALL', b] + (['PRE1910'] if pre else ['POST1910'])
    mh=head(H(f'~/frus-ner-raw/marked/{v}.head.json'))
    cr=head(H(f'~/frus-ner-raw-control/detected/{v}.head.json'))
    cf=head(H(f'~/frus-ner-raw-control-filtered/detected/{v}.head.json'))
    sr=head(f'{STUDIO}/detected/{v}.head.json')
    sf=head(H(f'~/frus-ner-raw-filtered/detected/{v}.head.json'))
    sb=head(H(f'~/frus-ner-raw-filtered-boundary/detected/{v}.head.json'))
    vals=dict(vols=1,docs=mh['docs'],chars=mh['chars'],marked=mh['mentions'],ctrl_raw=cr['mentions'],ctrl_filt=cf['mentions'],sweep_raw=sr['mentions'],sweep_filt=sf['mentions'],sweep_boundary=sb['mentions'],sweep_secs=sr.get('secs',0),ctrl_secs=cr.get('secs',0))
    for g in groups:
        for k in keys: agg[g][k]+=vals[k]
    # distinct names + (doc,name) triples from marked layer
    dm=set()
    for r in rows(H(f'~/frus-ner-raw/marked/{v}.jsonl.gz')):
        n=' '.join(r['n'].split()); names_all.add(n); nlen.append(len(n))
        if pre: names_pre.add(n)
        dm.add((r['d'],n.lower()))
    for g in groups: triples_marked[g]+=len(dm)
    dc=set()
    for r in rows(H(f'~/frus-ner-raw-control-filtered/detected/{v}.jsonl*')):
        dc.add((r['d'],' '.join(r['n'].split()).lower()))
    for g in groups: triples_ctrl[g]+=len(dc)
    ds=set()
    for r in rows(H(f'~/frus-ner-raw-filtered/detected/{v}.jsonl*')):
        ds.add((r['d'],' '.join(r['n'].split()).lower()))
    for g in groups: triples_sweep[g]+=len(ds)
out={}
for g in ['ALL','PRE1910','POST1910','1861-1899','1900-1929','1930-1945','1946-']:
    d=dict(agg[g]); d['distinct_doc_name_marked']=triples_marked[g]; d['distinct_doc_name_ctrl_filt']=triples_ctrl[g]; d['distinct_doc_name_sweep_filt']=triples_sweep[g]
    d['sweep_days']=round(d['sweep_secs']/86400,2); out[g]=d
out['distinct_marked_name_strings_all']=len(names_all)
out['distinct_marked_name_strings_pre1910']=len(names_pre)
out['mean_marked_name_len_chars']=round(statistics.mean(nlen),1)
out['pre1910_volume_rule']='manifest dateRange.earliest year < 1910'
json.dump(out,open(os.path.dirname(os.path.abspath(__file__))+'/slice-output.json','w'),indent=1)
print(json.dumps(out,indent=1))
