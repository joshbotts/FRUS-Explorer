#!/usr/bin/env python3
"""VERIFY the pooled 98.6% (475/482) and its per-band split by an independent re-tally of label-validation's
scored-mentions.jsonl (heads; proxy = score.json chapter_bearing_volumes_STRIP minus the 1873 pair; BOTH-same = S pick
equals STRIP|primary(0,60d) COMB pick; agree = S_j). Band from gold-mentions tei_date. Read-only; the Swift harness is
NOT re-run (not possible here), so this checks the tally, not the classifier."""
import json, collections, os
LV="/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/chapter-context/label-validation"
sc=json.load(open(LV+"/score.json")); proxy=set(sc["chapter_bearing_volumes_STRIP"])-{"frus1873p1v1","frus1873p1v2"}
yr={}
for l in open(LV+"/gold-mentions.jsonl"):
    m=json.loads(l)
    if m.get("tei_date"): yr[(m["v"],m["d"])]=int(m["tei_date"][:4])
T=collections.defaultdict(collections.Counter); routes=collections.Counter()
for l in open(LV+"/scored-mentions.jsonl"):
    r=json.loads(l)
    if r["pos"]!="head" or r["v"] not in proxy: continue
    y=yr.get((r["v"],r["d"])); bd="none" if y is None else "1900-1929" if y<1930 else "1930-1945" if y<1946 else "1946-"
    o=r.get("STRIP|primary(0,60d)") or {}
    if r["S"] and o.get("COMB") and r["S"]==o["COMB"]:
        c=T[bd]; c["both_same"]+=1; c["agree"]+= r["S_j"]=="agree"; c["disagree"]+= r["S_j"]=="disagree"; c["S_class_"+r["S_class"]]+=1
        routes[(bd,r["gold_route"])]+=1
    if r["S_j"]: T[bd+"|S"]["picks"]+=1; T[bd+"|S"][r["S_j"]]+=1
tot=collections.Counter()
for k,c in T.items():
    if "|" not in k: tot.update(c)
S_tot=collections.Counter()
for k,c in T.items():
    if k.endswith("|S"): S_tot.update(c)
out={"proxy_volumes":len(proxy),"by_band":{k:dict(c) for k,c in sorted(T.items())},"both_same_total":dict(tot),"S_total":dict(S_tot),
     "both_same_by_band_route":{f"{a}|{b}":n for (a,b),n in sorted(routes.items(),key=str)}}
json.dump(out,open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"v-retally-lv.json"),"w"),indent=1); print(json.dumps(out,indent=1))
