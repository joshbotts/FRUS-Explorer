#!/usr/bin/env python3
"""VERIFY the silver identity set and the S rule on it, from MY scan (v-fromto.jsonl, ElementTree) and MY POCOM loader
(v_pocom.load). S rule re-typed from the assessment's definition (m1a surname_of: strip .,;:() ; drop TITLES; keep
capitalised tokens >=3 chars; last token). Two band keys: DOC = TEI frus:doc-dateTime-min year (what measure-silver
used), VOL = ner_store.band_of(volume id) (the assessment's band). Head = persName inside the document's own first
<head> child (subtree). Silver = from/to head persName whose link resolves to a persName xml:id in the target volume, whose
(target volume, id) has a person-authority-index crosswalk id whose authority entry carries a POCOM slug 's'.
Negative silver = crosswalk id present, authority entry has no 's'. Head format: MY classifier (not theirs):
  paren  = the persName directly follows '(' in the notes-stripped head (e.g. 'The Ambassador in X (Page)')
  thetitle = the head segment holding the name (split at ' to ') begins 'The '/'the ' and the name is not honorific-led
  honorific = name begins with, or the head text immediately before it ends with, Mr./Mrs./Sir/Señor/Baron/Count/M./Messrs.
  other otherwise; plus a CEILING: any office word anywhere in the head."""
import json, re, collections, math, os, sys, random
D=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,D)
import v_pocom
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
PAI=json.load(open(REPO+"/FRUSExplorer/Resources/person-authority-index.json")); CW=PAI["crosswalk"]; AUTH=PAI["authority"]
S=json.load(open(D+"/v-scan.json"))["volumes"]; IDS={v:set(x["persName_xml_ids"]) for v,x in S.items()}
sur,spans,by,fore=v_pocom.load()
TITLES={"Mr.","Mrs.","Sir","Lord","Count","Baron","Prince","King","Queen","Excellency","Dr.","Hon."}
def surname_of(name):
    toks=[t.strip(".,;:()") for t in name.split()]
    toks=[t for t in toks if t and t not in TITLES and t[0].isupper() and len(t)>=3]
    return toks[-1] if toks else None
def s_rule(name,y):
    s=surname_of(name)
    if not s or s not in by: return "unknown",None
    if y is None: return "noyear",None
    live=sorted(x for x in by[s] if any(a-1<=y<=b+1 for a,b in spans[x]))
    return ("nobody" if not live else "one" if len(live)==1 else "several"),(live[0] if len(live)==1 else None)
def band_y(y):
    if y is None: return "no-year"
    return "pre-1861" if y<1861 else "1861-1899" if y<=1899 else "1900-1929" if y<=1929 else "1930-1945" if y<=1945 else "1946-"
VY=re.compile(r"frus(\d{4})")
def band_v(v):
    m=VY.search(v); y=int(m.group(1)) if m else None
    return band_y(y) if y and y>=1861 else ("pre-1861" if y else None)
HON=re.compile(r"(?:Mr\.|Mrs\.|Sir|Señor|Senor|Baron|Count|M\.|Messrs\.?)$")
HONLEAD=re.compile(r"^(?:Mr\.|Mrs\.|Sir|Señor|Senor|Baron|Count|M\.|Messrs\.?)\s")
OFFICE=re.compile(r"\b(Secretary|Minister|Ambassador|Consul|Chargé|Charge|Legation|Embassy|President|Governor|Commissioner|Agent|Envoy|Delegate|Admiral|Senator|Counselor|Attaché)\b")
def fmt(r):
    b=r.get("before"); n=r["n"]
    if b is None: return "head_in_note_or_no_text"
    if b.endswith("("): return "paren"
    if HONLEAD.match(n) or HON.search(b): return "honorific"
    seg=b[b.rfind(" to ")+4:] if " to " in b else b
    if re.match(r"(?:No\.\s*\d+\.?\s*)?[Tt]he\s",seg.strip()): return "thetitle"
    return "other"
def wilson(k,n,z=1.96):
    if not n: return None
    p=k/n; den=1+z*z/n; c=(p+z*z/(2*n))/den; h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den
    return [round(p,4),round(c-h,4),round(c+h,4)]
def ini(s):
    for t in re.split(r"[\s.]+",s or ""):
        if t and t[0].isalpha() and t not in ("Sir","Lord","Mr","Mrs","Dr","General","Admiral"): return t[0].lower()
    return ""
T={k:collections.defaultdict(collections.Counter) for k in ("DOC","VOL")}
SETS={k:collections.defaultdict(lambda: collections.defaultdict(set)) for k in ("DOC","VOL")}
PERSON=collections.defaultdict(collections.Counter)
BYVOL=collections.defaultdict(lambda: collections.defaultdict(lambda:[0,0]))
LINKS1873=collections.defaultdict(collections.Counter); T1873=collections.defaultdict(set)
cross_band=collections.Counter()
for line in open(D+"/v-fromto.jsonl"):
    r=json.loads(line); v=r["v"]; y=r["y"]; head=r["head"]
    link=r["link"]; resolved=False; tv=tid=None
    if link:
        f=link.split()[0]
        if "#" in f: pre,tid=f.split("#",1); tv=(pre[:-4] if pre.endswith(".xml") else pre) or v
        else: tv,tid=v,f
        resolved= tid in IDS.get(tv,())
    cid=CW.get(tv,{}).get(tid) if resolved else None
    slug=AUTH.get(str(cid),{}).get("s") if cid else None
    if v in ("frus1873p1v1","frus1873p1v2"):
        c=LINKS1873[v]; c["fromto_in_doc"]+=1
        if resolved: c["fromto_resolving"]+=1; T1873[v].add(tid); c["fromto_head_resolving"]+=head
        if slug: c["fromto_slug"]+=1
    for key,bd in (("DOC",band_y(y)),("VOL",band_v(v))):
        if not head: 
            if resolved and slug: T[key]["silver_all_positions"][bd]+=1
            continue
        if not resolved:
            if r["scope"]:
                c=T[key]["untagged_heads|"+bd]; c["rows"]+=1; cls,_=s_rule(r["n"],y); c["S:"+cls]+=1; c["fmt:"+fmt(r)]+=1
                if r.get("ht") and OFFICE.search(r["ht"]): c["ceiling_office_word_anywhere_in_head"]+=1
            continue
        if cid and not slug:
            c=T[key]["negative|"+bd]; c["rows"]+=1; cls,pick=s_rule(r["n"],y); c["S:"+cls]+=1
            if pick:
                c["false_picks"]+=1
                a=AUTH.get(str(cid),{}); en=a.get("n",""); ef=en.split(",",1)[1] if "," in en else ""
                if ini(ef) and ini(ef)==ini(fore.get(pick,"")): c["false_picks_same_initial"]+=1
            continue
        if not slug: continue
        c=T[key]["silver|"+bd]; st=SETS[key]["silver|"+bd]
        c["rows"]+=1; cls,pick=s_rule(r["n"],y); c["S:"+cls]+=1; c["fmt:"+fmt(r)]+=1
        if y is not None and any(a-1<=y<=b+1 for a,b in spans.get(slug,[])): c["slug_in_office_y1"]+=1
        if pick: c["picks"]+=1; c["agree"]+= (pick==slug)
        if r["scope"]: c["split_part_rows"]+=1; st["split_vols"].add(v); st["split_persons"].add(slug)
        st["docs"].add((v,r["d"])); st["vols"].add(v); st["persons"].add(slug); st["dtp"].add((v,r["d"],r["t"],slug))
        if key=="DOC":
            PERSON[bd][slug]+=1
            if pick: bv=BYVOL[bd][v]; bv[1]+=1; bv[0]+=(pick==slug)
    if head and resolved and slug and band_y(y)!=band_v(v): cross_band[(band_y(y),band_v(v))]+=1
out={"definitions":__doc__,"DOC":{},"VOL":{}}
for key in ("DOC","VOL"):
    for name,c in sorted(T[key].items()):
        d=dict(c); st=SETS[key].get(name)
        if st: d.update({k:len(x) for k,x in st.items()})
        if "picks" in d: d["agree_wilson"]=wilson(d["agree"],d["picks"])
        if "rows" in d: d["shares"]={k:round(n/d["rows"],4) for k,n in c.items() if k.startswith(("fmt:","S:","ceiling"))}
        out[key][name]=d
    for bd in ("1861-1899","1900-1929","1930-1945","1946-"):
        p=out[key].get("silver|"+bd,{}); n=out[key].get("negative|"+bd,{})
        if p.get("picks"): out[key]["combined|"+bd]={"agree":p["agree"],"picks":p["picks"]+n.get("false_picks",0),"wilson":wilson(p["agree"],p["picks"]+n.get("false_picks",0))}
out["top_person_DOC"]={bd:[c.most_common(3),sum(c.values()),round(c.most_common(1)[0][1]/sum(c.values()),4)] for bd,c in PERSON.items()}
rng=random.Random(7); boot={}
for bd,vv in BYVOL.items():
    vl=list(vv.values())
    if len(vl)<3: continue
    vals=sorted((lambda s:sum(x[0] for x in s)/sum(x[1] for x in s))([vl[rng.randrange(len(vl))] for _ in vl]) for _ in range(2000))
    boot[bd]=[len(vl),round(vals[50],4),round(vals[1949],4),min(round(a/b,3) for a,b in vl if b>=20)]
out["volume_bootstrap_DOC"]=boot
out["p1873"]={v:dict(c) for v,c in LINKS1873.items()}; out["p1873_distinct_linked_fromto_targets"]={v:len(s) for v,s in T1873.items()}
out["silver_heads_band_DOC_vs_VOL_mismatch"]={f"{a} (doc) / {b} (vol)":n for (a,b),n in cross_band.items()}
json.dump(out,open(D+"/v-silver.json","w"),indent=1,ensure_ascii=False)
for key in ("DOC","VOL"):
    print("=====",key)
    for name,d in out[key].items(): print(name,{k:v for k,v in d.items() if k!="shares"}); 
    for name,d in out[key].items():
        if "shares" in d: print("  shares",name,d["shares"])
for k in ("top_person_DOC","volume_bootstrap_DOC","p1873","p1873_distinct_linked_fromto_targets","silver_heads_band_DOC_vs_VOL_mismatch"): print(k,out[k])
