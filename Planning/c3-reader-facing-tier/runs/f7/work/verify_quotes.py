import sys,sqlite3,json
sys.path.insert(0,"work")
from docs_spec import *
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ok=bad=0;meta={}
allpairs=[p for _,L in FINDINGS for p in L]
assert len(allpairs)==len(set(allpairs)),"duplicate pair"
for v,d in allpairs:
    r=db.execute("SELECT header,dateline,document_number,body_text,length(body_text),is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print("MISSING",v,d); bad+=1; continue
    assert r[5]==0 and r[6]==0,(v,d)
    body=" ".join(r[3].split())
    dt=db.execute("select date_iso from document_dates where volume_id=? and document_id=?",(v,d)).fetchone()
    meta[v+"/"+d]={"header":" ".join(r[0].split()),"dateline":r[1],"num":r[2],"len":r[4],"date":dt[0] if dt else None}
    for q in QUOTES.get((v,d),[]):
        if " ".join(q.split()) in body: ok+=1
        else: print("QUOTE NOT FOUND",v,d,q[:80]); bad+=1
for k in QUOTES:
    assert k in allpairs,k
print("pairs",len(allpairs),"quotes ok",ok,"bad",bad)
json.dump(meta,open("work/docmeta.json","w"),ensure_ascii=False,indent=1)
