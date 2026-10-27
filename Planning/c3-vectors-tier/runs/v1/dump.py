# dump.py VOL DOC : write header/dateline/source_note/body_text of one document to docs/VOL__DOC.txt
import sys
from h import *
c=con()
SQL="SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0"
for a in sys.argv[1:]:
    v,d=a.split("/")
    r=c.execute(SQL,(v,d)).fetchone()
    if not r: print("MISSING",a); continue
    open("docs/%s__%s.txt"%(v,d),"w").write("HEADER: %s\nDATELINE: %s\nSOURCE: %s\n\n%s"%r)
    print(a,len(r[3]))
