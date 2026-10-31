# Check: every "quoted" string in overview.md is inside a verified quotation (raw/quotes.json) or is a search term/title;
# every history.state.gov URL cited is in raw/set.txt; same checks for collection excerpts.
import re, json, sys
Q=json.load(open("raw/quotes.json")); qt=[x[3] for x in Q]
setp={tuple(l.strip().split("|")) for l in open("raw/set.txt") if l.strip()}
ov=open("overview.md").read()
quoted=re.findall(r'"([^"]{3,})"', ov)
bad=[s for s in quoted if not any(" ".join(s.split()) in " ".join(t.split()) for t in qt)]
print("quoted strings in overview:",len(quoted),"not inside a verified quotation:",bad)
urls=set(re.findall(r'historicaldocuments/([^/\s]+)/(d\d+)', ov)); print("URLs cited:",len(urls),"not in set:",[u for u in urls if u not in setp])
docrefs=re.findall(r'Document (\d+)', ov); print("'Document N' mentions:",len(docrefs))
try:
    c=json.load(open("collection.fruscollection"))
    ex=[e for e in c["entries"] if e["kind"]=="excerpt"]; docs=[(e["volumeId"],e["documentId"]) for e in c["entries"] if e["kind"]=="document"]
    print("collection docs",len(docs),"dupes",len(docs)-len(set(docs)),"missing from set",[d for d in docs if d not in setp],"set missing from collection",[d for d in setp if d not in set(docs)])
    print("excerpts",len(ex),"not verified:",[e["text"] for e in ex if e["text"] not in qt],"excerpt doc not a document entry:",[(e["volumeId"],e["documentId"]) for e in ex if (e["volumeId"],e["documentId"]) not in set(docs)])
    print("Ed2 present:",[d for d in docs if d[0].endswith("Ed2")])
    print("composition keys",sorted(c["composition"].keys()))
except FileNotFoundError: print("no collection yet")
