import json, sys
import numpy as np
SP = sys.argv[1]
d = json.load(open(f"{SP}/d2/calibration.json"))
def show(c, c0): return np.clip((np.asarray(c) - c0) / (1 - c0), 0, 1) * 100
for c0q, c0d in ((0.47, 0.40), (0.45, 0.45)):
    print(f"-- offsets query {c0q} document {c0d}")
    for s in ("owner", "topical", "null"):
        for k, lab in ((0, "rank1"), (9, "rank10")):
            a = [r["top10"][k] for r in d["300m"][s] if r["text"] != "Space aliens"]
            b = [r["top10"][k] for r in d["eg2"][s] if r["text"] != "Space aliens"]
            print(f"   {s:8s} {lab:6s} 300m {np.median(a)*100:5.1f}  EG2 raw {np.median(b)*100:5.1f}  EG2 shown {np.median(show(b, c0q)):5.1f}")
    for k, lab in ((0, "top1"), (9, "top10"), (19, "top20")):
        a = [r["top20"][k] for r in d["300m"]["related"]]; b = [r["top20"][k] for r in d["eg2"]["related"]]
        print(f"   related  {lab:6s} 300m {np.median(a)*100:5.1f}  EG2 raw {np.median(b)*100:5.1f}  EG2 shown {np.median(show(b, c0d)):5.1f}")
    sa = [r for r in d["eg2"]["owner"] if r["text"] == "Space aliens"][0]["top10"][0]
    print(f"   Space aliens EG2 shown {float(show(sa, c0q)):.1f}")
# How many null-query best matches read at or above the median on-topic best match, per model/scale
on3 = [r["top10"][0] for s in ("owner","topical") for r in d["300m"][s] if r["text"] != "Space aliens"]
off3 = [r["top10"][0] for r in d["300m"]["null"]]
on2 = [r["top10"][0] for s in ("owner","topical") for r in d["eg2"][s] if r["text"] != "Space aliens"]
off2 = [r["top10"][0] for r in d["eg2"]["null"]]
print("300m: null best p90", np.percentile(off3, 90)*100, "on-topic best p10", np.percentile(on3, 10)*100)
print("EG2 raw: null best p90", np.percentile(off2, 90)*100, "on-topic best p10", np.percentile(on2, 10)*100)
print("EG2 raw on-topic best range", min(on2)*100, max(on2)*100, "null best range", min(off2)*100, max(off2)*100)
print("300m on-topic best range", min(on3)*100, max(on3)*100, "null best range", min(off3)*100, max(off3)*100)
