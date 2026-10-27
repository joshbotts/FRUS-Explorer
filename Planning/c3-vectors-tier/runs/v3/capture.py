import sqlite3, os
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
os.makedirs("docs",exist_ok=True); os.makedirs("raw",exist_ok=True)
n=0; okc=0; rows=[]
for l in open("docs_list.tsv"):
    v,d=l.split()
    h,dl,sn,b=db.execute("select header,dateline,source_note,body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    open(f"raw/{v}__{d}.body.txt","w",encoding="utf-8").write(b)
    cap=len(open(f"raw/{v}__{d}.body.txt",encoding="utf-8").read())
    n+=1; okc+= (cap==len(b)); rows.append((v,d,len(b),cap))
print("retrieved whole to disk (captured length = length(body_text)):",okc,"of",n)
open("capture_report.tsv","w").write("\n".join("\t".join(map(str,r)) for r in rows))
