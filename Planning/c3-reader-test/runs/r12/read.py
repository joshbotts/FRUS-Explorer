# usage: read.py vol/doc [vol/doc ...]  [--max N]   Reads whole body_text read-only, saves to raw/, prints up to N chars.
import sqlite3, sys, os
args=sys.argv[1:]; mx=7000
if '--max' in args:
    i=args.index('--max'); mx=int(args[i+1]); del args[i:i+2]
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
led=open("reading_ledger.csv","a")
for a in args:
    v,d=a.split('/')
    r=db.execute("SELECT header,dateline,source_note,body_text,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print("MISSING",a); continue
    h,dl,sn,b,L=r
    txt="HEADER: %s\nDATELINE: %s\nSOURCE: %s\n\n%s"%(h,dl,sn,b)
    open("raw/%s__%s.txt"%(v,d),"w").write(txt)
    led.write("%s,%s,%d,%d\n"%(v,d,L,len(b)))
    print("=====",a,"len",L,"(shown %d)"%min(len(txt),mx)); print(txt[:mx]); 
led.close()
