#!/usr/bin/env python3
"""Sum the raw qwen3-14b sweep's returned / located / unlocated / truncated counts over all detected heads (read-only)."""
import json, glob, os
STUDIO="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw/detected"
t={"heads":0,"returned":0,"unlocated":0,"located":0,"mentions":0,"truncated":0,"failed_chunks":0,"chunks":0}
for p in glob.glob(STUDIO+"/*.head.json"):
    h=json.load(open(p)); t["heads"]+=1
    for k in ("returned","unlocated","located","mentions","truncated","failed_chunks","chunks"):
        t[k]+=h.get(k) or 0
t["unlocated_share_of_returned"]=round(t["unlocated"]/t["returned"],4)
t["occurrences_per_located_string"]=round(t["mentions"]/t["located"],3)
json.dump(t,open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"sweep_grounding.json"),"w"),indent=1)
print(json.dumps(t,indent=1))
