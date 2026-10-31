import sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
PD=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30','frus1955-57v09','frus1961-63v25','frus1917-72PubDip']
Q='(Asia OR Asian OR "Far East" OR Vietnam OR Japan OR Japanese OR Korea OR Indonesia OR Philippines OR Thailand OR China OR Chinese OR Taiwan OR Pacific)'
for v in PD:
    tot=db.execute("select count(*) from document_cache where volume_id=? and is_front_matter=0 and is_editorial_note=0",(v,)).fetchone()[0]
    hit=db.execute("""SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id=? AND d.is_front_matter=0 AND d.is_editorial_note=0""",(Q+' AND "United States Information" ',v)).fetchone()[0]
    hit2=db.execute("""SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id=? AND d.is_front_matter=0 AND d.is_editorial_note=0""",(Q,v)).fetchone()[0]
    print(v,"docs",tot,"Asia-term docs",hit2,"with 'United States Information'",hit)
