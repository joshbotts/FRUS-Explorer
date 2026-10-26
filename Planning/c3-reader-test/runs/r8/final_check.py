import re,json
ov=open("overview.md").read(); coll=json.load(open("collection.fruscollection")); ex=json.load(open("excerpts.json"))
norm=lambda s:" ".join(s.replace("“",'"').replace("”",'"').replace("’","'").split()).lower()
extexts=[norm(e["text"]) for e in ex.values()]
# quotations in the overview: text inside straight double quotes, longer than 40 chars
quotes=[q.strip(' ,.;') for q in re.findall(r'"([^"\n]{30,}?)"(?=[\s,\.;:\)\(])',ov)]
bad=[]
for q in quotes:
    qn=norm(q)
    parts=[p.strip() for p in qn.split("…") if p.strip()]  # an ellipsis joins two spans of one excerpt
    if not all(any(p in t for t in extexts) for p in parts): bad.append(q[:90])
print("quotations found:",len(quotes),"not matching a verified excerpt:",len(bad)); [print("  BAD:",b) for b in bad]
urls=set(re.findall(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/([a-z_]*d\d+)",ov))
docs={(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"}
missing=[u for u in urls if u not in docs]
print("documents cited by URL in overview:",len(urls),"not in collection:",missing)
excerpt_pairs={(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="excerpt"}
print("excerpt pairs lacking a document entry:",excerpt_pairs-docs)
print("forbidden strings in overview:", [s for s in ["frus19","document_cache","SELECT","volume_id",".tsv",".py","#1"] if s in ov])
