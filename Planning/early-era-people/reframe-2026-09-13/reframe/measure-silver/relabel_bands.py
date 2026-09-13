#!/usr/bin/env python3
"""Task 2 extension of chapter-context/label-validation (score.py) WITHOUT re-running it: re-tally its
scored-mentions.jsonl per band of the TEI document year (gold-mentions.jsonl tei_date), for
  S (surname x year, verbatim), COMB|STRIP|primary(0,60d) (chapter post + surname, real Swift classifier at the chapter title),
  and BOTH-SAME (S pick == COMB pick), in document heads, over (i) every gold route and (ii) route A only (the
  crosswalk slug, the route that does not derive its truth from POCOM surname matching).
Populations: the 1873 pair (pre-1900) and the 15 post-1905 'proxy' volumes where the STRIP chapter rule finds a country
(score.json chapter_bearing_volumes_STRIP), plus all 33 post-1905 list volumes for S."""
import json, collections, math
LV="/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/chapter-context/label-validation"
PRE={"frus1873p1v1","frus1873p1v2"}
sc=json.load(open(LV+"/score.json")); strip=set(sc["chapter_bearing_volumes_STRIP"])-PRE
year={}
for l in open(LV+"/gold-mentions.jsonl"):
    m=json.loads(l)
    if m["tei_date"]: year[(m["v"],m["d"])]=int(m["tei_date"][:4])
def band(y):
    if y is None: return "no-year"
    return "pre-1861" if y<1861 else "1861-1899" if y<1900 else "1900-1929" if y<1930 else "1930-1945" if y<1946 else "1946-"
def wilson(k,n,z=1.96):
    if not n: return None
    p=k/n; den=1+z*z/n; c=(p+z*z/(2*n))/den; h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den
    return [round(p,4),round(c-h,4),round(c+h,4)]
T=collections.defaultdict(collections.Counter); V=collections.defaultdict(set); P=collections.defaultdict(set)
for l in open(LV+"/scored-mentions.jsonl"):
    r=json.loads(l)
    if r["pos"]!="head": continue
    pop="1873" if r["v"] in PRE else ("proxy15" if r["v"] in strip else "post1905_other")
    bd=band(year.get((r["v"],r["d"])))
    o=r.get("STRIP|primary(0,60d)") or {}
    for route in ("all","A"):
        if route=="A" and r["gold_route"]!="A": continue
        for p2 in (pop, "post1905_all" if pop!="1873" else None):
            if not p2: continue
            k=(p2,route,bd); c=T[k]; c["linked_head_rows"]+=1; V[k].add(r["v"]); P[k].add(r["gold_slug"])
            c["S_class:"+r["S_class"]]+=1
            if r["S_j"]: c["S_picks"]+=1; c["S_"+r["S_j"]]+=1
            if o.get("COMB_j"): c["COMB_picks"]+=1; c["COMB_"+o["COMB_j"]]+=1
            if r["S"] and o.get("COMB") and r["S"]==o["COMB"]:
                c["BOTH_same_picks"]+=1; c["BOTH_"+(r["S_j"] or "none")]+=1
out={}
for k,c in sorted(T.items()):
    d=dict(c); d["volumes"]=len(V[k]); d["distinct_gold_persons"]=len(P[k]-{None})
    dec=lambda a,b: (d.get(a,0), d.get(a,0)+d.get(b,0))
    d["S_prec_excl_undecided"]=wilson(*dec("S_agree","S_disagree"))
    d["COMB_prec_excl_undecided"]=wilson(*dec("COMB_agree","COMB_disagree"))
    d["BOTH_prec_excl_undecided"]=wilson(*dec("BOTH_agree","BOTH_disagree"))
    out["|".join(k)]=d
json.dump(out,open("label-validation-by-band.json","w"),indent=1)
for k,d in out.items(): print(k, json.dumps(d))
