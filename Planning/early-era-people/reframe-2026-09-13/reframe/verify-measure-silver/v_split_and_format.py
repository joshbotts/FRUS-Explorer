#!/usr/bin/env python3
"""VERIFY (a) split-part link targets/crosswalk/slug/doc counts from v-links-scope.jsonl + v-fromto.jsonl; (b) the 1873
list sizes and crosswalk entries; (c) whether untagged 1900-1929 head format is 'close to silver': split at doc year
1910, with the same classifier as v_silver.py (copied), and sample 'other' heads. Read-only."""
import json, os, re, collections, random
D=os.path.dirname(os.path.abspath(__file__))
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
PAI=json.load(open(REPO+"/FRUSExplorer/Resources/person-authority-index.json")); CW=PAI["crosswalk"]; AUTH=PAI["authority"]
S=json.load(open(D+"/v-scan.json"))["volumes"]; IDS={v:set(x["persName_xml_ids"]) for v,x in S.items()}
out={}
SPLIT=["frus1917Supp02v02","frus1918Supp01v02","frus1932v04"]
tg=collections.defaultdict(set); docs=collections.defaultdict(set); c=collections.defaultdict(collections.Counter)
for l in open(D+"/v-links-scope.jsonl"):
    v,did,ty,inh,tv,tid=json.loads(l)
    if v not in SPLIT: 
        if S[v]["scope"]: c["OTHER_SCOPE"][v]+=1
        continue
    c[v]["links"]+=1; c[v]["target:"+tv]+=1; c[v]["resolves"]+= tid in IDS.get(tv,())
    if did is None: continue
    c[v]["in_doc"]+=1; tg[v].add((tv,tid)); docs[v].add(did)
    cid=CW.get(tv,{}).get(tid); slug=AUTH.get(str(cid),{}).get("s") if cid else None
    if ty in ("from","to") and slug: c[v]["fromto_slug"]+=1; c[v]["fromto_head_slug"]+=inh
    if slug: c[v]["any_type_slug_in_doc"]+=1
for v in SPLIT:
    cw=[t for t in tg[v] if CW.get(t[0],{}).get(t[1])]; sl=[t for t in cw if AUTH.get(str(CW[t[0]][t[1]]),{}).get("s")]
    out[v]=dict(c[v]); out[v].update({"distinct_targets":len(tg[v]),"with_crosswalk":len(cw),"with_slug":len(sl),"docs_with_link":len(docs[v])})
out["other_scope_volumes_with_links"]=dict(c.get("OTHER_SCOPE",{}))
out["p1873_list_entries"]={v:len(IDS[v]) for v in ("frus1873p1v1","frus1873p1v2")}
out["p1873_crosswalk"]={v:CW.get(v) for v in ("frus1873p1v1","frus1873p1v2")}
out["fish_authority"]=AUTH.get("104298")
HON=re.compile(r"(?:Mr\.|Mrs\.|Sir|Señor|Senor|Baron|Count|M\.|Messrs\.?)$")
HONLEAD=re.compile(r"^(?:Mr\.|Mrs\.|Sir|Señor|Senor|Baron|Count|M\.|Messrs\.?)\s")
def fmt(r):
    b=r.get("before"); n=r["n"]
    if b is None: return "head_in_note_or_no_text"
    if b.endswith("("): return "paren"
    if HONLEAD.match(n) or HON.search(b): return "honorific"
    seg=b[b.rfind(" to ")+4:] if " to " in b else b
    if re.match(r"(?:No\.\s*\d+\.?\s*)?[Tt]he\s",seg.strip()): return "thetitle"
    return "other"
F=collections.defaultdict(collections.Counter); samp=collections.defaultdict(list); vol=collections.defaultdict(collections.Counter)
rng=random.Random(11)
for l in open(D+"/v-fromto.jsonl"):
    r=json.loads(l)
    if not (r["scope"] and r["head"] and not r["link"] and r["y"] and 1900<=r["y"]<=1929): continue
    k="1900-1909" if r["y"]<1910 else "1910-1929"; f=fmt(r); F[k][f]+=1; F[k]["rows"]+=1; vol[k][r["v"]]+=1
    if f=="other" and rng.random()<0.01 and len(samp[k])<15: samp[k].append([r["v"],r["d"],r["n"],(r.get("ht") or "")[:120]])
out["untagged_1900_1929_split"]={k:{**dict(x),"shares":{f:round(n/x["rows"],4) for f,n in x.items() if f!="rows"},"volumes":len(vol[k])} for k,x in F.items()}
out["other_samples"]=samp
json.dump(out,open(D+"/v-split-format.json","w"),indent=1,ensure_ascii=False); print(json.dumps(out,indent=1,ensure_ascii=False)[:6000])
