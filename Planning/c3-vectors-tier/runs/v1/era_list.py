import sys
from h import *
lo,hi,minc=sys.argv[1],sys.argv[2],int(sys.argv[3])
c=con()
SQL="""SELECT d.volume_id,d.document_id,dd.date_iso,substr(replace(d.header,char(10),' '),1,110),
 (length(d.body_text)-length(replace(lower(d.body_text),'cuba','')))/4 AS n, length(d.body_text) L
FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE frus_documents MATCH 'cuba OR cuban' AND d.is_front_matter=0 AND d.is_editorial_note=0
AND dd.date_iso>=? AND dd.date_iso<? ORDER BY dd.date_iso"""
for r in c.execute(SQL,(lo,hi)):
    if r[4]>=minc: print(*r,sep=" | ")
