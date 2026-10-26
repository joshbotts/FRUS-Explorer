#!/usr/bin/env python3
"""C-3 results: one row per cell from runs/<label>/verdicts.json and runs/<label>/tally.md, the
quality score of design §4, and the three readings of design §5.   python3 results.py

Usage deltas are typed in below from usage.md (the meter prints whole percentage points, so each
delta is ±1 coarse); the instruments' own cost, measured on the Cuba kit in step 0, was about one
point, and the value reading uses the gross delta, instruments included, as §8 item 3a says."""
import json, re, pathlib

OUT = pathlib.Path('/Users/jbotts/frus-analysis/c3')
keymap = json.load(open(OUT / 'keymap.json'))
# weekly all-models percentage points per cell, instruments included (usage.md)
USAGE = {'F-max': 3, 'S-med': 2, 'O-high': 2, 'S-high': 2, 'O-med': 1, 'F-high': 3, 'O-max': 2, 'S-max': 4, 'F-med': 3,
         'O-med (2)': 2, 'O-max (2)': 3, 'S-high (2)': 2}
FABLE = {'F-max': 6, 'S-med': 3, 'O-high': 3, 'S-high': 3, 'O-med': 2, 'F-high': 5, 'O-max': 4, 'S-max': 4, 'F-med': 6,
         'O-med (2)': 4, 'O-max (2)': 3, 'S-high (2)': 5}
COMPLIANCE_FLOOR = 0.952   # C-0c's block arm, design §5

rows = []
last_ranking = None
for cell, info in keymap.items():
    if cell == 'cal':
        continue
    lab = info['label']
    p = OUT / 'runs' / lab / 'verdicts.json'
    if not p.exists():
        rows.append({'cell': cell, 'label': lab, 'status': 'not run'})
        continue
    v = json.load(open(p))
    s, r, j = v.get('score:' + lab) or {}, v.get('refute:' + lab) or {}, v.get('judge:' + lab) or {}
    tally = (OUT / 'runs' / lab / 'tally.md').read_text() if (OUT / 'runs' / lab / 'tally.md').exists() else ''
    m = re.search(r'\| run:' + lab + r' \| \S+ \| ([\d,]+) \| ([\d,]+) \| ([\d,]+) \| ([\d,]+) \| (\d+) \| \d+ \| ([\d.]+) min \|', tally)
    run_min = float(m.group(6)) if m else None
    run_tools = int(m.group(5)) if m else None
    run_out = int(m.group(4).replace(',', '')) if m else None
    cell_min = sum(float(x) for x in re.findall(r'\| ([\d.]+) min \|', tally)) if tally else None
    compliance = s['obeyed'] / (s['obeyed'] + s['violated']) if s else None
    numbers = (r.get('numbersReproduced', 0), r.get('numbersTotal', 5)) if r else (None, None)
    quotes = (r.get('quotationsVerified', 0), r.get('quotationsTotal', 0)) if r else (None, None)
    fab = r.get('fabrications') if r else None
    opens = (r.get('collection') or {}).get('opens') if r else None
    reader = j.get('yes') if j else None
    quality = None
    if compliance is not None and r and j:
        qf = quotes[0] / quotes[1] if quotes[1] else 0
        quality = compliance * (numbers[0] / 5) * qf * (reader / 5)
        if fab or not opens:
            quality = 0.0
    rows.append({'cell': cell, 'label': lab, 'model': info['model'], 'effort': info['effort'],
                 'compliance': compliance, 'violated': [x['id'] for x in s.get('items', []) if x['verdict'] == 'violated'],
                 'numbers': numbers, 'quotes': quotes, 'fabrications': fab, 'miscitations': r.get('miscitations'),
                 'identifiers': (r.get('identifiersConfirmed'), r.get('identifiersChecked')),
                 'documents': (r.get('collection') or {}).get('documents'), 'opens': opens,
                 'reader': reader, 'reader_no': [x['id'] for x in j.get('items', []) if x['verdict'] == 'no'],
                 'quality': quality, 'run_min': run_min, 'cell_min': cell_min, 'run_tools': run_tools, 'run_output_tokens': run_out,
                 'usage': USAGE.get(cell), 'fable': FABLE.get(cell), 'ranking': j.get('ranking')})
    if j.get('ranking') and (last_ranking is None or len(j['ranking']) >= len(last_ranking)):
        last_ranking = j['ranking']

label_to_cell = {v['label']: k for k, v in keymap.items()}
rank_pos_global = {label_to_cell.get(l, l).split(' (')[0]: i for i, l in enumerate(last_ranking or []) if label_to_cell.get(l, l).split(' (')[0] not in {label_to_cell.get(m, m).split(' (')[0] for m in (last_ranking or [])[:i]}}
done = [x for x in rows if 'quality' in x]
print('| cell | model | effort | compliance | violated | numbers | quotes | fab. | ids | docs | reader | quality | run min | cell min | tool calls | weekly pts | Fable pts |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
for x in sorted(done, key=lambda x: -(x['quality'] or 0)):
    print(f"| {x['cell']} | {x['model']} | {x['effort']} | {x['compliance']:.3f} | {','.join(x['violated']) or '—'} | "
          f"{x['numbers'][0]}/{x['numbers'][1]} | {x['quotes'][0]}/{x['quotes'][1]} | {x['fabrications']} | "
          f"{x['identifiers'][0]}/{x['identifiers'][1]} | {x['documents']} | {x['reader']}/5{(' (' + ','.join(x['reader_no']) + ')') if x['reader_no'] else ''} | "
          f"{x['quality']:.3f} | {x['run_min']} | {x['cell_min']:.1f} | {x['run_tools']} | {x['usage']} | {x['fable']} |")
for x in rows:
    if x.get('status'):
        print(f"| {x['cell']} | {x['label']} | {x['status']} |")

print()
if last_ranking:
    print('Final judge ranking (best to worst):', ' > '.join(f"{label_to_cell.get(l, l)}" for l in last_ranking))
    print('  (for the earlier judges\' rankings see each cell\'s verdicts.json)')

# pool a replicated cell's runs: the readings are per CELL, each figure the mean of its runs
pooled = {}
for x in done:
    base = x['cell'].split(' (')[0]
    pooled.setdefault(base, []).append(x)
def mean(xs): return sum(xs) / len(xs)
cells = []
for base, xs in pooled.items():
    cells.append({'cell': base + (f' (n={len(xs)})' if len(xs) > 1 else ''), 'n': len(xs),
                  'compliance': mean([x['compliance'] for x in xs]), 'min_compliance': min(x['compliance'] for x in xs),
                  'fabrications': sum(x['fabrications'] or 0 for x in xs), 'miscitations': sum(x['miscitations'] or 0 for x in xs),
                  'numbers': (sum(x['numbers'][0] for x in xs), sum(x['numbers'][1] for x in xs)),
                  'quotes': (sum(x['quotes'][0] for x in xs), sum(x['quotes'][1] for x in xs)),
                  'quality': mean([x['quality'] for x in xs]), 'run_min': mean([x['run_min'] for x in xs]),
                  'usage': mean([x['usage'] for x in xs]) if all(x['usage'] for x in xs) else None,
                  'judge_rank': rank_pos_global.get(base, 99)})
print()
print('Per cell, runs pooled (mean of n runs):')
for c in sorted(cells, key=lambda c: -c['quality']):
    print(f"  {c['cell']}: compliance {c['compliance']:.3f} (min {c['min_compliance']:.3f}), quality {c['quality']:.3f}, run {c['run_min']:.1f} min, weekly pts {c['usage']}, fabrications {c['fabrications']}")
done = cells
eligible = [x for x in done if x['min_compliance'] >= COMPLIANCE_FLOOR and not x['fabrications']]
below = [x['cell'] for x in done if x['min_compliance'] < COMPLIANCE_FLOOR]
print()
print(f'Compliance floor {COMPLIANCE_FLOOR}: below it — {below or "none"} (a fast cell below the floor is a warning, not a recommendation)')
if eligible:
    fastest = min(eligible, key=lambda x: x['run_min'] or 1e9)
    print(f"FASTEST (lowest run wall clock among cells at or above the floor with zero fabrications): {fastest['cell']} at {fastest['run_min']} min")
with_usage = [x for x in done if x['usage']]
if with_usage:
    value = max(with_usage, key=lambda x: x['quality'] / x['usage'])
    print(f"BEST VALUE (quality per weekly point, instruments included): {value['cell']} at {value['quality'] / value['usage']:.3f} per point "
          f"(quality {value['quality']:.3f} over {value['usage']} points)")
    print('  all:', ', '.join(f"{x['cell']} {x['quality'] / x['usage']:.3f}" for x in sorted(with_usage, key=lambda x: -x['quality'] / x['usage'])))
if done:
    best = sorted(done, key=lambda x: (-round(x['quality'], 6), (x['miscitations'] or 0) + (x['fabrications'] or 0) + (x['numbers'][1] - x['numbers'][0]) + (x['quotes'][1] - x['quotes'][0]), x['judge_rank']))
    print(f"HIGHEST QUALITY (quality score, ties by the refuter's error count, then the judge's ranking): {best[0]['cell']} ({best[0]['quality']:.3f})")
    print('  order:', ' > '.join(f"{x['cell']} {x['quality']:.3f}" for x in best))
