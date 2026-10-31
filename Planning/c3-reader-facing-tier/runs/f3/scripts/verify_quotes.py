# verify_quotes.py: for each quote, SELECT instr(body_text, ?), length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?
import sqlite3,json
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ok=0
for qid,v,d,t in json.load(open('raw/quotes.json')):
    r=con.execute("SELECT instr(body_text, ?), length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(t,v,d)).fetchone()
    good=r is not None and r[0]>0 and r[2]==0 and r[3]==0; ok+=good
    print(qid,v+'/'+d,'FOUND at char %d of %d'%(r[0],r[1]) if good else 'NOT FOUND',r)
print(ok,'of',len(json.load(open('raw/quotes.json'))),'verified')
