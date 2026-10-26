# ledger.py: for every document of the argument set: SELECT length(body_text) ; make sure the raw body is on disk (texts/VOL__DOC.txt) and that the captured length equals length(body_text) in characters.
import sqlite3,os,sys
sys.path.insert(0,'/Users/jbotts/frus-analysis/c3/runs/r5')
from final_docs import ALL
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ok=0;out=open('/Users/jbotts/frus-analysis/c3/runs/r5/reading_ledger.tsv','w')
out.write("volume_id\tdocument_id\tlength_body_text_chars\tcaptured_chars\tcaptured_equals_length\n")
for v,d in ALL:
    h,dl,sn,b,L=c.execute("SELECT header,dateline,source_note,body_text,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    fn=f'/Users/jbotts/frus-analysis/c3/runs/r5/texts/{v}__{d}.txt'
    if not os.path.exists(fn):
        open(fn,'w').write("HEADER: %s\nDATELINE: %s\nSOURCE: %s\nBODY_LEN_CHARS: %d\n----\n%s"%(h,dl,sn,L,b))
    t=open(fn).read(); body=t.split('\n----\n',1)[1]
    eq=(len(body)==L)
    ok+=eq
    out.write(f"{v}\t{d}\t{L}\t{len(body)}\t{eq}\n")
print('captured whole (len == length(body_text)):',ok,'of',len(ALL))
