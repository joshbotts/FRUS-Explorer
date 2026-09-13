#!/usr/bin/env python3
"""Independent re-summation of the sweep / control / marked / filtered head.json files.
Written for verification; does not import the author's modules."""
import json, os, glob, sys
SWEEP="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw"
CTRL=os.path.expanduser("~/frus-ner-raw-control")
MARKED_MAC=os.path.expanduser("~/frus-ner-raw")
FILT={"filtered":os.path.expanduser("~/frus-ner-raw-filtered"),
      "boundary":os.path.expanduser("~/frus-ner-raw-filtered-boundary"),
      "ctrl-filtered":os.path.expanduser("~/frus-ner-raw-control-filtered")}
def heads(store, layer):
    out={}
    for p in sorted(glob.glob(os.path.join(store,layer,"*.head.json"))):
        h=json.load(open(p)); out[h["volume"]]=h
    return out
sw=heads(SWEEP,"detected"); ct=heads(CTRL,"detected"); mk=heads(SWEEP,"marked"); mkmac=heads(MARKED_MAC,"marked")
print("sweep heads",len(sw),"control heads",len(ct),"marked heads (studio)",len(mk),"marked heads (mac)",len(mkmac))
def tot(hs,keys):
    return {k:sum(h.get(k,0) or 0 for h in hs.values()) for k in keys}
K=["docs_scanned","docs_in_volume","chars_scanned","mentions","novel","overlapping_marked","marked_in_scanned_docs","secs","chunks","returned","located","unlocated","truncated","failed_chunks","unparsable","prompt_tokens","completion_tokens"]
ts=tot(sw,K); tc=tot(ct,K)
print("SWEEP",json.dumps(ts))
print("CTRL",json.dumps(tc))
print("sweep secs/days", ts["secs"], ts["secs"]/86400)
print("sweep sampled any?", any(h.get("sampled") for h in sw.values()), "ctrl sampled any?", any(h.get("sampled") for h in ct.values()))
print("sweep unlocated %%: %.2f"%(100*ts["unlocated"]/ts["returned"]), "truncated %% of chunks: %.3f"%(100*ts["truncated"]/ts["chunks"]))
mtot=sum(h["mentions"] for h in mk.values()); print("marked mentions (studio store) =",mtot, "; mac store =",sum(h["mentions"] for h in mkmac.values()))
print("sweep overlapping/marked = %d/%d = %.1f%%"%(ts["overlapping_marked"],mtot,100*ts["overlapping_marked"]/mtot))
print("ctrl overlapping/marked = %d/%d = %.1f%%"%(tc["overlapping_marked"],mtot,100*tc["overlapping_marked"]/mtot))
# per-volume doc agreement
mism=[v for v in sw if v not in ct or sw[v]["docs_scanned"]!=ct[v]["docs_scanned"]]
print("volumes with docs_scanned mismatch between arms:",len(mism), mism[:5])
print("sweep volumes docs_scanned != docs_in_volume:",[v for v,h in sw.items() if h["docs_scanned"]!=h["docs_in_volume"]])
# segment split: heads lacking failed_chunks
seg1={v:h for v,h in sw.items() if "failed_chunks" not in h}; seg2={v:h for v,h in sw.items() if "failed_chunks" in h}
print("segment1 (no failed_chunks key):",len(seg1), sorted(seg1)[:3], "...", sorted(seg1)[-3:])
for name,seg in (("seg1",seg1),("seg2",seg2)):
    t=tot(seg,K)
    print(name,"vols",len(seg),"docs",t["docs_scanned"],"mentions/doc %.2f"%(t["mentions"]/t["docs_scanned"]),"unlocated %.2f%%"%(100*t["unlocated"]/t["returned"]),"s/chunk %.2f"%(t["secs"]/t["chunks"]))
print("seg1 all pre-1873?", all(int(v[4:8])<=1872 for v in seg1), "max year", max(int(v[4:8]) for v in seg1))
print("gold vols in seg1:", [v for v in ("frus1864p2","frus1865p1","frus1866p3","frus1872p2v5") if v in seg1])
# runs.jsonl check
runs=[json.loads(l) for l in open(os.path.join(SWEEP,"runs.jsonl")) if l.strip()]
det=[r for r in runs if r.get("detected") is not None]
dv={}
for r in det: dv[r["vol"]]=r   # last run per volume wins
dm=lambda r: r["detected"]["mentions"] if isinstance(r["detected"],dict) else r["detected"]
print("runs.jsonl rows",len(runs),"detected rows",len(det),"distinct vols",len(dv),"sum mentions(last per vol)",sum(dm(r) for r in dv.values()),"sum secs(last per vol)",round(sum(r["secs"] for r in dv.values()),1))
# filtered stores: re-sum heads vs manifest
for name,store in FILT.items():
    hs=heads(store,"detected"); m=json.load(open(os.path.join(store,"run-manifest.json")))["totals"]
    kept=sum(h["mentions"] for h in hs.values())
    rules={}; ed={}
    for h in hs.values():
        f=h.get("filter",{})
        for k,v in (f.get("removed_by_rule") or {}).items(): rules[k]=rules.get(k,0)+v
        for k,v in (f.get("removed_spans_editors_marked_as_person_by_rule") or f.get("editor_marked_removed_by_rule") or {}).items(): ed[k]=ed.get(k,0)+v
    print(name,"heads",len(hs),"kept(sum heads)",kept,"manifest kept",m["kept"],"rules(sum heads)",rules,"manifest",m["removed_by_rule"],"editor-overlap(sum heads)",ed,sum(ed.values()))
    if not rules: print("  filter block keys:", list(next(iter(hs.values())).get("filter",{}).keys()))
