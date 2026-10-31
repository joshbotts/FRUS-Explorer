import re,json,sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ov=open("overview.md").read()
c=json.load(open("collection.fruscollection"))
pairs=[(e["volumeId"],e["documentId"]) for e in c["entries"] if e["kind"]=="document"]
bodies={k:re.sub(r"\s+"," ",db.execute("select body_text from document_cache where volume_id=? and document_id=?",k).fetchone()[0]) for k in pairs}
quotes=re.findall(r"“([^”]+)”",ov); bad=0
for q in quotes:
    qq=re.sub(r"\s+"," ",q).strip()
    hit=[k for k,b in bodies.items() if qq in b]
    if not hit: bad+=1; print("QUOTE NOT FOUND:",qq[:100])
print("quotations",len(quotes),"not found",bad)
urls=set(re.findall(r"historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)",ov)); 
print("distinct documents cited by URL:",len(urls),"; not in collection:",[u for u in urls if u not in set(pairs)])
print("collection documents not cited in overview:",[p for p in pairs if p not in urls])
for bad_s in ["SELECT","volume_id","document_id","document_cache","/Users/","frus_documents",".db","#1"]:
    if bad_s in ov: print("FORBIDDEN STRING present:",bad_s)
# ids in the overview outside URLs
body=re.sub(r"https://history\.state\.gov\S+","",ov)
print("id-like strings outside URLs:",re.findall(r"frus\d\S*|\bd\d{2,4}\b",body)[:5])
