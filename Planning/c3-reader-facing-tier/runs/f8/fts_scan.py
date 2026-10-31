import sqlite3,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open('ea_vols.txt') if l.strip()]
vl=",".join("'%s'"%v for v in vols)
terms=sys.argv[1:]
for t in terms:
    sql=f"""SELECT COUNT(*), COUNT(DISTINCT dc.volume_id) FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid
WHERE frus_documents MATCH ? AND dc.volume_id IN ({vl}) AND dc.is_front_matter=0 AND dc.is_editorial_note=0"""
    n,v=c.execute(sql,(t,)).fetchone()
    print(f"{n}\t{v}\t{t}",flush=True)
tot=c.execute(f"SELECT COUNT(*) FROM document_cache WHERE volume_id IN ({vl}) AND is_front_matter=0 AND is_editorial_note=0").fetchone()[0]
print("SCOPE_DOCS",tot)
