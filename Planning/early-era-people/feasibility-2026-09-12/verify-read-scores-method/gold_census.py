import json, collections
M="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/"
docs=[json.loads(l) for l in open(M+"m2a-ground-truth-documents.jsonl") if l.strip()]
spans=[json.loads(l) for l in open(M+"m2a-ground-truth.jsonl") if l.strip()]
print("doc rows", len(docs), "span rows", len(spans))
print("doc keys", sorted(docs[0].keys()), "span keys", sorted(spans[0].keys()))
seg1={"frus1864p2","frus1865p1","frus1866p3","frus1872p2v5"}
bd=collections.Counter(); bm=collections.Counter(); sd=collections.Counter(); sm=collections.Counter()
marks=collections.Counter(); zero=0
for r in docs:
    bd[r["band"]]+=1; bm[r["band"]]+=r["mentions"]
    if r["v"] in seg1: sd[r["band"]]+=1; sm[r["band"]]+=r["mentions"]
    marks[str(r.get("mark"))]+=1
    if r["mentions"]==0: zero+=1; print("zero-mention doc", r)
print("docs by band", dict(bd)); print("mentions by band", dict(bm))
print("seg1 docs by band", dict(sd), "total", sum(sd.values())); print("seg1 mentions by band", dict(sm), "total", sum(sm.values()))
print("mark values", dict(marks), "zero-mention docs", zero)
print("span-file mention count by band", dict(collections.Counter(s["band"] for s in spans)))
vols=collections.Counter(r["v"] for r in docs); print("volumes", len(vols), sorted(vols.items()))
# editor-seeded? any field
print("sample doc row", docs[0]); print("sample span row", spans[0])
