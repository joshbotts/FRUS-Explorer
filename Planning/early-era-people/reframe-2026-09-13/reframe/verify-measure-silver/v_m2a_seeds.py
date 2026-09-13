#!/usr/bin/env python3
"""VERIFY at SPAN level: (a) seeded spans (m2a-manifest.json) vs gold spans: kept exactly / overlapped / removed;
(b) the marked layer (~/frus-ner-raw/marked via ner_store, the scorer's own reader) for the 64 keyed documents vs the
seeded spans: are the scorer's baseline predictions the SAME spans that were seeded? Read-only."""
import json, sys, collections, os
sys.path.insert(0,"/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import ner_store
M="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"
man={(e["volume"],e["document"]):e for e in json.load(open(M+"/m2a-manifest.json"))["documents"]}
keyed=[(json.loads(l)["v"],json.loads(l)["d"]) for l in open(M+"/m2a-ground-truth-documents.jsonl")]
gold=collections.defaultdict(set); gseed=collections.defaultdict(set); band={}
for l in open(M+"/m2a-ground-truth.jsonl"):
    r=json.loads(l); gold[(r["v"],r["d"])].add((r["s"],r["e"])); band[(r["v"],r["d"])]=r["band"]
    if r["seeded"]: gseed[(r["v"],r["d"])].add((r["s"],r["e"]))
cache={}
T=collections.defaultdict(collections.Counter)
for k in keyed:
    v,d=k; e=man[k]; b=e["band"]; seeds={tuple(x) for x in e["seeded"]}
    if v not in cache: cache[v]=ner_store.spans_by_document(ner_store.volume_layer("/Users/jbotts/frus-ner-raw","marked",v))
    marked={(s,t) for s,t,_ in cache[v].get(d,[])}
    c=T[b]; c["docs"]+=1; c["seeded"]+=len(seeds); c["marked_spans"]+=len(marked)
    c["marked_equals_seeded_doc"]+= (marked==seeds)
    c["marked_not_seeded"]+=len(marked-seeds); c["seeded_not_marked"]+=len(seeds-marked)
    for s,t in seeds:
        if (s,t) in gold[k]: c["kept_exact"]+=1
        elif any(a<t and s<bb for a,bb in gold[k]): c["overlapped"]+=1
        else: c["removed"]+=1
    c["gold_flag_seeded_true"]+=len(gseed[k]); c["gold_flag_seeded_but_not_in_manifest_seeds"]+=len(gseed[k]-seeds)
    # relaxed hits of marked spans against gold (overlap)
    c["marked_overlapping_gold"]+=sum(1 for s,t in marked if any(a<t and s<bb for a,bb in gold[k]))
tot=collections.Counter()
for c in T.values(): tot.update(c)
out={"by_band":{b:dict(c) for b,c in sorted(T.items())},"total":dict(tot)}
json.dump(out,open(os.path.dirname(os.path.abspath(__file__))+"/v-m2a-seeds.json","w"),indent=1); print(json.dumps(out,indent=1))
