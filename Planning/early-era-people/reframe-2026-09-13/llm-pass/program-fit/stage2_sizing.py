#!/usr/bin/env python3
"""Stage-2 pilot sizing (read-only): the 300 m1a eval rows — bands, pre-1910, full-doc R-0 chars, POCOM candidate block size."""
import json, os, sys, csv, collections
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, REPO+"/tools/semantic-harvest")
sys.path.insert(0, REPO+"/Planning/early-era-people/feasibility-2026-09-12/measure-pocom")
import ner_store as st
import measure_pocom as mp
TEXT=os.path.expanduser("~/frus-semantic-raw/text")
rows=list(csv.DictReader(open(REPO+"/Planning/early-era-people/m1a-eval-candidates.csv")))
surnames, spans, by_surname = mp.load_pocom()
texts={}
out={"rows":len(rows),"keyed":sum(1 for r in rows if r["TRUE_IDENTITY_pocom_slug_or_name"].strip())}
band=collections.Counter(); roles=collections.Counter(); pre=0
dchars=[]; cands=[]; appts=[]; live=collections.Counter(); missing_doc=0
for r in rows:
    v=r["volume"]; band[st.band_of(v)]+=1; roles[r["role"]]+=1
    if int(r["year"])<1910: pre+=1
    if v not in texts: texts[v]=st.volume_text(TEXT,v)
    t=texts[v].get(r["document"])
    if t is None: missing_doc+=1; continue
    dchars.append(len(t))
    sl=by_surname.get(r["surname"],set())
    cands.append(len(sl)); appts.append(sum(len(spans[s]) for s in sl))
    y=int(r["year"]); n=mp.live_count(sl,spans,y,y)
    live["none_known" if not sl else ("nobody_in_office" if n==0 else ("unique" if n==1 else "several"))]+=1
q=lambda xs,p: sorted(xs)[min(len(xs)-1,int(p*len(xs)))]
out.update({"by_band":band,"roles":roles,"pre1910_rows":pre,"volumes":len(texts),"missing_doc_text":missing_doc,
 "doc_chars":{"total":sum(dchars),"median":q(dchars,.5),"p90":q(dchars,.9),"max":max(dchars),
              "total_capped_8000":sum(min(c,8000) for c in dchars),"total_capped_20000":sum(min(c,20000) for c in dchars)},
 "pocom_candidates_per_row":{"total":sum(cands),"median":q(cands,.5),"max":max(cands),"zero":sum(1 for c in cands if c==0)},
 "pocom_appointments_per_row":{"total":sum(appts),"median":q(appts,.5),"p90":q(appts,.9),"max":max(appts)},
 "surname_year_rule_on_these_rows":live})
json.dump(out,open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"stage2_sizing.json"),"w"),indent=1)
print(json.dumps(out,indent=1))
