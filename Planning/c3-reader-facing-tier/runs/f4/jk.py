from h import *
c=conn()
Q='(USIS OR USIA OR "Information Agency" OR "Information Service" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "cultural program" OR "information program" OR CULCON OR "cultural relations")'
vols=('frus1961-63v22','frus1964-68v29p1','frus1964-68v29p2','frus1958-60v18','frus1955-57v23p1','frus1955-57v23p2','frus1969-76v19p1','frus1969-76v19p2','frus1952-54v14p2','frus1952-54v15p1','frus1952-54v15p2')
SQL="SELECT f.volume_id, f.document_id, round(bm25(frus_documents),1) s, substr(replace(d.header,char(10),' '),1,100), d.dateline, length(d.body_text) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (%s) AND frus_documents MATCH ? ORDER BY s LIMIT 28"%','.join("'%s'"%v for v in vols)
print(SQL);print(Q)
for r in c.execute(SQL,(Q,)): print(r[0],r[1],r[2],r[5],'|',r[3],'|',(r[4] or '')[:35])
