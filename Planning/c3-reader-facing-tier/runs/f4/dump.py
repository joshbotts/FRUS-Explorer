import sys,sqlite3,re,os
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB,uri=True)
SQL="SELECT volume_id, document_id, header, dateline, source_note, body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?"
for a in sys.argv[1:]:
    v,d=a.split('/')
    r=c.execute(SQL,(v,d)).fetchone()
    if not r: print('MISSING',a); continue
    txt=f"{r[2]}\n{r[3]}\n\n{r[5]}"
    open(f"docs/{v}__{d}.txt","w").write(f"HEADER: {r[2]}\nDATELINE: {r[3]}\nSOURCE: {r[4]}\n\nBODY:\n{r[5]}")
    print(a,'len_body_chars',r[6],'fm',r[7],'en',r[8],'|',re.sub(r'\s+',' ',r[2])[:100],'|',(r[3] or '')[:40])
