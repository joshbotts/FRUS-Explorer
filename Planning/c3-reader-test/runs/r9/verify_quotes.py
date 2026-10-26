# verify_quotes.py: for each (pair, id, quote) in quotes.json, SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?
# and report whether the quote is an exact substring of the raw body_text ('raw'), or only of the whitespace-collapsed body
# ('collapsed', with the raw substring recovered by a \s+ regex), or missing. Writes quotes_verified.tsv and excerpts.json.
import sqlite3,json,re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
Q=json.load(open('/Users/jbotts/frus-analysis/c3/runs/r9/quotes.json')); out=[]; exc={}
for pair,qid,q in Q:
    v,d=pair.split('/')
    body=con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    if q in body: st='raw'; raw=q
    else:
        rx=re.compile(r'\s+'.join(re.escape(w) for w in q.split()))
        m=rx.search(body)
        if m: st='collapsed'; raw=m.group(0)
        else:
            st='MISSING'; raw=None
    out.append((pair,qid,st,len(q))); exc[qid]={'pair':pair,'status':st,'raw':raw,'quote':q}
    print(pair,qid,st,len(q))
open('/Users/jbotts/frus-analysis/c3/runs/r9/quotes_verified.tsv','w').write('\n'.join('\t'.join(map(str,r)) for r in out)+'\n')
json.dump(exc,open('/Users/jbotts/frus-analysis/c3/runs/r9/excerpts.json','w'),ensure_ascii=False,indent=1)
print('verified',sum(1 for r in out if r[2]!='MISSING'),'of',len(out))
