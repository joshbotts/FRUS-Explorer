from h import *
c=conn()
Q='''(USIS OR USIA OR JUSPAO OR "Information Agency" OR "Information Service" OR "psychological warfare" OR "psychological operations" OR "psychological strategy" OR "information program" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "hearts and minds" OR "cultural program" OR "Asia Foundation" OR "leader grant" OR "information officer" OR "cultural affairs" OR "cultural relations" OR "public diplomacy" OR "information activities")'''
c.execute("CREATE TEMP TABLE S2 AS SELECT d.volume_id v, d.document_id i FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ?",(Q,))
c.execute("""CREATE TEMP TABLE S1 AS SELECT d.volume_id v, d.document_id i FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN G ON G.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH '(Vietnam OR Viet OR Korea OR Japan OR Japanese OR China OR Chinese OR Indonesia OR Philippines OR Thailand OR Laos OR Cambodia OR Asia OR Asian OR Taiwan OR Malaysia OR Singapore OR Pacific)' AND (d.header LIKE '%Asia%' OR d.header LIKE '%Viet%' OR d.header LIKE '%Japan%' OR d.header LIKE '%China%' OR d.header LIKE '%Chinese%' OR d.header LIKE '%Korea%' OR d.header LIKE '%Indonesia%' OR d.header LIKE '%Philippines%' OR d.header LIKE '%Thai%' OR d.header LIKE '%Pacific%' OR d.header LIKE '%Taiwan%' OR d.header LIKE '%Far East%')""")
for name in ('S1','S2'):
    print(name, c.execute(f"SELECT COUNT(*) FROM {name}").fetchone())
    SQL=f"SELECT s.repository, s.record_group, s.series_name, s.citation_era, COUNT(*) n FROM document_sources s JOIN {name} x ON x.v=s.volume_id AND x.i=s.document_id GROUP BY 1,2,3,4 ORDER BY n DESC LIMIT 18"
    print(SQL)
    for r in c.execute(SQL): print('  ',r)
    SQL=f"SELECT s.lot_file, s.record_group, COUNT(*) n FROM document_sources s JOIN {name} x ON x.v=s.volume_id AND x.i=s.document_id WHERE s.lot_file IS NOT NULL GROUP BY 1,2 ORDER BY n DESC LIMIT 18"
    print(SQL)
    for r in c.execute(SQL): print('  ',r)
    SQL=f"SELECT e.repository, e.collection, e.lot_file_norm, COUNT(*) n, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs FROM external_citations e JOIN {name} x ON x.v=e.volume_id AND x.i=e.document_id GROUP BY 1,2,3 ORDER BY n DESC LIMIT 18"
    print(SQL)
    for r in c.execute(SQL): print('  ',r)
