import json, os
from datetime import datetime
H = os.path.expanduser("~")
studio = {}
for l in open(os.path.join(H, "Development/frus-semantic-raw/runs.jsonl")):
    r = json.loads(l); studio.setdefault(r["vol"], r)
runs = [json.loads(l) for l in open(os.path.join(H, "frus-semantic-raw-embeddinggemma-2/runs.jsonl"))]
bins = {}
tot_own = tot_ref = 0; tot_chars = tot_secs = 0
for r in runs:
    t = datetime.strptime(r["ts"], "%Y-%m-%dT%H:%M:%S")
    key = t.strftime("%m-%d %H:00")
    b = bins.setdefault(key, {"vols": 0, "own": 0.0, "ref": 0.0, "chars": 0, "secs": 0.0})
    b["vols"] += 1; b["chars"] += r["chars"]; b["secs"] += r["secs"]
    tot_chars += r["chars"]; tot_secs += r["secs"]
    s = studio.get(r["vol"])
    if s and s["ts"].startswith("2026-08-10") and s["chars"] == r["chars"]:
        b["own"] += r["secs"]; b["ref"] += s["secs"]; tot_own += r["secs"]; tot_ref += s["secs"]
for k in sorted(bins):
    b = bins[k]
    print("%s vols %3d  chars/s %6.0f  pace %.2f" % (k, b["vols"], b["chars"] / b["secs"], b["own"] / b["ref"] if b["ref"] else float("nan")))
print("whole run: chars/s %.0f, pace %.3f, embed secs %.0f (%.2f h), wall %s -> %s" % (tot_chars / tot_secs, tot_own / tot_ref, tot_secs, tot_secs / 3600, runs[0]["ts"], runs[-1]["ts"]))
studio_total = sum(s["secs"] for s in studio.values() if s["ts"].startswith("2026-08-10"))
print("studio Aug 10 secs", studio_total, studio_total / 3600)
