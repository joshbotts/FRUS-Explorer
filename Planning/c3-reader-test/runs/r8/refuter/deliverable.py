import json, re, collections
R8="/Users/jbotts/frus-analysis/c3/runs/r8/"
coll=json.load(open(R8+"collection.fruscollection"))
ents=coll["entries"]
kinds=collections.Counter(e["kind"] for e in ents)
print("entries:",len(ents),"by kind:",dict(kinds))
docs=[e for e in ents if e["kind"]=="document"]
print("documents with notes:",sum(1 for e in docs if e.get("notes")),"| notes total:",sum(len(e.get("notes",[])) for e in docs))
print("documents without notes:",[(e["volumeId"],e["documentId"]) for e in docs if not e.get("notes")])
docpairs={(e["volumeId"],e["documentId"]) for e in docs}
print("distinct document pairs:",len(docpairs))
print("generated blocks:",[e for e in ents if e["kind"]=="generated"])
print("headings:",[e["text"] for e in ents if e["kind"]=="heading"])
ov=open(R8+"overview.md").read()
urls=set(re.findall(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/([a-z_]*d\d+)",ov))
print("\nURL-cited pairs in overview:",len(urls))
# printed citations in the bottom line and elsewhere: "(Foreign Relations of the United States, 1913, Documents 7 and 1028; 1917, Document 379; ...)"
bl=ov[:ov.index("## Decisions this needs from you")]
printed=re.findall(r"\(((?:Foreign Relations of the United States, )?\d{4}(?:–\d{4})?, (?:Volume [IVXL]+, )?(?:Microfiche Supplement, )?Documents? [^()]*)\)",bl)
print("printed citation groups in the bottom line:",len(printed))
for p in printed: print("   ",p)
