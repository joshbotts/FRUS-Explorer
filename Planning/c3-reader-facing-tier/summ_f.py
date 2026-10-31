#!/usr/bin/env python3
"""One-screen summary of one run's saved verdicts and checks: python3 summ_f.py <label>"""
import json, sys, pathlib

lab = sys.argv[1]
root = pathlib.Path(__file__).parent
v = json.load(open(root / 'runs' / lab / 'verdicts.json'))
s, r = v.get('score:' + lab) or {}, v.get('refute:' + lab) or {}
items = {x['id']: x['verdict'] for x in s.get('items', [])}
MAIN35 = [k for k in items if k[0] in 'CIETRSAP' or k in ('O1', 'O2', 'O3')]
ob = sum(items[k] == 'obeyed' for k in MAIN35); vi = sum(items[k] == 'violated' for k in MAIN35)
if items:
    print(f'{lab}: 35-item compliance {ob}/{ob + vi} = {ob / max(1, ob + vi):.3f} (items scored {len(items)}; 35-set {len(MAIN35)})')
    print('  violated:', [k for k, x in items.items() if x == 'violated'])
    print('  V:', {k: items.get(k) for k in ('V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V8')}, ' O4:', items.get('O4'), " O2':", items.get("O2'"))
    ev = next((x['evidence'] for x in s.get('items', []) if x['id'] == "O2'"), '')
    print("  O2' evidence:", ev[:300])
if r:
    print('  refute: numbers', r.get('numbersReproduced'), '/', r.get('numbersTotal'), '; quotes', r.get('quotationsVerified'), '/', r.get('quotationsTotal'),
          '; fabrications', r.get('fabrications'), '; miscitations', r.get('miscitations'), '; identifiers', r.get('identifiersConfirmed'), '/', r.get('identifiersChecked'))
    c = r.get('collection') or {}
    print('  collection: opens', c.get('opens'), 'docs', c.get('documents'), 'cited', c.get('citedInOverview'), 'present', c.get('citedAndPresent'))
    vu = r.get('vectorUse') or {}
    print('  vector ops:', [o.split(' (')[0][:40] for o in vu.get('operations', [])])
    re_ = r.get('reach') or {}
    print('  reach: cited', re_.get('citedDocuments'), 'strict', re_.get('strictVectorReached'), 'quoted', re_.get('strictQuoted'),
          'practical', re_.get('practicalVectorReached'), '| V7:', (r.get('v7') or {}).get('verdict'))
for k in ('zeros', 'houseFigures', 'deadTerms'):
    x = r.get(k) or (v.get('steps:' + lab) or {}).get(k)
    if x:
        print(f'  {k}:', {a: b for a, b in x.items() if a != 'list'}, '|', (x.get('list') or '')[:260])
run = v.get('run:' + lab)
if run is not None:
    print('  run final line:', str(run)[:160])
st = root / 'runs' / lab / 'checks' / 'style.json'
if st.exists():
    m = json.load(open(st))
    dc = m.get('documents_cited_list') or {}
    print('  style: median', m['median_sentence'], 'over40', m['share_over40'], 'part1', m['part1_words'], 'bottom', m['bottom_words'],
          'DocCited', dc.get('present'), 'unresolved', dc.get('unresolvedCount'), 'part2', m.get('part2'), 'I/1k', m.get('first_per_1k'), 'tool', m.get('tool'))
