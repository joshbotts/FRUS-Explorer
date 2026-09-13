"""Independent re-derivation of NER-RUNBOOK §4.8.3 store totals from detected/*.head.json (SC-1, SC-2)."""
import json, os, glob
SWEEP="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw"
CTRL=os.path.expanduser("~/frus-ner-raw-control")
SEG1_LAST="frus1872p2v5"
def heads(store):
    out={}
    for p in sorted(glob.glob(os.path.join(store,"detected","*.head.json"))):
        h=json.load(open(p)); out[h["volume"]]=h
    return out
sw=heads(SWEEP); ct=heads(CTRL)
print("sweep volumes",len(sw),"control volumes",len(ct), "same set", set(sw)==set(ct))
keys=["docs_scanned","chars_scanned","mentions","novel","overlapping_marked","marked_in_scanned_docs","secs","chunks","unlocated","truncated","unparsable","returned","located","prompt_tokens","completion_tokens","failed_chunks"]
def tot(hs):
    t={}
    for h in hs.values():
        for k in keys:
            if k in h and h[k] is not None: t[k]=t.get(k,0)+h[k]
    return t
ts=tot(sw); tc=tot(ct)
print("SWEEP totals:",json.dumps(ts))
print("CTRL  totals:",json.dumps(tc))
print("sweep sampled any:",any(h.get("sampled") for h in sw.values()),"control sampled any:",any(h.get("sampled") for h in ct.values()))
print("docs match per volume in all:",all(sw[v]["docs_scanned"]==ct[v]["docs_scanned"] for v in sw), "docs_scanned==docs_in_volume all:", all(h["docs_scanned"]==h["docs_in_volume"] for h in sw.values()))
print("sweep days = %.2f" % (ts["secs"]/86400), "unlocated %% = %.2f" % (100*ts["unlocated"]/ts["returned"]), "truncated %% = %.3f"%(100*ts["truncated"]/ts["chunks"]))
print("landing ratio sweep = %d / %d = %.1f%%" % (ts["overlapping_marked"], ts["marked_in_scanned_docs"], 100*ts["overlapping_marked"]/ts["marked_in_scanned_docs"]))
print("landing ratio ctrl  = %d / %d = %.1f%%" % (tc["overlapping_marked"], tc["marked_in_scanned_docs"], 100*tc["overlapping_marked"]/tc["marked_in_scanned_docs"]))
# segment split: scope order
scope=json.load(open(os.path.join(SWEEP,"scope.json")))["volumes"]
print("scope volumes",len(scope), "first", scope[0], "27th", scope[26], "28th", scope[27])
nofail=[v for v in scope if "failed_chunks" not in sw[v]]
print("volumes lacking failed_chunks key:",len(nofail), nofail[0], nofail[-1], "== first 27 of scope:", nofail==scope[:27])
seg1=scope[:27]; seg2=scope[27:]
for name,vols in (("seg1",seg1),("seg2",seg2)):
    t=tot({v:sw[v] for v in vols})
    print(name, "vols",len(vols), "mentions/doc %.2f"%(t["mentions"]/t["docs_scanned"]), "unlocated %.2f%%"%(100*t["unlocated"]/t["returned"]), "s/chunk %.2f"%(t["secs"]/t["chunks"]), "docs",t["docs_scanned"],"mentions",t["mentions"])
# runs.jsonl cross-check
runs=[json.loads(l) for l in open(os.path.join(SWEEP,"runs.jsonl")) if l.strip()]
print("runs.jsonl rows",len(runs),"keys",sorted(runs[0].keys()))
