# channels.py: archival channels over raw/coreset_clean.tsv (C).
# came-from: SELECT repository, record_group, lot_file_norm, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?
# pointed-at: SELECT repository, collection, lot_file_norm, decimal_class FROM external_citations WHERE volume_id=? AND document_id=?  (no broken filter applies; that is cross_references)
import sqlite3,collections,json
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
C=[tuple(l.split('\t')) for l in open('raw/coreset_clean.tsv').read().split('\n') if l]
cf=collections.Counter(); cfrg=collections.Counter(); era=collections.Counter(); nsrc=0
pa=collections.Counter(); padocs=collections.defaultdict(set); npa=0
for v,d in C:
    r=con.execute("SELECT repository, record_group, lot_file_norm, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if r:
        nsrc+=1; era[r[4]]+=1; cfrg[(r[0],r[1])]+=1
        cf[(r[0],r[1],r[2],r[3])]+=1
    rows=con.execute("SELECT repository, collection, lot_file_norm FROM external_citations WHERE volume_id=? AND document_id=?",(v,d)).fetchall()
    if rows: npa+=1
    for rr in rows:
        k=(rr[0],rr[1],rr[2]); padocs[k].add((v,d))
print('C docs',len(C),'with a came-from row',nsrc,'with >=1 pointed-at row',npa)
print('citation form split (came-from):',era.most_common())
print('\nCAME-FROM by repository/record group (docs):')
for k,c in cfrg.most_common(15): print(c,k)
print('\nCAME-FROM top lot/series (docs):')
for k,c in [(k,c) for k,c in cf.most_common(60) if k[2] or k[3]][:25]: print(c,k)
print('\nPOINTED-AT top (distinct citing docs):')
for k,s in sorted(padocs.items(),key=lambda x:-len(x[1]))[:25]: print(len(s),k)
