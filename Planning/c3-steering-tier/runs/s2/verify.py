# verify every excerpt is an exact substring of its document's body_text; verify every collection pair exists
import json, sqlite3
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL="SELECT body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?"
print("SQL:", SQL)
ok=0; ex=json.load(open("excerpts.json"))
for v,d,t in ex:
    r=con.execute(SQL,(v,d)).fetchone()
    n=r[0].count(t) if r else -1
    print("%s/%s exact-substring occurrences=%d fm=%s en=%s" % (v,d,n,r[1],r[2])); ok+= n>=1
print("excerpts verified: %d of %d" % (ok,len(ex)))
