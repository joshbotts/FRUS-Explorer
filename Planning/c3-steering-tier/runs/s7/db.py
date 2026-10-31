import sqlite3
LOG="/Users/jbotts/frus-analysis/c3s/runs/s7/queries.log"
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
def q(sql,args=(),tag="py"):
    with open(LOG,"a") as f: f.write("python3 [%s] SQL: %s  ARGS=%r\n"%(tag," ".join(sql.split()),args))
    return con.execute(sql,args).fetchall()
NONAPP="c.is_front_matter=0 AND c.is_editorial_note=0"
def hits(match,tag="hits"):
    return q("SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND "+NONAPP+" ORDER BY c.volume_id,c.document_id",(match,),tag)
def text(v,d,tag="text"):
    r=q("SELECT coalesce(header,'')||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||coalesce(body_text,'') FROM document_cache WHERE volume_id=? AND document_id=?",(v,d),tag)
    return " ".join(r[0][0].split())
