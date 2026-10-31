import sqlite3,sys,os
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
log=open("work/dump_log.tsv","a")
for a in sys.argv[1:]:
    v,d=a.split("/")
    r=db.execute("SELECT header,dateline,source_note,body_text,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone()
    if not r: print("MISSING",a); continue
    h,dl,sn,b,n=r
    fn="docs/%s__%s.txt"%(v,d)
    open(fn,"w",encoding="utf-8").write(b)
    open("docs/%s__%s.meta.txt"%(v,d),"w",encoding="utf-8").write("HEADER: %s\nDATELINE: %s\nSOURCE: %s\n"%(h,dl,sn))
    got=len(open(fn,encoding="utf-8").read())
    log.write("%s\t%d\t%d\t%s\n"%(a,n,got,"OK" if n==got else "MISMATCH"))
    print(a,n,got,"OK" if n==got else "MISMATCH")
