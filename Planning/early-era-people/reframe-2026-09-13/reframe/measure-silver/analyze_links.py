#!/usr/bin/env python3
"""Task 1 from links.jsonl (scan_links.py output). Every <persName corresp|ref> in the manifest corpus, split into:
  (a) links inside the 267 TEI-rule scope volumes, per volume: cross-volume vs local, resolving vs dangling, inside a
      document div, from/to vs untyped, in the document's own head; the target lists; how many targets carry a
      person-authority crosswalk id and a POCOM slug;
  (b) in list volumes: links into ANOTHER volume (cross-part), and dangling links;
  (c) the 1873 pair."""
import json, collections, re
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
PAI=json.load(open(REPO+"/FRUSExplorer/Resources/person-authority-index.json"))
CW=PAI["crosswalk"]; AUTH=PAI["authority"]
def slug_of(tv,tid):
    cid=CW.get(tv,{}).get(tid)
    return (cid, AUTH.get(str(cid),{}).get("s") if cid else None)
scope=collections.defaultdict(collections.Counter); scope_targets=collections.defaultdict(set); scope_docs=collections.defaultdict(set)
scope_slug_targets=collections.defaultdict(set); scope_cw_targets=collections.defaultdict(set)
cross_list=collections.Counter(); dangling_list=collections.Counter(); dangling_examples=collections.defaultdict(list)
p1873=collections.defaultdict(collections.Counter); p1873_targets=collections.defaultdict(set)
list_total=collections.Counter()
for line in open("links.jsonl"):
    r=json.loads(line)
    v=r["v"]; indoc=r["d"] is not None; ft=r["t"] in ("from","to")
    if r["scope"]:
        c=scope[v]; c["links"]+=1
        c["cross" if r["cross"] else "local"]+=1
        c["resolves" if r["resolves"] else "dangling"]+=1
        if indoc: c["in_document"]+=1; scope_docs[v].add(r["d"])
        if indoc and r["resolves"]:
            c["in_document_resolving"]+=1
            c["fromto_resolving" if ft else "untyped_resolving"]+=1
            if r["head"]: c["in_head_resolving"]+=1
            if ft and r["head"]: c["fromto_head_resolving"]+=1
            cid,s=slug_of(r["tv"],r["tid"])
            if cid: c["in_document_resolving_crosswalk"]+=1; scope_cw_targets[v].add((r["tv"],r["tid"]))
            if s:
                c["in_document_resolving_slug"]+=1; scope_slug_targets[v].add((r["tv"],r["tid"]))
                if ft: c["fromto_resolving_slug"]+=1
                if ft and r["head"]: c["fromto_head_resolving_slug"]+=1
            scope_targets[v].add((r["tv"],r["tid"]))
        c["target:"+r["tv"]]+=1
    else:
        list_total["links"]+=1
        if r["cross"]:
            cross_list[(v,r["tv"],r["resolves"],indoc)]+=1
        if not r["resolves"]:
            dangling_list[(v,indoc)]+=1
            if len(dangling_examples[v])<3: dangling_examples[v].append(r["link_raw"])
        if v in ("frus1873p1v1","frus1873p1v2"):
            c=p1873[v]; c["links"]+=1
            if indoc: c["in_document"]+=1
            if indoc and ft: c["fromto_in_document"]+=1
            if indoc and ft and r["resolves"]: c["fromto_resolving"]+=1; p1873_targets[v].add(r["tid"])
            if indoc and ft and r["resolves"] and r["head"]: c["fromto_head_resolving"]+=1
            if indoc and ft and r["resolves"] and slug_of(r["tv"],r["tid"])[1]: c["fromto_resolving_slug"]+=1
            if indoc and not ft and r["resolves"]: c["untyped_resolving"]+=1
            if not indoc: c["outside_document"]+=1
V="/Users/jbotts/Development/frus/volumes"
ids1873={v:set(re.findall(r'<persName\b[^>]*\bxml:id="([^"]+)"',open(f"{V}/{v}.xml",encoding="utf-8").read())) for v in ("frus1873p1v1","frus1873p1v2")}
out={"scope_per_volume":{v:dict(c) for v,c in sorted(scope.items())},
     "scope_distinct_targets":{v:len(s) for v,s in scope_targets.items()},
     "scope_distinct_targets_with_crosswalk":{v:len(s) for v,s in scope_cw_targets.items()},
     "scope_distinct_targets_with_slug":{v:len(s) for v,s in scope_slug_targets.items()},
     "scope_documents_with_link":{v:len(s) for v,s in scope_docs.items()},
     "list_volume_links_total":list_total["links"],
     "list_volume_cross_volume_links":[[a,b,res,indoc,n] for (a,b,res,indoc),n in sorted(cross_list.items(),key=lambda x:-x[1])],
     "list_volume_dangling_links":[[a,indoc,n] for (a,indoc),n in sorted(dangling_list.items(),key=lambda x:-x[1])],
     "list_volume_dangling_examples":dict(dangling_examples),
     "p1873":{v:dict(c) for v,c in p1873.items()},
     "p1873_list_entries":{v:len(s) for v,s in ids1873.items()},
     "p1873_distinct_linked_fromto_targets":{v:len(s) for v,s in p1873_targets.items()},
     "p1873_crosswalk_entries":{v:CW.get(v) for v in ("frus1873p1v1","frus1873p1v2")}}
json.dump(out,open("links-analysis.json","w"),indent=1)
print(json.dumps({k:out[k] for k in ("scope_per_volume","scope_distinct_targets","scope_distinct_targets_with_crosswalk","scope_distinct_targets_with_slug","scope_documents_with_link","p1873","p1873_list_entries","p1873_distinct_linked_fromto_targets","p1873_crosswalk_entries","list_volume_links_total")},indent=1))
print("cross-volume links in list volumes (source,target,resolves,in_doc,n):",out["list_volume_cross_volume_links"][:40])
print("dangling in list volumes, top 25:",out["list_volume_dangling_links"][:25], "total dangling rows:",sum(n for _,_,n in out["list_volume_dangling_links"]))
