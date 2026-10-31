# fetch.py: dump documents whole to docs/<vol>__<doc>.txt ; verify captured length = length(body_text)
import sys,os,re
sys.path.insert(0,'/Users/jbotts/frus-analysis/c3f/runs/f5')
from h import *
c=conn()
SQL="SELECT volume_id,document_id,header,dateline,source_note,body_text,length(body_text),is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?"
LOGF="/Users/jbotts/frus-analysis/c3f/runs/f5/fetched.tsv"
def fetch(pairs):
    for v,d in pairs:
        p=f"/Users/jbotts/frus-analysis/c3f/runs/f5/docs/{v}__{d}.txt"
        if os.path.exists(p): continue
        r=run(c,SQL,[v,d],"fetch whole doc") if False else c.execute(SQL,[v,d]).fetchall()
        if not r: print("MISSING",v,d); continue
        v,d,h,dl,sn,b,L,fm,en=r[0]
        txt=f"HEADER: {h}\nDATELINE: {dl}\nSOURCE_NOTE: {sn}\nBODY:\n{b}"
        open(p,"w").write(txt)
        got=len(b)
        open(LOGF,"a").write(f"{v}\t{d}\t{L}\t{got}\t{'OK' if got==L else 'SHORT'}\t{fm}\t{en}\n")
if __name__=="__main__":
    pairs=[tuple(x.split('/')) for x in sys.argv[1:]]
    fetch(pairs)
