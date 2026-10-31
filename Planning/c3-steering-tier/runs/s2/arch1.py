import sqlite3, json
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
pairs=[l.strip().split("/") for l in open("cited.txt") if l.strip()]
S1="SELECT repository, record_group, lot_file_norm, series_name, citation_era, decimal_class, substr(raw_text,1,160) FROM document_sources WHERE volume_id=? AND document_id=?"
S2="SELECT note_ordinal, anchor, repository, collection, lot_file_norm, decimal_class, substr(raw_text,1,140) FROM external_citations WHERE volume_id=? AND document_id=?"
print("CAME-FROM SQL:", S1); print("POINTED-AT SQL:", S2)
for v,d in pairs:
    print("==", v, d)
    for r in con.execute(S1,(v,d)): print("  FROM:", r)
    for r in con.execute(S2,(v,d)): print("  CITES:", r)
