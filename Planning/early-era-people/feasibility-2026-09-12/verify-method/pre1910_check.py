"""Pre-1910 cut: scope volumes and gold documents by volume year (read-only)."""
import os, sys, json, re
sys.path.insert(0, '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest')
os.environ['GROUND_TRUTH'] = '/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/m2a-ground-truth.jsonl'
import score_detections as sd
def year(v):
    m = re.match(r'frus(\d{4})', v); return int(m.group(1)) if m else None
scope = json.load(open(os.path.expanduser('~/frus-ner-raw/scope.json')))['volumes']
vols = [v if isinstance(v, str) else v.get('volume') or v.get('id') for v in scope]
pre1910 = [v for v in vols if year(v) and year(v) < 1910]
pre1930 = [v for v in vols if year(v) and year(v) < 1930]
out = {'scope_volumes': len(vols), 'scope_pre1910_volumes': len(pre1910), 'scope_pre1930_volumes': len(pre1930), 'unparsed': [v for v in vols if not year(v)]}
gold, bands = sd.load_ground_truth(os.environ['GROUND_TRUTH'])
sub = {k: v for k, v in gold.items() if year(k[0]) < 1910}
out['gold_docs_pre1910'] = len(sub); out['gold_spans_pre1910'] = sum(len(v) for v in sub.values())
out['gold_docs_pre1910_by_band'] = {}
for k in sub: out['gold_docs_pre1910_by_band'][bands[k]] = out['gold_docs_pre1910_by_band'].get(bands[k], 0) + 1
out['gold_volumes_pre1910'] = sorted(set(k[0] for k in sub))
subbands = {k: bands[k] for k in sub}
res = {}
base, _ = sd.collect_predictions(os.path.expanduser('~/frus-ner-raw'), 'marked', sub, False)
res['baseline'] = sd.score_one('b', base, sub, subbands, [])
for label, path in [('sweep_filtered', '~/frus-ner-raw-filtered'), ('sweep_raw', '/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw'), ('control_filtered', '~/frus-ner-raw-control-filtered'), ('control_raw', '~/frus-ner-raw-control')]:
    det, _ = sd.collect_predictions(os.path.expanduser(path), 'detected', sub, False)
    res[label] = sd.score_one(label, det, sub, subbands, [])
out['pre1910_scores'] = {k: {'strict': {m: r['strict'][m] for m in ('precision','recall','f1')}, 'relaxed': {m: r['relaxed'][m] for m in ('precision','recall','f1')}, 'docs': r['documents_scored']} for k, r in res.items()}
json.dump(out, open('pre1910_check.json', 'w'), indent=1); print(json.dumps(out, indent=1))
