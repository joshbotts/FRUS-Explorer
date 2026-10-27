from vec import *
import sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
anchors=[("frus1874","d552"),("frus1898","d498"),("frus1934v05","d127"),("frus1944v07","d878"),("frus1958-60v06","d499"),("frus1969-76ve10","d205")]
out=open("vec_neighbours.txt","w")
for a in anchors:
    nn=knn(row_of[a],15)
    out.write(f"ANCHOR {a[0]}/{a[1]}\n"); print("ANCHOR",a)
    for d,r in nn:
        v,doc=doc_of[r]
        x=db.execute("select substr(c.header,1,60), dd.date_iso, instr(lower(c.body_text),'cuba')>0, c.is_front_matter, c.is_editorial_note from document_cache c left join document_dates dd on dd.volume_id=c.volume_id and dd.document_id=c.document_id where c.volume_id=? and c.document_id=?",(v,doc)).fetchone()
        line=f"  ham {d:3d} {v}/{doc} {x[1] if x else 'NOT IN DB'} cuba_in_text={x[2] if x else None} fm={x[3] if x else None} en={x[4] if x else None} | {x[0] if x else ''}"
        out.write(line+"\n"); print(line)
out.close()
