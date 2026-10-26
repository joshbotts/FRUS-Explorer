# Dump whole documents (header, dateline, source_note, body_text) to raw/<vol>__<doc>.txt; print captured length vs length(body_text)
import sys
from db import q
pairs=[a.split("/") for a in sys.argv[1:]]
for v,d in pairs:
    r=q("SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d),tag="read")
    if not r: print("MISSING",v,d); continue
    h,dl,sn,b,L=r[0]
    open("raw/%s__%s.txt"%(v,d),"w").write("HEADER: %s\nDATELINE: %s\nSOURCE: %s\n---\n%s"%(h,dl,sn,b))
    print("%s/%s len=%d captured=%d"%(v,d,L,len(b)))
