#!/usr/bin/env python3
"""Task 2+3. The silver identity set, from fromto.jsonl (scan_links.py): every from/to <persName> inside a document
div whose corresp/ref resolves to a persName xml:id in a persons list (local, or the sibling part for the three split
sets), whose (target volume, target id) has a person-authority-index crosswalk id whose authority entry carries a POCOM
slug `s`. For comparison, every UNLINKED from/to row in the 267 TEI-rule volumes, through the SAME code.

Per band of the document's TEI frus:doc-dateTime-min year:
  - sizes: mention rows, head rows, distinct (volume, document, type, slug) head rows, documents, volumes, persons;
  - S = POCOM surname x year, measure_pocom.load_pocom/surname_of/text_of imported VERBATIM (the assessment §2.5 rule):
    class unknown/nobody/one/several over doc year +-1; agreement of a 'one' pick with the silver slug;
  - whether the silver slug held any dated POCOM appointment covering doc year +-1 (the rule can reach it at all);
  - head format, one classifier for both populations: 'post' = (a) name inside '( )' preceded, after the last ' to ',
    by a post word; (b) a '( ... )' right after the name holding a post word; (c) a ', ...' appositive within 50 chars
    holding a post word; (d) a post word among the 3 tokens before the name. 'bare_honorific' = none of those and the
    name is preceded by Mr./Mrs./Señor/Sir/Baron/Count/M./Messrs. 'other' otherwise; 'name_not_in_head_text' when the
    tag-stripped head does not contain the name string. Post words: llm-pass/identity/candidates.py POST, copied.
  - provenance of the entry -> slug join: 'registry' when one HistoryAtState/people record carries BOTH the FRUS
    persons anchor and the departmenthistory slug (the join was made inside the OH registry); 'overlay' otherwise
    (the anchor reached the people-id through frus-name-authority persons-complete.xml frus-ref idnos)."""
import sys, json, re, collections, math
sys.path.insert(0,"/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-pocom")
import measure_pocom as M
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
PAI=json.load(open(REPO+"/FRUSExplorer/Resources/person-authority-index.json")); CW=PAI["crosswalk"]; AUTH=PAI["authority"]
reg=json.load(open("registry-provenance.json"))["records"]
anchor_slugs=collections.defaultdict(set); anchor_any=set()
for k,r in reg.items():
    for vol,ref in r["a"]:
        anchor_any.add((vol,ref))
        for s in r["s"]: anchor_slugs[(vol,ref)].add(s)
surnames,spans,by_surname=M.load_pocom()
POST = re.compile(r"\b(Secretary|Under Secretary|Assistant Secretary|Ambassador|Minister|Chargé|Charge|Consul|"
                  r"Vice Consul|Consul General|President|Governor|Counselor|Counsellor|Representative|Commissioner|"
                  r"Delegate|Delegation|Admiral|General|Agent|Envoy|Attorney General|Senator|Chairman|Prime Minister|"
                  r"Emperor|King|Queen|Sultan|Khedive|Viceroy|Premier|Chancellor|Director|Adviser|Advisor|Legation|Embassy|"
                  r"Military Attaché|Naval Attaché|Attaché|Ministry|Foreign Office|Department)\b")
HON=re.compile(r"(Mr\.|Mrs\.|Señor|Senor|Sir|Baron|Count|M\.|Messrs\.?)\s*$")
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
    if HON.search(before): return "bare_honorific"
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
B=collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
SETS=collections.defaultdict(lambda: collections.defaultdict(lambda: collections.defaultdict(set)))
vol_rows=collections.defaultdict(collections.Counter)
person_rows=collections.defaultdict(collections.Counter)
dis_examples=collections.defaultdict(list)
silver_out=open("silver-rows.jsonl","w")
for line in open("fromto.jsonl"):
    r=json.loads(line); y=r["y"]; bd=band(y); head=r["head"]
    linked=bool(r.get("link_raw")) and r.get("resolves")
    if not linked:
        if r["scope"]:
            pop="untagged_scope"
            c=B[pop][bd]; c["rows"]+=1
            if head:
                c["head_rows"]+=1
                cls,_=s_rule(r["n"],y); c["S_class:"+cls]+=1
                c["fmt:"+head_format(r.get("ht"),r["n"])]+=1
        continue
    cid=CW.get(r["tv"],{}).get(r["tid"]); slug=AUTH.get(str(cid),{}).get("s") if cid else None
    grp="split_part_in_scope" if r["scope"] else "list_volume"
    for pop in ("linked_all", "linked_"+grp):
        c=B[pop][bd]; c["rows"]+=1; c["crosswalk" if cid else "no_crosswalk"]+=1
        if slug: c["slug"]+=1
        if head:
            c["head_rows"]+=1
            if slug: c["head_slug"]+=1
    if not slug: continue
    cls,pick=s_rule(r["n"],y)
    inoffice=any(a-1<=y<=b+1 for a,b in spans.get(slug,[])) if y is not None else None
    prov="registry" if slug in anchor_slugs.get((r["tv"],r["tid"]),()) else ("overlay_anchor_in_registry_without_slug" if (r["tv"],r["tid"]) in anchor_any else "overlay")
    fmt=head_format(r.get("ht"),r["n"]) if head else "not_head"
    rec={"v":r["v"],"d":r["d"],"t":r["t"],"n":r["n"],"y":y,"band":bd,"head":head,"tv":r["tv"],"tid":r["tid"],"cid":cid,"slug":slug,
         "S_class":cls,"S_pick":pick,"S_j":(None if pick is None else ("agree" if pick==slug else "disagree")),"slug_in_pocom_office_y1":inoffice,
         "prov":prov,"fmt":fmt,"grp":grp,"ht":r.get("ht")}
    silver_out.write(json.dumps(rec)+"\n")
    for pop in ("silver_all","silver_"+grp):
        for pos in ("all","head") if head else ("all",):
            c=B[pop+"|"+pos][bd]; S=SETS[pop+"|"+pos][bd]
            c["rows"]+=1; c["S_class:"+cls]+=1; c["prov:"+prov]+=1; c["fmt:"+fmt]+=1
            c["slug_in_pocom_office_y1:"+str(inoffice)]+=1
            if pick: c["S_picks"]+=1; c["S_agree" if pick==slug else "S_disagree"]+=1
            if cls=="one" and pick!=slug: c["S_one_wrong_person"]+=1
            if y is not None and y<1906: c["pre1906_doc"]+=1
            S["docs"].add((r["v"],r["d"])); S["vols"].add(r["v"]); S["persons"].add(slug); S["doc_type_person"].add((r["v"],r["d"],r["t"],slug))
            if pos=="head": vol_rows[bd][r["v"]]+=1; person_rows[bd][slug]+=1
    if head and pick and pick!=slug and len(dis_examples[bd])<12:
        dis_examples[bd].append([r["v"],r["d"],r["t"],r["n"],slug,pick,(r.get("ht") or "")[:140]])
res={"definitions":__doc__,"bands":{}}
for pop,byb in B.items():
    res["bands"][pop]={}
    for bd,c in sorted(byb.items()):
        d=dict(c)
        S=SETS.get(pop,{}).get(bd)
        if S: d.update({"distinct_documents":len(S["docs"]),"distinct_volumes":len(S["vols"]),"distinct_persons":len(S["persons"]),"distinct_doc_type_person":len(S["doc_type_person"])})
        if "S_picks" in d: d["S_agreement_wilson_mention_grain"]=wilson(d.get("S_agree",0),d["S_picks"])
        res["bands"][pop][bd]=d
res["head_concentration"]={bd:{"top_volumes":vr.most_common(5),"top_persons":person_rows[bd].most_common(8),"volumes":len(vr),"persons":len(person_rows[bd]),
                               "top_person_share":round(person_rows[bd].most_common(1)[0][1]/sum(person_rows[bd].values()),4)} for bd,vr in vol_rows.items()}
res["S_disagreement_examples_head"]=dis_examples
json.dump(res,open("silver.json","w"),indent=1,ensure_ascii=False)
for pop in ("linked_all","linked_list_volume","linked_split_part_in_scope","silver_all|all","silver_all|head","silver_split_part_in_scope|head","untagged_scope"):
    print("==",pop)
    for bd,d in res["bands"].get(pop,{}).items(): print("  ",bd,json.dumps(d,ensure_ascii=False))
print(json.dumps(res["head_concentration"],indent=1))
