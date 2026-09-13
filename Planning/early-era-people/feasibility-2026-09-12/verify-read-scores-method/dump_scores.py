import json
p="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/score-detections.json"
d=json.load(open(p))
print("top keys:", list(d.keys()))
for k,v in d.items():
    if k!="results": print(k, json.dumps(v)[:600])
for r in d["results"]:
    print("=== ", r.get("name") or r.get("detector") or r.get("store"))
    for k,v in r.items():
        if k in ("false_positive_examples","missed_examples"): print(k, len(v), v[:6])
        elif k=="by_band":
            for b,bv in v.items(): print("  band",b,json.dumps(bv))
        else: print(k, json.dumps(v)[:400])
