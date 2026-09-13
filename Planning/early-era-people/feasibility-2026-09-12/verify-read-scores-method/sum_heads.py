import json, glob, os, collections
SW="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw/detected"
CT=os.path.expanduser("~/frus-ner-raw-control/detected")
def load(d):
    out={}
    for p in sorted(glob.glob(d+"/*.head.json")):
        v=os.path.basename(p)[:-len(".head.json")]
        out[v]=json.load(open(p))
    return out
sw=load(SW); ct=load(CT)
print("sweep heads", len(sw), "control heads", len(ct))
k0=next(iter(sw)); print("sweep head keys", sorted(sw[k0].keys()))
print("control head keys", sorted(ct[next(iter(ct))].keys()))
def num(h,k): 
    v=h.get(k); return v if isinstance(v,(int,float)) else 0
vols=sorted(sw)
seg1=[v for v in vols if v<= "frus1872p2v5"]
print("seg1 count", len(seg1), seg1[0], seg1[-1], "seg2 count", len(vols)-len(seg1))
for name,segvols in (("seg1",seg1),("seg2",[v for v in vols if v>"frus1872p2v5"]),("all",vols)):
    tot=collections.Counter()
    for v in segvols:
        for k,val in sw[v].items():
            if isinstance(val,(int,float)) and not isinstance(val,bool): tot[k]+=val
    docs=tot.get("documents") or tot.get("docs") or tot.get("documents_scanned")
    print(name, {k:tot[k] for k in sorted(tot) if k in ("documents","docs","documents_scanned","mentions","chunks","secs","unlocated","truncated","overlapping_marked","marked_in_scanned_docs","strings_returned","returned_strings","failed_chunks","chars","characters")})
    if docs and tot.get("mentions"): print("   mentions/doc %.2f"%(tot["mentions"]/docs), "unlocated%% %.2f"%(100*tot.get("unlocated",0)/max(1,tot.get("strings_returned",tot.get("returned_strings",1)))), "s/chunk %.2f"%(tot.get("secs",0)/max(1,tot.get("chunks",1))))
    print("   failed_chunks key present in", sum(1 for v in segvols if "failed_chunks" in sw[v]), "of", len(segvols))
ctot=collections.Counter()
for v in ct.values():
    for k,val in v.items():
        if isinstance(val,(int,float)) and not isinstance(val,bool): ctot[k]+=val
print("control totals", {k:ctot[k] for k in sorted(ctot) if k in ("documents","docs","mentions","secs","overlapping_marked","marked_in_scanned_docs","characters","chars")})
mismatch=[v for v in vols if sw[v].get("documents")!=ct.get(v,{}).get("documents")]
print("per-volume doc-count mismatches", len(mismatch), mismatch[:5])
print("sampled flags sweep", collections.Counter(str(h.get("sampled")) for h in sw.values()), "control", collections.Counter(str(h.get("sampled")) for h in ct.values()))
