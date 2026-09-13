import json, gzip, os, glob
H=os.path.expanduser
REPO='/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5'
scope=json.load(open(H('~/frus-ner-raw/scope.json')))['volumes']
man={v['volumeId']:int(v['dateRange']['earliest'][:4]) for v in json.load(open(REPO+'/FRUSExplorer/Resources/manifest.json'))}
def rows(pattern):
    for p in glob.glob(pattern):
        f=gzip.open(p,'rt',encoding='utf-8') if p.endswith('.gz') else open(p,encoding='utf-8')
        with f:
            for line in f:
                if line.strip(): yield json.loads(line)
def norm(n): return ' '.join(n.split()).lower()
out={}
for label,pat in [('marked','~/frus-ner-raw/marked/{v}.jsonl.gz'),('ctrl_filt','~/frus-ner-raw-control-filtered/detected/{v}.jsonl*'),('union','')]:
    tot=0; pre=0; corpus=set(); corpus_pre=set(); bytes_n=0
    for v in scope:
        s=set()
        pats=[pat] if pat else ['~/frus-ner-raw/marked/{v}.jsonl.gz','~/frus-ner-raw-control-filtered/detected/{v}.jsonl*']
        for p in pats:
            for r in rows(H(p.format(v=v))):
                n=norm(r['n']); s.add(n)
        tot+=len(s); bytes_n+=sum(len(x) for x in s); corpus|=s
        if man[v]<1910: pre+=len(s); corpus_pre|=s
    out[label]=dict(persons_rows_sum_per_volume_distinct=tot, pre1910=pre, corpus_distinct_strings=len(corpus), corpus_distinct_pre1910=len(corpus_pre), name_bytes_sum=bytes_n)
json.dump(out,open(os.path.dirname(os.path.abspath(__file__))+'/persons-rows-output.json','w'),indent=1)
print(json.dumps(out,indent=1))
