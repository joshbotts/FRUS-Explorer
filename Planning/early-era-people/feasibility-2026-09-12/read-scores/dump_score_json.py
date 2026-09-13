# Read-only dump of score-detections.json (64-document M2a score, 2026-09-12) and of the
# gold document list's per-band shape. No new statistics: counts only, as stored.
import json, sys
from collections import Counter
D="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"
j=json.load(open(D+"/score-detections.json"))
print({k:j[k] for k in j if k!='results'})
for r in j['results']:
    print("="*70); print(r['detector'], "scored", r['documents_scored'], "/", r['documents_in_ground_truth'], "refused", r['volumes_refused'])
    for m in ('strict','relaxed'): print(" ", m, r[m])
    for b,v in r['by_band'].items(): print("   ", b, "docs", v['documents'], "strict", v['strict'], "relaxed", v['relaxed'])
    print("  FP examples (first 40 in sorted (v,d) order, NOT a random draw):", "; ".join(f"{x['v']}/{x['d']}:{x['n']}" for x in r['false_positive_examples']))
    print("  miss examples (same ordering):", "; ".join(f"{x['v']}/{x['d']}:{x['n']}" for x in r['missed_examples']))
rows=[json.loads(l) for l in open(D+"/m2a-ground-truth-documents.jsonl")]
print("="*70)
print("gold docs", len(rows), Counter(r['band'] for r in rows))
print("mentions by band", {b:sum(r['mentions'] for r in rows if r['band']==b) for b in sorted({r['band'] for r in rows})})
print("zero-mention docs", [(r['v'],r['d'],r['mark']) for r in rows if r['mentions']==0], "marks", Counter(r['mark'] for r in rows))
seg1={'frus1864p2','frus1865p1','frus1866p3','frus1872p2v5'}
print("gold docs in sweep segment-1 volumes", sum(r['v'] in seg1 for r in rows), "mentions", sum(r['mentions'] for r in rows if r['v'] in seg1))
