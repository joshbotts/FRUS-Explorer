import sys
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3s/runs/s7")
from db import *
for pair in sys.argv[1:]:
    v,d=pair.split("/")
    r=q("SELECT header,dateline,source_note,body_text,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d),"read")
    h,dl,sn,b,L=r[0]
    open("raw/%s__%s.txt"%(v,d),"w").write("HEADER: %s\nDATELINE: %s\nSOURCE: %s\nBODY:\n%s"%(h,dl,sn,b))
    print(pair,"len(body_text)=",L)
