import sqlite3,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
PD=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30','frus1955-57v09','frus1961-63v25']
Q='header:(Asia OR Asian OR "Far East" OR Vietnam OR Vietnamese OR Japan OR Japanese OR Korea OR Korean OR Indonesia OR Philippines OR Thailand OR China OR Chinese OR Taiwan OR Pacific OR Laos OR Cambodia OR Burma OR Malaysia OR Singapore OR Australia)'
for v in PD:
    for r in db.execute("""SELECT d.volume_id,d.document_id,substr(replace(d.header,char(10),' '),1,200),d.dateline FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id=? AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.rowid""",(Q,v)):
        print(r[0],r[1],re.sub(r"\s+"," ",r[2]),"|",(r[3] or "")[:60])
