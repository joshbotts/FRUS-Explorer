import sqlite3,sys,re,os
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
maxc=int(os.environ.get("MAXC","3500"))
show=os.environ.get("SHOW","1")=="1"
for a in sys.argv[1:]:
    v,d=a.split("/")
    r=db.execute("SELECT volume_id,document_id,header,dateline,source_note,body_text,length(body_text),is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print("NOT FOUND",a); continue
    txt=r[5]
    open("docs/%s__%s.txt"%(v,d),"w").write("HEADER: %s\nDATELINE: %s\nSOURCE: %s\nBODY:\n%s"%(r[2],r[3],r[4],txt))
    print("="*8,a,"| length(body_text)=%d captured=%d | fm=%d en=%d"%(r[6],len(txt),r[7],r[8]))
    print(re.sub(r"\s+"," ",r[2])[:220],"|",r[3])
    if show: print(re.sub(r"[ \t]+"," ",txt)[:maxc])
