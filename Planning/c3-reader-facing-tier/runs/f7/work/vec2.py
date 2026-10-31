import sys;sys.path.insert(0,"work")
from vec_lib import *
import sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
anchors=sys.argv[1:]
for a in anchors:
    v,d=a.split("/");r=row_of[(v,d)]
    h=ham_all(r);h[r]=9999
    cand=np.argsort(h,kind="stable")[:800]
    qa=vec(r)
    sc=[]
    for c in cand:
        cc=vec(int(c));sc.append(float(np.dot(qa,cc)))
    sc=np.array(sc);order=np.argsort(-sc)[:12]
    print("ANCHOR",a,"map cluster:",None)
    for o in order:
        c=int(cand[o]);vv,dd=doc_of[c]
        row=db.execute("select substr(replace(header,char(10),' '),1,95),is_front_matter,is_editorial_note from document_cache where volume_id=? and document_id=?",(vv,dd)).fetchone()
        dt=db.execute("select substr(date_iso,1,10) from document_dates where volume_id=? and document_id=?",(vv,dd)).fetchone()
        print("  ham %3d cos_raw %.3f cal %.3f  %s/%s %s | %s"%(h[c],sc[o],(sc[o]-0.40)/0.60,vv,dd,dt[0] if dt else "?",row[0] if row else "ABSENT_FROM_DB"))
