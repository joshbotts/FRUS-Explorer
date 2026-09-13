"""Reproduce NER-RUNBOOK §7.2's post-hoc union figures with the scorer's own functions (read-only)."""
import os, sys, json
sys.path.insert(0, '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest')
os.environ['GROUND_TRUTH'] = '/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/m2a-ground-truth.jsonl'
os.environ['STORE'] = os.path.expanduser('~/frus-ner-raw')
import score_detections as sd
gold, bands = sd.load_ground_truth(os.environ['GROUND_TRUTH'])
verify = False
base, base_ref = sd.collect_predictions(os.path.expanduser('~/frus-ner-raw'), 'marked', gold, verify)
out = {'documents': len(gold), 'mentions': sum(len(v) for v in gold.values()), 'baseline_refused': base_ref}
def score(name, preds):
    r = sd.score_one(name, preds, gold, bands, [])
    return {'strict': {k: r['strict'][k] for k in ('precision','recall','f1')},
            'relaxed': {k: r['relaxed'][k] for k in ('precision','recall','f1')},
            'documents_scored': r['documents_scored'],
            'by_band': {b: {'relaxed_f1': v['relaxed']['f1'], 'strict_f1': v['strict']['f1'], 'documents': v.get('documents')} for b, v in r['by_band'].items()}}
out['baseline'] = score('baseline', base)
for label, path in [('control_filtered', '~/frus-ner-raw-control-filtered'), ('sweep_filtered', '~/frus-ner-raw-filtered'), ('control_raw', '~/frus-ner-raw-control')]:
    det, ref = sd.collect_predictions(os.path.expanduser(path), 'detected', gold, verify)
    out[label] = score(label, det); out[label]['refused'] = ref
    union = {}
    for key in gold:
        if key in det and key in base:
            union[key] = sorted(set(base[key]) | set(det[key]))
    out['editor+' + label] = score('union', union)
json.dump(out, open('union_check.json', 'w'), indent=1)
print(json.dumps(out, indent=1))
