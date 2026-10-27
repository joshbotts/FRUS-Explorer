# Literal frame census over W, BODY_TEXT only (source note excluded; footnotes still included), whitespace-collapsed, Python re.I.
# Plus false-friend test for the question's own terms: share in W vs share in all dated non-apparatus docs, same decade (FTS, porter).
import sqlite3,re,collections
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
W={tuple(l.split('\t')[:2]):l.split('\t')[2] for l in open('cuba_set.tsv')}
SEP=r'[\s\-,().]+'
inst=re.compile(r'\bnational'+SEP+r'securit(?:y|ies)'+SEP+r'(?:files?|council|action|advis[eo]r|affairs|agency|archives?|memorand\w*|stud\w*|decision\w*|staff|policy papers?|documents?)\b',re.I)
F={'american_property_citizens':r'\bAmerican'+SEP+r'(?:citizens?|property|properties|interests?|capital|investments?)\b',
   'commerce_trade':r'\b(?:commerce|commercial|trade)\b',
   'sugar':r'\bsugars?\b',
   'insurrection_revolution':r'\b(?:insurrection\w*|insurgen\w*|revolution\w*|filibuster\w*)\b',
   'order_stability':r'\b(?:stability|stable government|public order|law and order)\b',
   'slavery':r'\b(?:slaves?|slavery|emancipation)\b',
   'annex_intervene':r'\b(?:annex\w*|interven\w*)\b',
   'strategic_defense':r'\b(?:strategic\w*|defen[cs]e|naval station|Guantanamo|hemisphere defense)\b',
   'communist_soviet':r'\b(?:communis[mt]s?|communistic|soviets?|Sino-Soviet)\b',
   'missiles':r'\bmissiles?\b',
   'national_security_prose':r'\bnational'+SEP+r'securit(?:y|ies)\b',
   'prosperity':r'\bprosper\w*',
   'migration':r'\b(?:refugees?|exiles?|emigra\w*|migra\w*|Mariel)\b'}
cp={k:re.compile(v,re.I) for k,v in F.items()}
N=collections.Counter(); R=collections.defaultdict(collections.Counter)
for (v,d),iso in W.items():
    if not iso: continue
    dec=iso[:3]+'0s'
    b=' '.join(c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0].split())
    b2=inst.sub(' ',b)
    N[dec]+=1
    for k,p in cp.items():
        if p.search(b2 if k=='national_security_prose' else b): R[k][dec]+=1
decs=sorted(N)
with open('s12_frames.tsv','w') as f:
    f.write('frame\t'+'\t'.join(decs)+'\n'); f.write('N\t'+'\t'.join(str(N[d]) for d in decs)+'\n')
    for k in F: f.write(k+'\t'+'\t'.join("%d"%R[k][d] for d in decs)+'\n')
print(open('s12_frames.tsv').read())
# false friend
base=collections.Counter(); 
for v,d,iso in c.execute("SELECT dc.volume_id,dc.document_id,dd.date_iso FROM document_cache dc JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0 AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso LIKE '196%'"): base[(v,d)]=1
def fts(q): return set(c.execute("SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH ?",(q,)).fetchall())
W60={k for k,i in W.items() if i.startswith('196')}
for q in ['"national security"','prosperity OR prosperous','"department of state"']:
    h=fts(q); a=len(h&W60); b=len(h&set(base))
    print("FALSE-FRIEND 1960s",q,": W %d of %d ; corpus %d of %d"%(a,len(W60),b,len(base)))
