#!/usr/bin/env python3
"""SUPERSEDES silver.py's head-format and S tables (silver.py missed an honorific INSIDE the persName span, e.g.
'Mr. Bayard', and filed those heads as 'other'). Same inputs (fromto.jsonl, person-authority-index.json,
registry-provenance.json, POCOM via measure_pocom imported verbatim). Adds:
  - head format with the in-span honorific rule, cross-tabbed with the S class, for silver and untagged-scope heads;
  - S agreement per band split by join provenance (registry vs overlay);
  - a volume-cluster bootstrap (2,000 resamples of volumes, seed 234) for S agreement per band;
  - the NEGATIVE silver set: linked from/to heads whose crosswalk id has an authority entry with NO POCOM slug, i.e. a
    person the editors identified and the OH registry does not join to POCOM. An S 'one' pick there names a POCOM
    officeholder for someone who is not one — unless the registry simply missed the join, which is flagged when the
    picked officeholder's POCOM forename initial equals the authority entry's forename initial ('possible registry miss');
  - the top (silver slug, S pick) disagreement pairs per band."""
import sys, json, re, collections, math, random, glob
sys.path.insert(0,"/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-pocom")
import measure_pocom as M
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
PAI=json.load(open(REPO+"/FRUSExplorer/Resources/person-authority-index.json")); CW=PAI["crosswalk"]; AUTH=PAI["authority"]
reg=json.load(open("registry-provenance.json"))["records"]
anchor_slugs=collections.defaultdict(set)
for k,r in reg.items():
    for vol,ref in r["a"]:
        for s in r["s"]: anchor_slugs[(vol,ref)].add(s)
surnames,spans,by_surname=M.load_pocom()
forename={}
for p in glob.glob("/Users/jbotts/Development/pocom/people/*/*.xml"):
    t=open(p,encoding="utf-8",errors="replace").read()
    i=re.search(r"<id>([^<]+)</id>",t); f=re.search(r"<forename>([^<]*)</forename>",t)
    if i and f: forename[i.group(1)]=f.group(1).strip()
POST = re.compile(r"\b(Secretary|Under Secretary|Assistant Secretary|Ambassador|Minister|Chargé|Charge|Consul|"
                  r"Vice Consul|Consul General|President|Governor|Counselor|Counsellor|Representative|Commissioner|"
                  r"Delegate|Delegation|Admiral|General|Agent|Envoy|Attorney General|Senator|Chairman|Prime Minister|"
                  r"Emperor|King|Queen|Sultan|Khedive|Viceroy|Premier|Chancellor|Director|Adviser|Advisor|Legation|Embassy|"
                  r"Military Attaché|Naval Attaché|Attaché|Ministry|Foreign Office|Department)\b")
HONW=r"(Mr\.|Mrs\.|Señor|Senor|Sir|Baron|Count|M\.|Messrs\.?|Monsieur|Herr|Don)"
HON_BEFORE=re.compile(HONW+r"\s*$"); HON_IN=re.compile(r"^\s*"+HONW+r"\s")
def head_format(ht,name):
    if not ht or not name: return "no_head_text"
    i=ht.find(name)
    if i<0: return "name_not_in_head_text"
    before=ht[:i]; after=ht[i+len(name):]
    seg=before[before.rfind(" to ")+4:] if " to " in before else before
    if before.rstrip().endswith("(") and POST.search(seg[-90:]): return "post"
    m=re.match(r"\s*\(([^)]{0,80})\)",after)
    if m and POST.search(m.group(1)): return "post"
    m=re.match(r"\s*,\s*(.{0,50})",after)
    if m and POST.search(m.group(1).split(" to ")[0]): return "post"
    toks=before.split()[-3:]
    if toks and POST.search(" ".join(toks)) and not before.rstrip().lower().endswith(" to"): return "post"
    if HON_BEFORE.search(before) or HON_IN.match(name): return "bare_honorific"
    return "other"
def band(y):
    if y is None: return "no-year"
    return "pre-1861" if y<1861 else "1861-1899" if y<1900 else "1900-1929" if y<1930 else "1930-1945" if y<1946 else "1946-"
def s_rule(name,y):
    sur=M.surname_of(M.text_of(name))
    if not sur or sur not in by_surname: return "unknown",None
    if y is None: return "noyear",None
    live=[s for s in by_surname[sur] if any(a-1<=y<=b+1 for a,b in spans[s])]
    return {0:"nobody",1:"one"}.get(len(live),"several"),(live[0] if len(live)==1 else None)
def wilson(k,n,z=1.96):
    if not n: return None
    p=k/n; den=1+z*z/n; c=(p+z*z/(2*n))/den; h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den
    return [round(p,4),round(c-h,4),round(c+h,4)]
def ini(s):
    for tok in re.split(r"[\s.]+",s or ""):
        if tok and tok[0].isalpha() and tok not in ("Sir","Lord","Mr","Mrs","Dr","General","Admiral"): return tok[0].lower()
    return ""
T=collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
byvol=collections.defaultdict(lambda: collections.defaultdict(lambda:[0,0]))
dis=collections.defaultdict(collections.Counter)
negex=collections.defaultdict(list)
for line in open("fromto.jsonl"):
    r=json.loads(line)
    if not r["head"]: continue
    y=r["y"]; bd=band(y)
    linked=bool(r.get("link_raw")) and r.get("resolves")
    fmt=head_format(r.get("ht"),r["n"]); cls,pick=s_rule(r["n"],y)
    if not linked:
        if r["scope"]:
            c=T["untagged_scope_heads"][bd]; c["rows"]+=1; c["fmt:"+fmt]+=1; c["S_class:"+cls]+=1; c[cls+"|"+fmt]+=1
        continue
    cid=CW.get(r["tv"],{}).get(r["tid"]); a=AUTH.get(str(cid),{}) if cid else {}; slug=a.get("s")
    if cid and not slug:
        c=T["negative_heads_crosswalk_no_slug"][bd]; c["rows"]+=1; c["S_class:"+cls]+=1; c["fmt:"+fmt]+=1
        if pick:
            c["S_false_picks"]+=1
            en=a.get("n",""); ef=en.split(",",1)[1] if "," in en else ""
            leak=ini(ef)!="" and ini(ef)==ini(forename.get(pick,""))
            c["S_false_picks_possible_registry_miss" if leak else "S_false_picks_initial_differs_or_unknown"]+=1
            if len(negex[bd])<10 and not leak: negex[bd].append([r["v"],r["d"],r["n"],en,(a.get("r") or "")[:80],pick])
        continue
    if not slug:
        c=T["linked_heads_no_crosswalk"][bd]; c["rows"]+=1; c["S_class:"+cls]+=1
        if pick: c["S_picks_unscoreable"]+=1
        continue
    prov="registry" if slug in anchor_slugs.get((r["tv"],r["tid"]),()) else "overlay"
    for pop in ("silver_heads","silver_heads|"+prov,"silver_heads|"+("split_part_in_scope" if r["scope"] else "list_volume")):
        c=T[pop][bd]; c["rows"]+=1; c["fmt:"+fmt]+=1; c["S_class:"+cls]+=1; c[cls+"|"+fmt]+=1
        if pick: c["S_picks"]+=1; c["S_agree" if pick==slug else "S_disagree"]+=1
    if pick:
        bv=byvol[bd][r["v"]]; bv[1]+=1; bv[0]+= (pick==slug)
        if pick!=slug: dis[bd][(slug,pick)]+=1
res={"definitions":__doc__,"pocom_forenames_loaded":len(forename),"tables":{}}
for pop,byb in T.items():
    res["tables"][pop]={}
    for bd,c in sorted(byb.items()):
        d=dict(c)
        if "S_picks" in d: d["S_agreement_wilson_mention_grain"]=wilson(d.get("S_agree",0),d["S_picks"])
        if "S_false_picks" in d: d["S_false_pick_share_of_rows"]=wilson(d["S_false_picks"],d["rows"])
        n=d["rows"]; d["shares"]={k:round(v/n,4) for k,v in d.items() if isinstance(v,int) and (k.startswith("fmt:") or k.startswith("S_class:"))}
        res["tables"][pop][bd]=d
rng=random.Random(234); boot={}
for bd,vols in byvol.items():
    vl=list(vols.items())
    if len(vl)<3: boot[bd]={"volumes":len(vl),"note":"too few volumes to bootstrap"}; continue
    vals=[]
    for _ in range(2000):
        s=[vl[rng.randrange(len(vl))][1] for _ in vl]; a=sum(x[0] for x in s); n=sum(x[1] for x in s)
        if n: vals.append(a/n)
    vals.sort(); boot[bd]={"volumes":len(vl),"point":round(sum(v[0] for _,v in vl)/sum(v[1] for _,v in vl),4),
                           "p2.5":round(vals[int(0.025*len(vals))],4),"p97.5":round(vals[int(0.975*len(vals))-1],4),
                           "worst_volume":min(((v[0]/v[1],k,v[1]) for k,v in vl if v[1]>=20),default=None)}
res["S_agreement_volume_bootstrap"]=boot
res["S_disagreement_pairs_top"]={bd:[[a,b,n] for (a,b),n in c.most_common(12)] for bd,c in dis.items()}
res["negative_examples_initial_differs"]=negex
json.dump(res,open("silver2.json","w"),indent=1,ensure_ascii=False)
for pop in ("silver_heads","silver_heads|registry","silver_heads|overlay","silver_heads|split_part_in_scope","negative_heads_crosswalk_no_slug","linked_heads_no_crosswalk","untagged_scope_heads"):
    print("==",pop)
    for bd,d in res["tables"].get(pop,{}).items():
        print("  ",bd,{k:v for k,v in d.items() if "|" not in k})
print(json.dumps({"boot":boot,"dis":res["S_disagreement_pairs_top"],"negex":negex},indent=1,ensure_ascii=False)[:5000])
