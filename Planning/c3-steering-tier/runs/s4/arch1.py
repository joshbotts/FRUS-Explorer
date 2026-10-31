import json,sqlite3,re
S=json.load(open("work/set.json"))
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
print(con.execute("select sql from sqlite_master where name='external_citations'").fetchone()[0])
for f,v,d in S:
    r=con.execute("select repository,record_group,lot_file,series_name,citation_era,substr(raw_text,1,110) from document_sources where volume_id=? and document_id=?",(v,d)).fetchone()
    n=con.execute("select count(*) from external_citations where volume_id=? and document_id=?",(v,d)).fetchone()[0]
    print(f,v,d,"| src:",r,"| ext_cites:",n)
