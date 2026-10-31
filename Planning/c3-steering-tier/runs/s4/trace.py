import re,json,sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
coll=json.load(open("collection.fruscollection"))
docs=[(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"]
norm=lambda t:re.sub(r"\s+"," ",t)
body={k:norm(con.execute("select body_text from document_cache where volume_id=? and document_id=?",k).fetchone()[0]) for k in docs}
s=open("overview.md").read()
qs=re.findall(r"\"([^\"]{3,})\"|“([^”]{3,})”",s); qs=[a or b for a,b in qs]
rows=[]; docsq=set()
for q in qs:
    qn=norm(q).rstrip(".,;:")
    hit=[k for k in docs if qn in body[k]]
    if hit:
        rows.append((q,hit[0])); docsq.add(hit[0])
print(len(rows),"verified double-quoted passages in the overview;",len(docsq),"distinct documents quoted")
json.dump(rows,open("work/overview_quotes.json","w"))
