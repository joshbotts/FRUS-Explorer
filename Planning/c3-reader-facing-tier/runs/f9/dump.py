# SELECT volume_id, document_id, header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?
import sqlite3
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
log=open('docs/_lengths4.tsv','w')
for line in open('reading_list4.txt'):
    v,d=line.split()
    r=c.execute("SELECT header, dateline, source_note, body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print('MISSING',v,d); continue
    open(f'docs/{v}__{d}.txt','w').write(f"HEADER: {r[0]}\nDATELINE: {r[1]}\nSOURCE: {r[2]}\n---\n{r[3]}")
    log.write(f"{v}\t{d}\t{r[4]}\t{r[5]}\t{r[6]}\n")
