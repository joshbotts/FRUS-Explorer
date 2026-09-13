#!/usr/bin/env python3
"""Task 4 precedent. M2a seeded each staged document with the editors' <persName> spans (stage_m2a.py). Its summary
reports 35 'editor_spans_rejected' = seeded (start,end) pairs not kept EXACTLY. This separates a rejected seed whose
text the annotator still wrapped with different boundaries (overlap with a kept span) from a seed removed outright
(no kept span overlaps it), per band. Read-only over the M2a folder."""
import json, collections
M="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"
man=json.load(open(M+"/m2a-manifest.json"))
entries=man["documents"] if isinstance(man,dict) and "documents" in man else man
if isinstance(entries,dict): entries=list(entries.values())
gold=collections.defaultdict(list)
for l in open(M+"/m2a-ground-truth.jsonl"):
    r=json.loads(l); gold[(r["v"],r["d"])].append((r["s"],r["e"],r["n"],r["seeded"]))
docs=set()
for l in open(M+"/m2a-ground-truth-documents.jsonl"):
    r=json.loads(l); docs.add((r["v"],r["d"]))
out=collections.defaultdict(collections.Counter); ex=[]
for e in entries:
    k=(e.get("volume"),e.get("document"))
    if k not in docs: continue
    seeded={(s,t) for s,t in e.get("seeded",[])}
    kept={(s,t) for s,t,_,_ in gold[k]}
    c=out[e["band"]]; c["seeded"]+=len(seeded)
    for s,t in seeded:
        if (s,t) in kept: c["kept_exact"]+=1; continue
        ov=[g for g in gold[k] if g[0]<t and s<g[1]]
        if ov: c["rejected_but_overlapped_by_kept_span"]+=1; ex.append([k,(s,t),[g[2] for g in ov]])
        else: c["removed_outright"]+=1; ex.append([k,(s,t),"REMOVED"])
tot=collections.Counter()
for c in out.values(): tot.update(c)
res={"by_band":{b:dict(c) for b,c in sorted(out.items())},"total":dict(tot),"examples":[[list(a),list(b),c] for a,b,c in ex[:60]]}
json.dump(res,open("m2a-seed-check.json","w"),indent=1,ensure_ascii=False)
print(json.dumps({"by_band":res["by_band"],"total":res["total"]},indent=1)); print(res["examples"][:40])
