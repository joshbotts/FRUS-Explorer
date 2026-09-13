#!/usr/bin/env python3
"""Editor-linked validation lens before 1906: what frus1873p1v1/v2 offer. Read-only.
TEI from/to persName with corresp/ref to a local xml:id -> person-authority-index crosswalk -> authority slug
-> POCOM chief/principal record; joined to the Swift harness's per-document shown rows."""
import re, json, glob, collections, os
HERE=os.path.dirname(os.path.abspath(__file__))
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
A=json.load(open(REPO+"/FRUSExplorer/Resources/person-authority-index.json"))
H={}
for l in open(HERE+"/../harness/frus-pre1906-classified.jsonl"):
    r=json.loads(l)
    if r["volume"].startswith("frus1873p1v"): H[(r["volume"],r["d"])]=r
pocom=set()
for p in glob.glob("/Users/jbotts/Development/pocom/missions-*/*.xml")+glob.glob("/Users/jbotts/Development/pocom/positions-principals/*.xml"):
    pocom.update(re.findall(r"<person-id>([^<]+)</person-id>", open(p).read()))
out={}
for v in ("frus1873p1v1","frus1873p1v2"):
    t=open(f"/Users/jbotts/Development/frus/volumes/{v}.xml",encoding="utf-8").read()
    cw=A["crosswalk"].get(v,{})
    c=collections.Counter(); docs_with_link=set(); shown_docs=set()
    for m in re.finditer(r'(?=<div\b[^>]*type="document"[^>]*xml:id="([^"]+)")', t):
        pass
    parts=re.split(r'(?=<div\b[^>]*type="document")', t)
    for part in parts[1:]:
        did=re.search(r'xml:id="([^"]+)"',part).group(1)
        h=H.get((v,did)); shown = bool(h and h["shown"])
        c["docs"]+=1; c["docs_shown_by_classifier"]+=shown
        for a in re.findall(r'<persName\b([^>]*)>', part):
            ty=re.search(r'type="(from|to)"',a)
            if not ty: continue
            c["fromto"]+=1
            ref=re.search(r'(?:corresp|ref)="#?([^"]+)"',a)
            if not ref: continue
            rid=ref.group(1).split("#")[-1]
            cid=cw.get(rid)
            c["fromto_with_ref"]+=1
            if cid is None: continue
            c["fromto_ref_in_crosswalk"]+=1
            slug=(A["authority"].get(str(cid)) or {}).get("s")
            if not slug: continue
            c["fromto_with_pocom_slug"]+=1
            if slug in pocom: c["fromto_slug_has_pocom_appointment"]+=1
            if shown: c["fromto_slug_in_doc_shown_by_classifier"]+=1
    out[v]=dict(c)
json.dump(out,open(HERE+"/lens_1873.json","w"),indent=1); print(json.dumps(out,indent=1))
