# Archival channels for the working set W. came-from = document_sources (one row per doc). pointed-at = external_citations (many rows per doc). Never summed.
import sqlite3,collections
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
W=set(tuple(l.split('\t')[:2]) for l in open('cuba_set.tsv'))
iso={tuple(l.split('\t')[:2]):l.split('\t')[2] for l in open('cuba_set.tsv')}
S1="SELECT volume_id, document_id, repository, record_group, lot_file_norm, series_name, citation_era, decimal_class FROM document_sources"
cf=collections.Counter(); era=collections.Counter(); n=0; lots=collections.Counter(); dec=collections.Counter(); rg=collections.Counter()
for v,d,rep,rgp,lot,ser,ce,dc in c.execute(S1):
    if (v,d) not in W: continue
    n+=1; era[ce]+=1
    cf[(rep or '-', ser or '-')]+=1
    if rgp: rg[rgp]+=1
    if lot: lots[lot]+=1
    if dc: dec[dc[:7]]+=1
print("came-from SQL:",S1,"(filtered in Python to W)")
print("W docs with a document_sources row:",n,"of",len(W))
print("citation_era (a FORM, not a date):",era.most_common())
print("top repository/series:"); [print(" ",k,v) for k,v in cf.most_common(25)]
print("top record_group:",rg.most_common(10))
print("top lots:",lots.most_common(25))
print("top decimal_class prefix:",dec.most_common(15))
S2="SELECT volume_id, document_id, anchor, repository, collection, lot_file_norm, decimal_class FROM external_citations"
pa=collections.Counter(); m=0; docs=set(); plot=collections.Counter(); pdec=collections.Counter(); anc=collections.Counter()
for v,d,a,rep,col,lot,dc in c.execute(S2):
    if (v,d) not in W: continue
    m+=1; docs.add((v,d)); anc[a]+=1
    pa[(rep or '-', col or '-')]+=1
    if lot: plot[lot]+=1
    if dc: pdec[dc[:7]]+=1
print("\npointed-at SQL:",S2,"(filtered in Python to W)")
print("rows:",m,"citing docs:",len(docs),"of",len(W)); print("anchors:",anc.most_common())
print("top repository/collection:"); [print(" ",k,v) for k,v in pa.most_common(20)]
print("top lots:",plot.most_common(20)); print("top decimal prefix:",pdec.most_common(15))
