# came-from: SELECT repository, record_group, lot_file_norm, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?
# pointed-at: SELECT repository, collection, lot_file_norm, decimal_class, anchor FROM external_citations WHERE volume_id=? AND document_id=?
import sqlite3,collections
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pairs=[l.strip().split('|') for l in open('candidate_set.txt') if l.strip()]
cf=collections.Counter(); era=collections.Counter(); pa=collections.Counter(); pa_docs=collections.defaultdict(set); cf_docs=collections.defaultdict(set)
nosrc=0
for v,d in pairs:
    r=c.execute("SELECT repository, record_group, lot_file_norm, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: nosrc+=1; continue
    key=(r[0],r[1],r[2],r[3]); cf[key]+=1; era[r[4]]+=1; cf_docs[key].add((v,d))
    for row in c.execute("SELECT repository, collection, lot_file_norm, decimal_class, anchor FROM external_citations WHERE volume_id=? AND document_id=?",(v,d)):
        k2=(row[0],row[1],row[2]); pa[k2]+=1; pa_docs[k2].add((v,d))
print('pairs',len(pairs),'without document_sources row',nosrc)
print('citation_era',era.most_common())
print('--- CAME-FROM (document_sources), docs per unit')
for k,n in cf.most_common(30): print(n,k)
print('--- POINTED-AT (external_citations), rows / distinct docs')
for k,n in pa.most_common(30): print(n,len(pa_docs[k]),k)
