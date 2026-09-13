#!/usr/bin/env python3
"""VERIFY (a) join provenance of silver heads: 'registry' when ONE HistoryAtState/people record (ElementTree over every
element's text) carries both the FRUS anchor historicaldocuments/<tv>/persons#<tid> and departmenthistory/people/<slug>;
'overlay' otherwise. (b) Linked heads with NO crosswalk id, and their S picks (unscoreable, outside every silver
denominator). (c) crosswalk ids absent from the authority table. Per doc-year band. Read-only."""
import json, os, re, sys, collections
import xml.etree.ElementTree as ET
D=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,D)
import v_pocom
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
PAI=json.load(open(REPO+"/FRUSExplorer/Resources/person-authority-index.json")); CW=PAI["crosswalk"]; AUTH=PAI["authority"]
IDS={v:set(x["persName_xml_ids"]) for v,x in json.load(open(D+"/v-scan.json"))["volumes"].items()}
FR=re.compile(r"historicaldocuments/([^/\s]+)/persons#(\S+)"); PC=re.compile(r"departmenthistory/people/([^\s/#]+)")
pair=set(); nrec=0; both=0; withslug=0
for root,_,files in os.walk("/Users/jbotts/Development/people/data"):
    for f in files:
        if not f.endswith(".xml"): continue
        nrec+=1; anc=set(); sl=set()
        for el in ET.parse(os.path.join(root,f)).getroot().iter():
            t=el.text or ""
            anc.update(FR.findall(t)); sl.update(PC.findall(t))
        withslug+=bool(sl); both+=bool(sl and anc)
        for a in anc:
            for s in sl: pair.add((a[0],a[1],s))
sur,spans,by,fore=v_pocom.load()
TITLES={"Mr.","Mrs.","Sir","Lord","Count","Baron","Prince","King","Queen","Excellency","Dr.","Hon."}
def surname_of(name):
    toks=[t.strip(".,;:()") for t in name.split()]; toks=[t for t in toks if t and t not in TITLES and t[0].isupper() and len(t)>=3]
    return toks[-1] if toks else None
def pick(name,y):
    s=surname_of(name)
    if not s or s not in by: return None
    live=[x for x in by[s] if any(a-1<=y<=b+1 for a,b in spans[x])]
    return live[0] if len(live)==1 else None
def band(y): return "no-year" if y is None else "pre-1861" if y<1861 else "1861-1899" if y<1900 else "1900-1929" if y<1930 else "1930-1945" if y<1946 else "1946-"
T=collections.defaultdict(collections.Counter)
for l in open(D+"/v-fromto.jsonl"):
    r=json.loads(l)
    if not r["head"] or not r["link"]: continue
    f=r["link"].split()[0]
    if "#" in f: pre,tid=f.split("#",1); tv=(pre[:-4] if pre.endswith(".xml") else pre) or r["v"]
    else: tv,tid=r["v"],f
    if tid not in IDS.get(tv,()): continue
    bd=band(r["y"]); cid=CW.get(tv,{}).get(tid)
    if not cid:
        T[bd]["linked_head_no_crosswalk"]+=1
        if r["y"] is not None and pick(r["n"],r["y"]): T[bd]["no_crosswalk_S_picks_unscoreable"]+=1
        continue
    if str(cid) not in AUTH: T[bd]["crosswalk_id_missing_from_authority"]+=1; continue
    s=AUTH[str(cid)].get("s")
    if not s: continue
    T[bd]["silver_heads"]+=1; T[bd]["registry" if (tv,tid,s) in pair else "overlay"]+=1
out={"people_records":nrec,"records_with_slug":withslug,"records_with_anchor_and_slug":both,"by_band":{b:dict(c) for b,c in sorted(T.items())}}
json.dump(out,open(D+"/v-registry-uncw.json","w"),indent=1); print(json.dumps(out,indent=1))
