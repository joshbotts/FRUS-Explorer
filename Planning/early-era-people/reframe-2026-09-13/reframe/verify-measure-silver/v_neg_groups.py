#!/usr/bin/env python3
"""VERIFY negative-silver validity: group every S false pick on a negative head (crosswalk id, no slug) by
(authority person, picked POCOM slug), with birth years and POCOM forename, per doc-year band. A row whose authority
forename's first token equals the POCOM forename's first token AND birth years agree would be a likely registry miss
(same person, not a negative); otherwise a real wrong pick. Read-only."""
import json, os, re, sys, glob, collections
import xml.etree.ElementTree as ET
D=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,D)
import v_pocom
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
PAI=json.load(open(REPO+"/FRUSExplorer/Resources/person-authority-index.json")); CW=PAI["crosswalk"]; AUTH=PAI["authority"]
IDS={v:set(x["persName_xml_ids"]) for v,x in json.load(open(D+"/v-scan.json"))["volumes"].items()}
sur,spans,by,fore=v_pocom.load()
birth={}
for f in glob.glob("/Users/jbotts/Development/pocom/people/*/*.xml"):
    r=ET.parse(f).getroot(); b=r.findtext("birth")
    if b and b.strip()[:4].isdigit(): birth[r.findtext("id").strip()]=int(b.strip()[:4])
TITLES={"Mr.","Mrs.","Sir","Lord","Count","Baron","Prince","King","Queen","Excellency","Dr.","Hon."}
def surname_of(name):
    toks=[t.strip(".,;:()") for t in name.split()]; toks=[t for t in toks if t and t not in TITLES and t[0].isupper() and len(t)>=3]
    return toks[-1] if toks else None
def pick_of(name,y):
    s=surname_of(name)
    if not s or s not in by: return None
    live=[x for x in by[s] if any(a-1<=y<=b+1 for a,b in spans[x])]
    return live[0] if len(live)==1 else None
def band(y): return "1900-1929" if y<1930 else "1930-1945" if y<1946 else "1946-"
def first(s): 
    t=[x for x in re.split(r"[\s.,]+",s or "") if x]; return t[0].lower() if t else ""
G=collections.defaultdict(collections.Counter); cls=collections.defaultdict(collections.Counter)
for l in open(D+"/v-fromto.jsonl"):
    r=json.loads(l); y=r["y"]
    if not r["head"] or y is None or y<1900 or not r["link"]: continue
    f=r["link"].split()[0]
    if "#" in f: pre,tid=f.split("#",1); tv=(pre[:-4] if pre.endswith(".xml") else pre) or r["v"]
    else: tv,tid=r["v"],f
    if tid not in IDS.get(tv,()): continue
    cid=CW.get(tv,{}).get(tid)
    if not cid: continue
    a=AUTH.get(str(cid),{})
    if a.get("s"): continue
    p=pick_of(r["n"],y)
    if not p: continue
    an=a.get("n",""); af=an.split(",",1)[1] if "," in an else ""
    same_first=first(af)!="" and first(af)==first(fore.get(p,""))
    same_birth=a.get("b") is not None and a.get("b")==birth.get(p)
    k=("likely_registry_miss" if same_first and (same_birth or a.get("b") is None or birth.get(p) is None) else
       "birth_equal_forename_differs" if same_birth else "different_or_unknown")
    cls[band(y)][k]+=1
    G[band(y)][(an,a.get("b"),p,fore.get(p),birth.get(p),k)]+=1
out={"classes":{b:dict(c) for b,c in cls.items()},
     "top_groups":{b:[[*k,n] for k,n in c.most_common(12)] for b,c in G.items()},
     "likely_registry_miss_groups":{b:[[*k,n] for k,n in c.most_common() if k[5]=="likely_registry_miss"][:15] for b,c in G.items()}}
json.dump(out,open(D+"/v-neg-groups.json","w"),indent=1,ensure_ascii=False); print(json.dumps(out,indent=1,ensure_ascii=False)[:7000])
