from h import *
c=conn()
Q='(Vietnam OR Viet OR Korea OR Japan OR Japanese OR China OR Chinese OR Indonesia OR Philippines OR Thailand OR Laos OR Cambodia OR Asia OR Asian OR Taiwan OR Malaysia OR Singapore OR Pacific)'
SQL="SELECT f.volume_id, f.document_id, bm25(frus_documents) s, substr(replace(d.header,char(10),' '),1,120), d.dateline, length(d.body_text) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN G ON G.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? AND (d.header LIKE '%Asia%' OR d.header LIKE '%Viet%' OR d.header LIKE '%Japan%' OR d.header LIKE '%China%' OR d.header LIKE '%Chinese%' OR d.header LIKE '%Korea%' OR d.header LIKE '%Indonesia%' OR d.header LIKE '%Philippines%' OR d.header LIKE '%Thai%' OR d.header LIKE '%Pacific%' OR d.header LIKE '%Taiwan%' OR d.header LIKE '%Far East%') ORDER BY f.volume_id, f.document_id"
print(SQL);print(Q)
rows=c.execute(SQL,(Q,)).fetchall()
print(len(rows))
for r in rows: print(r[0],r[1],r[5],'|',r[3],'|',(r[4] or '')[:40])
