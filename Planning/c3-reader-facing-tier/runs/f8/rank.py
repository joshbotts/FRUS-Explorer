import sqlite3,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
volfile,q,lim=sys.argv[1],sys.argv[2],int(sys.argv[3])
vols=[l.strip() for l in open(volfile) if l.strip()]
vl=",".join("'%s'"%v for v in vols)
sql=f"""SELECT dc.volume_id, dc.document_id, bm25(frus_documents) AS score, length(dc.body_text), substr(replace(dc.header,char(10),' '),1,150), dd.date_iso
FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid
LEFT JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id
WHERE frus_documents MATCH ? AND dc.volume_id IN ({vl}) AND dc.is_front_matter=0 AND dc.is_editorial_note=0
ORDER BY score ASC LIMIT {lim}"""
for r in c.execute(sql,(q,)):
    print("\t".join(str(x) for x in r))
