# Independent re-derivation of RC-4 / RC-6 / RC-13 row counts. Counts ROWS (not head.json) and
# measures the exact union of (doc, name) pairs, plus real serialized bytes for a shape (a)/(b) artifact.
import json, gzip, os, glob, collections, sys
H=os.path.expanduser
REPO='/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5'
STUDIO='/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw'
scope=json.load(open(H('~/frus-ner-raw/scope.json')))['volumes']
man={v['volumeId']:v for v in json.load(open(REPO+'/FRUSExplorer/Resources/manifest.json'))}
def yr_manifest(v): return int(man[v]['dateRange']['earliest'][:4])
def yr_id(v):
    import re; return int(re.search(r'frus(\d{4})',v).group(1))
def norm(n): return ' '.join(n.split()).lower()
def read(path):
    op=gzip.open if path.endswith('.gz') else open
    with op(path,'rt',encoding='utf-8') as f:
        return [json.loads(l) for l in f if l.strip()]
def one(dirp,v):
    c=[dirp+'/'+v+s for s in ('.jsonl','.jsonl.gz') if os.path.exists(dirp+'/'+v+s)]
    assert len(c)==1,(dirp,v,c); return c[0]
MARK=H('~/frus-ner-raw/marked'); CTRL=H('~/frus-ner-raw-control-filtered/detected'); CTRLRAW=H('~/frus-ner-raw-control/detected')
TEXT=H('~/frus-semantic-raw/text')
G=collections.defaultdict(collections.Counter)
corpus={'m':set(),'c':set(),'u':set()}; corpus_pre={'m':set(),'c':set(),'u':set()}
mlen_mentions=0; mlen_rows_chars=0; mlen_rows_bytes=0
head_vs_rows_mismatch=[]
art_a={}; art_b={}
for v in scope:
    pre_man=yr_manifest(v)<1910; pre_id=yr_id(v)<1910
    groups=['ALL']+(['PRE_MAN'] if pre_man else [])+(['PRE_ID'] if pre_id else [])
    mrows=read(one(MARK,v)); crows=read(one(CTRL,v))
    mh=json.load(open(MARK+'/'+v+'.head.json')); ch=json.load(open(CTRL+'/'+v+'.head.json'))
    if mh['mentions']!=len(mrows) or ch['mentions']!=len(crows): head_vs_rows_mismatch.append((v,mh['mentions'],len(mrows),ch['mentions'],len(crows)))
    sh=json.load(open(STUDIO+'/detected/'+v+'.head.json')); crh=json.load(open(CTRLRAW+'/'+v+'.head.json'))
    tdocs=sum(1 for l in gzip.open(one(TEXT,v),'rt',encoding='utf-8') if l.strip())
    mp={(r['d'],norm(r['n'])) for r in mrows}; cp={(r['d'],norm(r['n'])) for r in crows}
    mn={n for _,n in mp}; cn={n for _,n in cp}
    up=mp|cp; un=mn|cn
    for r in mrows: mlen_mentions+=len(norm(r['n']))
    mlen_rows_chars+=sum(len(n) for n in mn); mlen_rows_bytes+=sum(len(n.encode('utf-8')) for n in mn)
    vals=dict(vols=1,docs_head=mh['docs'],docs_text=tdocs,chars=mh['chars'],marked=len(mrows),ctrl_filt=len(crows),
              ctrl_raw=crh['mentions'],sweep_raw=sh['mentions'],sweep_secs=sh.get('secs',0),ctrl_secs=crh.get('secs',0),
              pairs_m=len(mp),pairs_c=len(cp),pairs_u=len(up),pairs_overlap=len(mp&cp),
              names_m=len(mn),names_c=len(cn),names_u=len(un),names_overlap=len(mn&cn))
    for g in groups:
        for k,x in vals.items(): G[g][k]+=x
    for k,s in (('m',mn),('c',cn),('u',un)):
        corpus[k]|=s
        if pre_man: corpus_pre[k]|=s
    # shape (a) / (b) artifact rows, one-letter keys, per-volume grouped; ref = deterministic per (volume, name) ordinal-free: use name itself as key
    def pack(names,pairs):
        idx={n:i for i,n in enumerate(sorted(names))}
        bydoc=collections.defaultdict(list)
        for d,n in pairs: bydoc[d].append(idx[n])
        return {'p':sorted(names),'m':{d:sorted(l) for d,l in bydoc.items()}}
    art_a[v]=pack(mn,mp); art_b[v]=pack(un,up)
out={g:dict(c) for g,c in G.items()}
for g in out:
    out[g]['sweep_days']=round(out[g]['sweep_secs']/86400,2)
out['corpus_distinct']={k:len(s) for k,s in corpus.items()}
out['corpus_distinct_pre1910_manifest_rule']={k:len(s) for k,s in corpus_pre.items()}
out['mean_norm_name_len_per_marked_mention']=round(mlen_mentions/out['ALL']['marked'],2)
out['mean_norm_name_len_per_marked_persons_row_chars']=round(mlen_rows_chars/out['ALL']['names_m'],2)
out['mean_norm_name_len_per_marked_persons_row_utf8_bytes']=round(mlen_rows_bytes/out['ALL']['names_m'],2)
out['head_vs_rows_mismatch']=head_vs_rows_mismatch
def size(o,**kw): return len(json.dumps(o,separators=(',',':'),ensure_ascii=False,**kw).encode('utf-8'))
out['artifact_bytes_measured']={
 'shape_a_compact_oneletter_grouped':size(art_a),
 'shape_a_pretty_indent1':len(json.dumps(art_a,indent=1,ensure_ascii=False).encode('utf-8')),
 'shape_b_union_compact_oneletter_grouped':size(art_b),
 'shape_b_union_pretty_indent1':len(json.dumps(art_b,indent=1,ensure_ascii=False).encode('utf-8')),
}
# flat-row shape as the report's arithmetic assumes: [{"v":..,"d":..,"r":..}] per pair + [{"v":..,"r":..,"n":..}] per person
flat_a={'persons':[{'v':v,'r':'ner:'+n,'n':n} for v,a in art_a.items() for n in a['p']],
        'mentions':[{'v':v,'d':d,'r':'ner:'+a['p'][i]} for v,a in art_a.items() for d,l in a['m'].items() for i in l]}
out['artifact_bytes_measured']['shape_a_flat_rows_compact']=size(flat_a)
flat_b={'persons':[{'v':v,'r':'ner:'+n,'n':n} for v,a in art_b.items() for n in a['p']],
        'mentions':[{'v':v,'d':d,'r':'ner:'+a['p'][i]} for v,a in art_b.items() for d,l in a['m'].items() for i in l]}
out['artifact_bytes_measured']['shape_b_flat_rows_compact']=size(flat_b)
import zlib
out['artifact_bytes_measured']['shape_a_compact_gzip9']=len(zlib.compress(json.dumps(art_a,separators=(',',':'),ensure_ascii=False).encode('utf-8'),9))
out['artifact_bytes_measured']['shape_b_compact_gzip9']=len(zlib.compress(json.dumps(art_b,separators=(',',':'),ensure_ascii=False).encode('utf-8'),9))
json.dump(out,open(os.path.dirname(os.path.abspath(__file__))+'/rows-check-output.json','w'),indent=1)
print(json.dumps(out,indent=1))
