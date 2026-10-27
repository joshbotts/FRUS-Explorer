# usage: show.py VOL DOC [maxchars=3000] -- prints header/dateline and first maxchars of body; saves raw to texts/
import sqlite3,sys
v,d=sys.argv[1:3]; m=int(sys.argv[3]) if len(sys.argv)>3 else 3000
sql="SELECT header,dateline,source_note,body_text,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?"
open('/Users/jbotts/frus-analysis/c3/runs/r5/queries.log','a').write("show.py: %s [%r,%r] first %d chars\n"%(sql,v,d,m))
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
h,dl,sn,b,L=c.execute(sql,(v,d)).fetchone()
open('/Users/jbotts/frus-analysis/c3/runs/r5/texts/%s__%s.txt'%(v,d),'w').write("HEADER: %s\nDATELINE: %s\nSOURCE: %s\nBODY_LEN_CHARS: %d\n----\n%s"%(h,dl,sn,L,b))
print("##",v,d,"|",' '.join((h or '').split())[:120],"|",dl,"| len",L)
print(' '.join(b.split())[:m])
