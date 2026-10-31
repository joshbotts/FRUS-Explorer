import json,sqlite3,re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ex=json.load(open('excerpts.json')); ok=0; out=open('excerpt_verification.txt','w')
for v,d,t in ex:
    b,=con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    exact=t in b; coll=re.sub(r'\s+',' ',t) in re.sub(r'\s+',' ',b)
    line=f"{v}/{d} exact_in_body_text={exact} whitespace_collapsed={coll} :: {t[:70]}"
    print(line); out.write(line+"\n"); ok+=exact
print("exact",ok,"of",len(ex))
