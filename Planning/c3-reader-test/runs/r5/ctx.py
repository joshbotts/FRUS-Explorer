# usage: ctx.py VOL DOC REGEX [width=350] [maxhits=6]   (regex case-INSENSITIVE, Python re; run on header+dateline+source_note+body whitespace-collapsed)
import sqlite3,sys,re,os
v,d,rx=sys.argv[1:4]; w=int(sys.argv[4]) if len(sys.argv)>4 else 350; mh=int(sys.argv[5]) if len(sys.argv)>5 else 6
sql="SELECT header,dateline,source_note,body_text,length(body_text),is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?"
open('/Users/jbotts/frus-analysis/c3/runs/r5/queries.log','a').write("ctx.py: %s [%r,%r] regex(IGNORECASE)=%r width=%d\n"%(sql,v,d,rx,w))
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
r=c.execute(sql,(v,d)).fetchone()
h,dl,sn,b,L,fm,en=r
open('/Users/jbotts/frus-analysis/c3/runs/r5/texts/%s__%s.txt'%(v,d),'w').write("HEADER: %s\nDATELINE: %s\nSOURCE: %s\nBODY_LEN_CHARS: %d\n----\n%s"%(h,dl,sn,L,b))
t=' '.join((' '.join([h or '',dl or '',sn or '',b])).split())
print("HDR:",' '.join((h or '').split())[:200]);print("DL:",dl,"| len",L,"| fm",fm,"en",en)
n=0;last=-10**9
for m in re.finditer(rx,t,re.I):
    if m.start()<last+w: continue
    last=m.start()+w
    print("--[%d]"%m.start(),t[max(0,m.start()-w):m.end()+w]);n+=1
    if n>=mh:break
print("hits shown",n,"of total matches",len(re.findall(rx,t,re.I)))
