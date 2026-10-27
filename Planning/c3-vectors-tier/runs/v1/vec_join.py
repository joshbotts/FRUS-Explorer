import sqlite3
from vec import *
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for a in [("frus1950v02","d440"),("frus1874","d552")]:
    print("ANCHOR",a)
    for d,r in neighbours(row_of[a],10):
        v,i=doc_of[r]
        x=c.execute("""SELECT dd.date_iso, ds.citation_era, ds.repository, ds.record_group, ds.lot_file_norm, (SELECT COUNT(*) FROM external_citations ec WHERE ec.volume_id=d.volume_id AND ec.document_id=d.document_id)
           FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id LEFT JOIN document_sources ds ON ds.volume_id=d.volume_id AND ds.document_id=d.document_id
           WHERE d.volume_id=? AND d.document_id=?""",(v,i)).fetchone()
        print("  ham %3d %s/%s date=%s | came-from era=%s repo=%s RG=%s lot=%s | footnote citations (pointed-at rows)=%s"%((d,v,i)+x))
