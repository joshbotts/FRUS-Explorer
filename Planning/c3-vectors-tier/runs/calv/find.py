# usage: find.py 'FTS expression' [limit] [volume_like]  -- non-apparatus docs, bm25 ranked; logs SQL
import sqlite3,sys
expr=sys.argv[1]; lim=int(sys.argv[2]) if len(sys.argv)>2 else 30
vol=sys.argv[3] if len(sys.argv)>3 else '%'
sql=("SELECT d.volume_id,d.document_id,substr(replace(d.header,char(10),' '),1,90),substr(replace(coalesce(d.dateline,''),char(10),' '),1,60),length(d.body_text),bm25(frus_documents) s "
"FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id LIKE ? ORDER BY s ASC LIMIT ?")
open('/Users/jbotts/frus-analysis/c3/runs/r5/queries.log','a').write("find.py: "+sql.replace('?',"%r")%(expr,vol,lim)+"\n")
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for r in c.execute(sql,(expr,vol,lim)):
    print("|".join(str(x) for x in r[:5]))
