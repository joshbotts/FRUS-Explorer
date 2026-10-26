# scope_build.py: union of setA_pairs.tsv (chapter-defined) and the flagged rows of setB_classified.tsv (FTS-defined, hand-classified);
# writes scope_pairs.tsv; counts by decade of document_dates.date_iso (frus:doc-dateTime-min) against decade_denominators.tsv;
# came-from channel: SELECT repository, record_group, series_name, lot_file_norm, citation_era, decimal_class FROM document_sources WHERE volume_id=? AND document_id=?
# pointed-at channel: SELECT repository, collection, lot_file_norm, decimal_class, raw_text FROM external_citations WHERE volume_id=? AND document_id=?
import sqlite3,collections,os
os.chdir('/Users/jbotts/frus-analysis/c3/runs/r9')
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
A=[(l.split('\t')[0],l.split('\t')[1]) for l in open('setA_pairs.tsv').read().splitlines()]
B=[(p[0],p[1]) for p in (l.split('\t') for l in open('setB_classified.tsv').read().splitlines()) if p[2]=='1']
scope=collections.OrderedDict()
for v,d in A: scope[(v,d)]='A'
for v,d in B: scope[(v,d)]=scope.get((v,d),'')+'B'
with open('scope_pairs.tsv','w') as f:
    for (v,d),ch in scope.items(): f.write(f"{v}\t{d}\t{ch}\n")
out=open('scope_stats.txt','w')
def P(*a):
    s=' '.join(str(x) for x in a); print(s); out.write(s+'\n')
P('Set A pairs',len(A),'Set B relevant',len(B),'overlap',sum(1 for c in scope.values() if c=='AB'),'SCOPE union',len(scope))
P('scope volumes',len(set(v for v,d in scope)))
# decades
den={l.split('|')[0]:int(l.split('|')[1]) for l in open('decade_denominators.tsv').read().splitlines()}
dec=collections.Counter(); undated=0; topvol=collections.defaultdict(collections.Counter)
for v,d in scope:
    r=con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if r and r[0]: k=r[0][:3]+'0s'; dec[k]+=1; topvol[k][v]+=1
    else: undated+=1
P('undated in scope',undated)
P('decade\tscope_n\tdecade_dated_nonapparatus\tper_1000\ttop_volume_share')
for k in sorted(dec):
    tv=topvol[k].most_common(1)[0]
    P(f"{k}\t{dec[k]}\t{den.get(k,0)}\t{1000*dec[k]/den[k]:.2f}\t{tv[0]} {tv[1]} of {dec[k]}")
# came-from
cf=collections.Counter(); cf_era=collections.Counter(); cf_rows=0; cf_missing=0
for v,d in scope:
    r=con.execute("SELECT repository, record_group, series_name, lot_file_norm, citation_era, decimal_class FROM document_sources WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: cf_missing+=1; continue
    cf_rows+=1; cf_era[r[4]]+=1
    cf[(r[0] or '-', r[1] or '-', (r[2] or '-')[:60], r[3] or '-')]+=1
P('CAME-FROM (document_sources) rows',cf_rows,'scope documents with no row',cf_missing)
P('citation_era (a citation FORM, not a date):',dict(cf_era))
with open('came_from.tsv','w') as f:
    f.write('n\trepository\trecord_group\tseries_name\tlot_file_norm\n')
    for k,n in cf.most_common(): f.write(f"{n}\t"+'\t'.join(k)+'\n')
P('top came-from targets:')
for k,n in cf.most_common(18): P(f"  {n}\t{k}")
# pointed-at
pa=collections.Counter(); pa_rows=0; pa_docs=0
for v,d in scope:
    rows=con.execute("SELECT repository, collection, lot_file_norm, decimal_class FROM external_citations WHERE volume_id=? AND document_id=?",(v,d)).fetchall()
    if rows: pa_docs+=1
    for r in rows:
        pa_rows+=1; pa[(r[0] or '-', (r[1] or '-')[:60], r[2] or '-', r[3] or '-')]+=1
P('POINTED-AT (external_citations) rows',pa_rows,'in',pa_docs,'scope documents (no row before 1910-12-06 by construction)')
with open('pointed_at.tsv','w') as f:
    f.write('n\trepository\tcollection\tlot_file_norm\tdecimal_class\n')
    for k,n in pa.most_common(): f.write(f"{n}\t"+'\t'.join(k)+'\n')
P('top pointed-at targets:')
for k,n in pa.most_common(18): P(f"  {n}\t{k}")
out.close()
