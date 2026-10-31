#!/usr/bin/env python3
"""One-screen summary of one run's saved verdicts: python3 summ.py <label>"""
import json, sys
lab = sys.argv[1]
v = json.load(open(f'runs/{lab}/verdicts.json'))
s, r, j = v.get('score:' + lab) or {}, v.get('refute:' + lab) or {}, v.get('judge:' + lab) or {}
items = {x['id']: x['verdict'] for x in s.get('items', [])}
MAIN35 = [k for k in items if k[0] in 'CIETRSAP' or k in ('O1', 'O2', 'O3')]
ob = sum(items[k] == 'obeyed' for k in MAIN35); vi = sum(items[k] == 'violated' for k in MAIN35)
print(f'{lab}: 35-item compliance {ob}/{ob + vi} = {ob / max(1, ob + vi):.3f} (items scored {len(items)}; 35-set {len(MAIN35)})')
print('  violated:', [k for k, x in items.items() if x == 'violated'])
print('  V:', {k: items.get(k) for k in ('V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V8')}, ' O4:', items.get('O4'), " O2':", items.get("O2'"))
print('  refute: numbers', r.get('numbersReproduced'), '/', r.get('numbersTotal'), '; quotes', r.get('quotationsVerified'), '/', r.get('quotationsTotal'),
      '; fabrications', r.get('fabrications'), '; miscitations', r.get('miscitations'), '; identifiers', r.get('identifiersConfirmed'), '/', r.get('identifiersChecked'))
c = r.get('collection') or {}
print('  collection: opens', c.get('opens'), 'docs', c.get('documents'), 'excerpts', c.get('excerpts'), 'cited', c.get('citedInOverview'), 'present', c.get('citedAndPresent'))
vu = r.get('vectorUse') or {}
print('  vector ops:', [o.split(' (')[0] for o in vu.get('operations', [])], '; digests compared', vu.get('digestsCompared'))
re_ = r.get('reach') or {}
print('  reach: cited', re_.get('citedDocuments'), 'strict', re_.get('strictVectorReached'), 'quoted', re_.get('strictQuoted'), 'practical', re_.get('practicalVectorReached'))
print('   strict pairs:', (re_.get('strictPairs') or '')[:400])
v7 = r.get('v7') or {}
print('  V7:', v7.get('verdict'), '|', (v7.get('memoClaimedStrict') or '')[:300])
print('  judge: yes', j.get('yes'), [(x['id'], x['verdict']) for x in j.get('items', [])], 'ranking', j.get('ranking'))
