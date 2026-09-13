#!/usr/bin/env python3
"""VERIFY extras. (i) Silver head rows 1900-1929 split at doc year 1910 (does silver hold ANY 1900-1909 document?), and the
untagged 1900-1909 S-class mix. (ii) Negative silver: for each S false pick, does the authority entry's birth year
(person-authority-index 'b') equal the picked POCOM officeholder's <birth>? A match suggests a registry miss (the row is
not a true negative). (iii) M1a CSV: year distribution and S class of the pre-1910 rows under my S rule. Read-only."""
import json, os, re, sys, csv, glob, collections
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
    toks=[t.strip(".,;:()") for t in name.split()]
    toks=[t for t in toks if t and t not in TITLES and t[0].isupper() and len(t)>=3]
    return toks[-1] if toks else None
def s_rule(name,y):
    s=surname_of(name)
    if not s or s not in by: return "unknown",None
    live=sorted(x for x in by[s] if any(a-1<=y<=b+1 for a,b in spans[x]))
    return ("nobody" if not live else "one" if len(live)==1 else "several"),(live[0] if len(live)==1 else None)
def band(y): return "1900-1929" if y<1930 else "1930-1945" if y<1946 else "1946-"
out={"silver_1900_1929_by_decade":collections.Counter(),"silver_1900_1929_vols_pre1910":collections.Counter(),
     "untagged_1900_1909_S":collections.Counter(),"neg_birth":collections.defaultdict(collections.Counter),"neg_birth_examples":collections.defaultdict(list)}
for l in open(D+"/v-fromto.jsonl"):
    r=json.loads(l); y=r["y"]
    if not r["head"] or y is None or y<1900: continue
    link=r["link"]; tv=tid=None; res=False
    if link:
        f=link.split()[0]
        if "#" in f: pre,tid=f.split("#",1); tv=(pre[:-4] if pre.endswith(".xml") else pre) or r["v"]
        else: tv,tid=r["v"],f
        res=tid in IDS.get(tv,())
    if not res:
        if r["scope"] and y<1910: out["untagged_1900_1909_S"][s_rule(r["n"],y)[0]]+=1; out["untagged_1900_1909_S"]["rows"]+=1
        continue
    cid=CW.get(tv,{}).get(tid); a=AUTH.get(str(cid),{}) if cid else {}; slug=a.get("s")
    if slug and y<1930:
        out["silver_1900_1929_by_decade"][str(y//10*10)+"s"]+=1
        if y<1910: out["silver_1900_1929_vols_pre1910"][r["v"]]+=1
    if cid and not slug:
        cls,pick=s_rule(r["n"],y)
        if not pick: continue
        c=out["neg_birth"][band(y)]; c["false_picks"]+=1
        ab=a.get("b"); pb=birth.get(pick)
        if ab is None or pb is None: c["birth_unknown_either_side"]+=1
        elif ab==pb:
            c["birth_equal"]+=1
            if len(out["neg_birth_examples"][band(y)])<8: out["neg_birth_examples"][band(y)].append([r["v"],r["d"],r["n"],a.get("n"),ab,pick,pb,(a.get("r") or "")[:60]])
        elif abs(ab-pb)<=2: c["birth_within_2y"]+=1
        else: c["birth_differs"]+=1
rows=list(csv.DictReader(open(REPO+"/Planning/early-era-people/m1a-eval-candidates.csv")))
yc=collections.Counter(); m1=collections.Counter()
for r in rows:
    y=int(r["year"]); yc["<1900" if y<1900 else "1900-1909" if y<1910 else ">=1910"]+=1
    if y<1910: m1[s_rule(r["name_as_printed"],y)[0]]+=1
out["m1a_year_classes"]=yc; out["m1a_pre1910_S_mine"]=m1; out["m1a_1904_volume_rows_years"]=collections.Counter(r["year"] for r in rows if r["volume"]=="frus1904")
json.dump(out,open(D+"/v-extra.json","w"),indent=1,ensure_ascii=False); print(json.dumps(out,indent=1,ensure_ascii=False))
