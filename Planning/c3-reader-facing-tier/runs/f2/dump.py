import sqlite3,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
sql="SELECT d.header, d.dateline, d.source_note, d.body_text, length(d.body_text), t.date_iso FROM document_cache d LEFT JOIN document_dates t ON t.volume_id=d.volume_id AND t.document_id=d.document_id WHERE d.volume_id=? AND d.document_id=?"
log=open("/Users/jbotts/frus-analysis/c3f/runs/f2/queries.log","a")
for line in open(sys.argv[1]):
    v,d=line.split()
    log.write('sqlite3 -readonly DB "%s" [%s,%s]\n'%(sql,v,d))
    h,dl,sn,b,L,dt=c.execute(sql,(v,d)).fetchone()
    with open("raw/%s_%s.txt"%(v,d),"w") as f:
        f.write("HEADER: %s\nDATELINE: %s\nDATE: %s\nSOURCE: %s\nLEN: %d\n\n%s"%(" ".join(h.split()),dl,dt,sn,L,b))
    print(v,d,L,dt,(sn or "")[:120].replace("\n"," "))
