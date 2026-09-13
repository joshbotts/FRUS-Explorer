#!/usr/bin/env python3
"""My own POCOM loader (ElementTree, not regex) for the assessment's S rule definition: slug->surname from people/*/*.xml
<persName><surname>; slug->[(min year,max year)] over every 4-digit <date> inside each <chief>/<principal> of
missions-*/ and positions-principals/; by_surname keeps only slugs with a span. Parity-checked against
measure_pocom.load_pocom (imported ONLY for the parity comparison). Writes v-pocom.json."""
import glob, collections, json, os, sys, re
import xml.etree.ElementTree as ET
P="/Users/jbotts/Development/pocom"
def load():
    sur={}; fore={}
    for f in sorted(glob.glob(P+"/people/*/*.xml")):
        r=ET.parse(f).getroot(); i=r.findtext("id"); s=r.findtext("persName/surname")
        if i and s and s.strip(): sur[i.strip()]=s.strip()
        fn=r.findtext("persName/forename")
        if i and fn: fore[i.strip()]=fn.strip()
    spans=collections.defaultdict(list)
    for f in sorted(glob.glob(P+"/missions-*/*.xml"))+sorted(glob.glob(P+"/positions-principals/*.xml")):
        r=ET.parse(f).getroot()
        for blk in list(r.iter("chief"))+list(r.iter("principal")):
            pid=blk.findtext("person-id")
            if not pid: continue
            ys=[int(e.text[:4]) for e in blk.iter("date") if e.text and e.text[:4].isdigit()]
            if ys: spans[pid.strip()].append((min(ys),max(ys)))
    by=collections.defaultdict(set)
    for s,n in sur.items():
        if s in spans: by[n].add(s)
    return sur,spans,by,fore
if __name__=="__main__":
    sur,spans,by,fore=load()
    sys.path.insert(0,"/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-pocom")
    import measure_pocom as M
    s2,sp2,by2=M.load_pocom()
    par={"surnames_mine":len(sur),"surnames_theirs":len(s2),"surname_diff":len(set(sur.items())^set(s2.items())),
         "span_slugs_mine":len(spans),"span_slugs_theirs":len(sp2),
         "span_multiset_diff_slugs":sum(1 for k in set(spans)|set(sp2) if sorted(spans.get(k,[]))!=sorted(sp2.get(k,[]))),
         "by_surname_diff":sum(1 for k in set(by)|set(by2) if by.get(k,set())!=by2.get(k,set()))}
    ex=[k for k in set(spans)|set(sp2) if sorted(spans.get(k,[]))!=sorted(sp2.get(k,[]))][:5]
    par["span_diff_examples"]={k:[sorted(spans.get(k,[])),sorted(sp2.get(k,[]))] for k in ex}
    json.dump({"parity":par},open(os.path.dirname(os.path.abspath(__file__))+"/v-pocom.json","w"),indent=1); print(json.dumps(par,indent=1))
