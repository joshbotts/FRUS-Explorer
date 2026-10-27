# Literal census over the working set W (cuba_set.tsv). Surface: header+dateline+source_note+body_text concatenated, whitespace-collapsed (index's flattened text; footnotes included).
# Python re with re.I (case-insensitive). STRICT = single spaces; TOLERANT = inflections + [\s\-,().]+ separators.
import sqlite3,re,collections,json,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
W=[tuple(l.rstrip('\n').split('\t')) for l in open('cuba_set.tsv')]
SEP=r'[\s\-,().]+'
pats={
 'ns_strict':r'\bnational security\b',
 'ns_tol':r'\bnational'+SEP+r'securit(?:y|ies)\b',
 'communis_lit':r'\bcommunis(?:m|t|ts|tic)\b',
 'commun_other':r'\bcommunicat\w*',
 'soviet_lit':r'\bsoviets?\b',
 'sugar_lit':r'\bsugars?\b',
 'security_lit':r'\bsecurity\b',
 'prosper_lit':r'\bprosper\w*',
 'strategic_lit':r'\bstrategic\w*',
}
cp={k:re.compile(v,re.I) for k,v in pats.items()}
res=collections.defaultdict(collections.Counter); tot=collections.Counter()
hits={}
byvol=collections.defaultdict(list)
for v,d,iso,flag in W: byvol[v].append((d,iso))
SQL="SELECT document_id, header, coalesce(dateline,''), coalesce(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?"
for v in sorted(byvol):
    for d,iso in byvol[v]:
        r=c.execute(SQL,(v,d)).fetchone()
        t=' '.join(' '.join(r[1:]).split())
        dec=(iso[:3]+'0s') if iso else 'undated'
        tot[dec]+=1
        h={}
        for k,p in cp.items():
            if p.search(t): res[k][dec]+=1; h[k]=1
        hits[v+'/'+d]=h
json.dump(hits,open('s5_hits.json','w'))
print("SQL per doc:",SQL)
decs=sorted(tot)
print("pattern\t"+'\t'.join(decs))
print("N\t"+'\t'.join(str(tot[d]) for d in decs))
for k in pats: print(k+'\t'+'\t'.join("%d"%res[k][d] for d in decs))
