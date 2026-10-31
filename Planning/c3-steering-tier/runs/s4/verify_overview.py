import re,json,sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
coll=json.load(open("collection.fruscollection"))
docs=[(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"]
norm=lambda t:re.sub(r"\s+"," ",t)
body={k:norm(con.execute("select body_text from document_cache where volume_id=? and document_id=?",k).fetchone()[0]) for k in docs}
allbody=" ".join(body.values())
s=open("overview.md").read()
# 1. quotations: text in straight or curly double quotes
quotes=re.findall(r"\"([^\"]{3,})\"|“([^”]{3,})”",s)
quotes=[a or b for a,b in quotes]
nondoc=[]; ok=0; bad=[]
for q in quotes:
    qn=norm(q).rstrip(".,;:")
    if qn in allbody: ok+=1; continue
    bad.append(q)
print("double-quoted strings:",len(quotes),"found verbatim in a collection document:",ok)
for b in bad: print("  NOT IN A DOCUMENT:",b[:150])
# 2. URLs cited vs collection
urls=set(re.findall(r"historicaldocuments/([^/\s)]+)/(d\d+)",s))
print("distinct documents cited by URL:",len(urls),"missing from collection:",[u for u in urls if u not in set(docs)])
print("collection documents not cited by URL in overview:",[d for d in docs if d not in urls])
# 3. excerpts
ex=[e for e in coll["entries"] if e["kind"]=="excerpt"]
print("excerpts:",len(ex),"all verbatim in own doc:",all(norm(e["text"]) in body[(e["volumeId"],e["documentId"])] for e in ex))
