import sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open("work/ea_vols_list.txt")]
ph=",".join("?"*len(vols))
q='header:("information agency" OR "information service" OR "information program" OR "information policy" OR "psychological" OR propaganda OR "voice of america" OR usia OR usis OR "cultural" OR "public affairs" OR "public diplomacy" OR "educational exchange" OR "information activities" OR "information and cultural" OR "image of the united states")'
sql=f"""SELECT d.volume_id,d.document_id,replace(substr(d.header,1,210),char(10),' '),length(d.body_text) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH ? AND d.volume_id IN ({ph}) AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id,d.rowid"""
rows=db.execute(sql,[q]+vols).fetchall()
for r in rows: print("|".join(map(str,r)))
print("N",len(rows))
