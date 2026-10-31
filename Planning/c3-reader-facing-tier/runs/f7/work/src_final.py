import sys,sqlite3;sys.path.insert(0,"work")
from docs_spec import *
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pairs=[p for _,L in FINDINGS for p in L]
print("== CAME-FROM (document_sources, one row per document) for the 33 collection documents")
for v,d in pairs:
    r=db.execute("select record_group,repository,citation_era,lot_file_norm,series_name,substr(raw_text,1,130) from document_sources where volume_id=? and document_id=?",(v,d)).fetchone()
    print(v+"/"+d,"|",r)
print("== POINTED-AT (external_citations) rows for the 33")
for v,d in pairs:
    n=db.execute("select count(*) from external_citations where volume_id=? and document_id=?",(v,d)).fetchone()[0]
    if n:
        for r in db.execute("select repository,collection,lot_file_norm,substr(raw_text,1,100) from external_citations where volume_id=? and document_id=? limit 4",(v,d)): print(v+"/"+d,"|",r)
