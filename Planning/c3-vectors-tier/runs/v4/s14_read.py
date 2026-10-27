# Reading SELECT: SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?
import sqlite3
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for l in open('reading_ids.txt'):
    v,d=l.split()
    r=c.execute("SELECT header, dateline, source_note, body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    open('texts/%s_%s.txt'%(v,d),'w').write("HEADER: %s\nDATELINE: %s\nSOURCE: %s\nBODY:\n%s"%(r[0],r[1],r[2],r[3]))
    print(v,d,"len(body_text)=",r[4],"captured=",len(r[3]),"fm/en",r[5],r[6])
