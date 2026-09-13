#!/usr/bin/env python3
"""How stale are pre-#1292 Source Explorer strata for 1861-1899? Compare before-docs.jsonl vs after-docs.jsonl per document
(appYear 1861-1899): share with any suggestion, and share whose set of (category, geoKeys) changed. Read-only."""
import json, os, collections
S="/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/geo-fix"
def load(p):
    d={}
    for l in open(p):
        r=json.loads(l); d[(r["volume"],r["d"])]=(r.get("appYear"),frozenset((s["category"],tuple(sorted(s.get("geoKeys") or []))) for s in (r.get("shown") or [])))
    return d
b=load(S+"/before-docs.jsonl"); a=load(S+"/after-docs.jsonl")
c=collections.Counter()
for k,(y,sb) in b.items():
    if y is None or not (1861<=y<=1899): continue
    sa=a.get(k,(None,frozenset()))[1]
    c["docs"]+=1; c["before_any"]+=bool(sb); c["after_any"]+=bool(sa); c["changed"]+= sb!=sa
    c["geo_changed_among_both_any"]+= bool(sb) and bool(sa) and {g for _,g in sb}!={g for _,g in sa}
out={k:v for k,v in c.items()}; out["shares"]={k:round(v/c["docs"],4) for k,v in c.items() if k!="docs"}; out["docs_total_before"]=len(b); out["docs_total_after"]=len(a)
json.dump(out,open(os.path.dirname(os.path.abspath(__file__))+"/v-geofix-drift.json","w"),indent=1); print(json.dumps(out,indent=1))
