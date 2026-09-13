#!/usr/bin/env python3
"""Circularity check, read-only. Parse every HistoryAtState/people record: FRUS persons anchors (volume, ref) from
historicaldocuments/<vol>/persons#<ref> source-urls, and POCOM slugs from departmenthistory/people/<slug>.
Writes registry-provenance.json: for each record id, anchors + slugs; plus counts of records that carry BOTH
(i.e. the OH registry itself joins a FRUS list entry to a POCOM person)."""
import os, re, json, glob, collections
R="/Users/jbotts/Development/people/data"
FR=re.compile(r"historicaldocuments/([^/<\s]+)/persons#([^<\s]+)")
PC=re.compile(r"departmenthistory/people/([^<\s/#]+)")
recs={}; n=0
for root,_,files in os.walk(R):
    for f in files:
        if not f.endswith(".xml"): continue
        t=open(os.path.join(root,f),encoding="utf-8",errors="replace").read(); n+=1
        pid=re.search(r"<id>(\d+)</id>",t)
        if not pid: continue
        anchors=sorted(set(FR.findall(t))); slugs=sorted(set(PC.findall(t)))
        recs[pid.group(1)]={"a":anchors,"s":slugs}
both=[k for k,v in recs.items() if v["a"] and v["s"]]
out={"files":n,"records":len(recs),"with_frus_anchor":sum(1 for v in recs.values() if v["a"]),
     "with_pocom_slug":sum(1 for v in recs.values() if v["s"]),"with_both":len(both),
     "records_with_multiple_slugs":sum(1 for v in recs.values() if len(v["s"])>1)}
anchor_index={}
for k,v in recs.items():
    for a in v["a"]: anchor_index.setdefault("%s#%s"%a,[]).append(k)
out["distinct_anchors"]=len(anchor_index)
out["anchors_in_multiple_records"]=sum(1 for x in anchor_index.values() if len(x)>1)
json.dump({"summary":out,"records":recs},open("registry-provenance.json","w"))
print(json.dumps(out,indent=1))
