# dump.py ids...: SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?
import sqlite3,sys
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for p in sys.argv[1:]:
    v,d=p.split('/')
    r=con.execute("SELECT header, coalesce(dateline,''), coalesce(source_note,''), body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print(p,'MISSING'); continue
    open('/Users/jbotts/frus-analysis/c3f/runs/f3/raw/docs/%s__%s.txt'%(v,d),'w').write('HEADER: %s\nDATELINE: %s\nSOURCE: %s\nBODY:\n%s\n'%r[:4])
    print(p, 'len',r[4],'fm',r[5],'ed',r[6])
