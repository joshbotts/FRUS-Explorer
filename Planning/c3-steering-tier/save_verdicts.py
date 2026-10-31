#!/usr/bin/env python3
"""Save one workflow run's agent results from its journal into runs/<label>/verdicts.json and
print a one-screen summary.   python3 save_verdicts.py <transcript dir> <label>"""
import json, sys, os
d, label = sys.argv[1], sys.argv[2]
labels = {}
out = {}
for line in open(os.path.join(d, 'journal.jsonl')):
    r = json.loads(line)
    if r.get('type') == 'started':
        labels[r['key']] = r.get('label')
    if r.get('type') == 'result':
        out[labels.get(r['key'], r['key'])] = r.get('result')
path = f'runs/{label}/verdicts.json'
os.makedirs(f'runs/{label}', exist_ok=True)
json.dump(out, open(path, 'w'), indent=2, ensure_ascii=False)
print('saved', path, 'agents:', list(out))
s = out.get('score:' + label) or {}
r = out.get('refute:' + label) or {}
j = out.get('judge:' + label) or {}
run = out.get('run:' + label)
if run is not None: print('RUN:', str(run)[:200])
if s: 
    print('SCORE: obeyed', s.get('obeyed'), 'violated', s.get('violated'), 'n/a', s.get('notApplicable'), 'items', len(s.get('items', [])),
          '-> compliance', round(s['obeyed'] / max(1, s['obeyed'] + s['violated']), 3))
    print(' violated:', [x['id'] for x in s.get('items', []) if x['verdict'] == 'violated'])
    print(' notes:', s.get('notes', '')[:500])
if r:
    print('REFUTE: numbers', r.get('numbersReproduced'), '/', r.get('numbersTotal'), '; quotes', r.get('quotationsVerified'), '/', r.get('quotationsTotal'),
          '; fabrications', r.get('fabrications'), '; miscitations', r.get('miscitations'), '; identifiers', r.get('identifiersConfirmed'), '/', r.get('identifiersChecked'))
    print(' scope:', r.get('scope'))
    print(' collection:', {k: v for k, v in r.get('collection', {}).items() if k != 'checkerOutput'})
    print(' checker:', r.get('collection', {}).get('checkerOutput', '')[:200])
    print(' notes:', r.get('notes', '')[:500])
    print(' vectorUse:', {k: (v if k != 'notes' else v[:200]) for k, v in (r.get('vectorUse') or {}).items()})
    print(' reach:', r.get('reach'))
    print(' v7:', r.get('v7'))
if j:
    print('JUDGE: yes', j.get('yes'), [(x['id'], x['verdict']) for x in j.get('items', [])], 'ranking', j.get('ranking'), '|', j.get('rankingReason', '')[:300])
