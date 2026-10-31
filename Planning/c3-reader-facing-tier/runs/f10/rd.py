import sqlite3,sys,os
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
for a in sys.argv[1:]:
    v,d=a.split("/")
    r=db.execute("select header,dateline,source_note,body_text,length(body_text) from document_cache where volume_id=? and document_id=? and is_front_matter=0 and is_editorial_note=0",(v,d)).fetchone()
    if not r: print(a,"NOT FOUND"); continue
    txt="HEADER: %s\nDATELINE: %s\nSOURCE: %s\n\n%s"%(r[0],r[1],r[2],r[3])
    open(R+"readings/%s__%s.txt"%(v,d),"w").write(txt)
    open(R+"queries.log","a").write("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id='%s' AND document_id='%s' AND is_front_matter=0 AND is_editorial_note=0;  -> readings/%s__%s.txt (body %d chars)\n"%(v,d,v,d,r[4]))
    print(a,r[4],"chars |",r[0][:100].replace("\n"," "))
