# usage: sec.py VOL SECTION_ID [regex=recogni]  -- list docs in a section (from struct.db) with date, length, count of regex matches (case-insens, Python)
import sqlite3,sys,re
v,s=sys.argv[1:3]; rx=sys.argv[3] if len(sys.argv)>3 else 'recogni'
open('/Users/jbotts/frus-analysis/c3/runs/r5/queries.log','a').write("sec.py: struct.db sd(volume_id=%r,section_id=%r) JOIN document_cache; count regex(IGNORECASE) %r over header+dateline+source_note+body\n"%(v,s,rx))
st=sqlite3.connect('/Users/jbotts/frus-analysis/c3/runs/r5/struct.db')
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for (d,) in st.execute("select document_id from sd where volume_id=? and section_id=?",(v,s)):
    h,dl,sn,b,fm,en=c.execute("select header,dateline,source_note,body_text,is_front_matter,is_editorial_note from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    t=' '.join(' '.join([h or '',dl or '',sn or '',b]).split())
    print(d,'|',' '.join((h or '').split())[:75],'|',' '.join((dl or '').split())[:50],'|',len(b),'| n=',len(re.findall(rx,t,re.I)),'| fm%d en%d'%(fm,en))
