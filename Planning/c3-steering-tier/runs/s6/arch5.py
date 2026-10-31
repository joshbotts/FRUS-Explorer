import sqlite3, csv, collections
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
core={(r["volume_id"],r["document_id"]) for r in csv.DictReader(open("scan2.csv")) if int(r["nfam"])>=3}
print("core docs",len(core))
cf=collections.Counter(); n_src=0; era=collections.Counter()
for v,d,repo,rg,lot,ser,ce in con.execute("SELECT volume_id,document_id,repository,record_group,lot_file_norm,series_name,citation_era FROM document_sources"):
    if (v,d) in core:
        n_src+=1; era[ce]+=1
        cf[(repo,rg,ser if ce in("structured","named_series","cfpf") else (lot or ce))]+=1
print("SQL: SELECT volume_id,document_id,repository,record_group,lot_file_norm,series_name,citation_era FROM document_sources (filtered to the 479 core pairs in python)")
print("core docs with a document_sources row:",n_src,"of",len(core)); print("citation_era:",dict(era))
print("came-from top 14 (repository, RG, series-or-lot-or-era):")
for k,n in cf.most_common(14): print("  ",n,k)
pa=collections.Counter(); docs_pa=set(); rows=0
for v,d,repo,coll,lot in con.execute("SELECT volume_id,document_id,repository,collection,lot_file_norm FROM external_citations"):
    if (v,d) in core:
        rows+=1; docs_pa.add((v,d)); pa[(repo,coll or lot)]+=1
print("SQL: SELECT volume_id,document_id,repository,collection,lot_file_norm FROM external_citations (filtered to the 479 core pairs in python)")
print("pointed-at rows:",rows,"over",len(docs_pa),"core docs of",len(core))
for k,n in pa.most_common(14): print("  ",n,k)
