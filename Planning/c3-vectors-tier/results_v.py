#!/usr/bin/env python3
"""C-3 vectors tier results: one row per run from runs/<label>/verdicts.json and tally.md, the C-3
figures for the same two cells beside them (a different question, so a reference and not a
control), and the five pre-registered readings of the design's §6.   python3 results_v.py"""
import json, re, pathlib

OUT = pathlib.Path('/Users/jbotts/frus-analysis/c3v')
C3 = pathlib.Path('/Users/jbotts/frus-analysis/c3')
keymap = json.load(open(OUT / 'keymap.json'))
USAGE = {'O-med+V (1)': 2, 'S-high+V (1)': 2, 'O-med+V (2)': 1, 'S-high+V (2)': 2}   # weekly points, instruments included (usage.md)
FABLE = {'O-med+V (1)': 3, 'S-high+V (1)': 3, 'O-med+V (2)': 3, 'S-high+V (2)': 4}
# C-3's same cells on the recognition question (C-3-Results-2026-10-26.md): compliance, run min, weekly pts, docs, reader
C3REF = {'O-med': [(1.000, 18.2, 1, 19, 5), (1.000, 19.4, 2, 26, 5)], 'S-high': [(1.000, 30.5, 2, 56, 5), (1.000, 32.4, 2, 56, 5)]}
FLOOR = 0.952
ORIG = {'C1','C2','I1','I2','I3','E1','E2','E3','T1','T2','T3','R1','R2','R3','R4','S1','S2','S3','S4','S5','A1','A2','A3','A4','A5','A6',
        'P1','P2','P3','P4','P5','P6','O1','O2','O3'}

rows = []
for cell, info in keymap.items():
    if cell == 'calv': continue
    lab = info['label']; p = OUT / 'runs' / lab / 'verdicts.json'
    if not p.exists():
        rows.append({'cell': cell, 'label': lab, 'status': 'not run'}); continue
    v = json.load(open(p)); s, r, j = v['score:' + lab], v['refute:' + lab], v['judge:' + lab]
    items = {x['id']: x['verdict'] for x in s['items']}
    orig = [items[i] for i in ORIG if i in items]
    comp35 = orig.count('obeyed') / max(1, orig.count('obeyed') + orig.count('violated'))
    vitems = {i: items.get(i) for i in ['V1','V2','V3','V4','V5','V6']}
    vscored = [x for x in vitems.values() if x in ('obeyed','violated')]
    compV = (vscored.count('obeyed') / len(vscored)) if vscored else None
    comp_all = s['obeyed'] / (s['obeyed'] + s['violated'])
    tally = (OUT / 'runs' / lab / 'tally.md').read_text()
    m = re.search(r'\| run:' + lab + r' \| \S+ \| [\d,]+ \| [\d,]+ \| [\d,]+ \| ([\d,]+) \| (\d+) \| \d+ \| ([\d.]+) min \|', tally)
    run_min, run_tools, run_out = float(m.group(3)), int(m.group(2)), int(m.group(1).replace(',', ''))
    cell_min = sum(float(x) for x in re.findall(r'\| ([\d.]+) min \|', tally))
    reach, vu, coll = r.get('reach', {}), r.get('vectorUse', {}), r.get('collection', {})
    quality = comp35 * (r['numbersReproduced'] / 5) * (r['quotationsVerified'] / max(1, r['quotationsTotal'])) * (j['yes'] / 5)
    if r['fabrications'] or not coll.get('opens'): quality = 0.0
    rows.append({'cell': cell, 'label': lab, 'comp35': comp35, 'comp_all': comp_all, 'compV': compV,
                 'violated': [i for i, x in items.items() if x == 'violated'], 'vitems': vitems,
                 'numbers': (r['numbersReproduced'], r['numbersTotal']), 'quotes': (r['quotationsVerified'], r['quotationsTotal']),
                 'fab': r['fabrications'], 'ids': (r['identifiersConfirmed'], r['identifiersChecked']), 'docs': coll.get('documents'),
                 'reader': j['yes'], 'ranking': j.get('ranking'), 'quality': quality,
                 'ops': len(vu.get('operations') or []), 'digests': vu.get('digestsCompared'),
                 'cited': reach.get('citedDocuments'), 'vreached': reach.get('vectorReached'), 'vquoted': reach.get('vectorReachedQuoted'),
                 'vpairs': (reach.get('vectorReachedPairs') or '')[:160],
                 'run_min': run_min, 'cell_min': cell_min, 'tools': run_tools, 'out': run_out,
                 'usage': USAGE.get(cell), 'fable': FABLE.get(cell)})

done = [x for x in rows if 'quality' in x]
print('| run | compliance (35 items) | all 40 | V1–V6 | violated | numbers | quotes | ids | docs | reader | quality | ops | vector-reached (quoted) | run min | cell min | tool calls | weekly pts |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
for x in done:
    vs = ''.join({'obeyed': '✓', 'violated': '✗', 'not_applicable': '–'}.get(x['vitems'][k] or '?', '?') for k in ['V1','V2','V3','V4','V5','V6'])
    print(f"| {x['cell']} | {x['comp35']:.3f} | {x['comp_all']:.3f} | {vs} | {','.join(x['violated']) or '—'} | {x['numbers'][0]}/{x['numbers'][1]} | "
          f"{x['quotes'][0]}/{x['quotes'][1]} | {x['ids'][0]}/{x['ids'][1]} | {x['docs']} | {x['reader']}/5 | {x['quality']:.3f} | {x['ops']} | "
          f"{x['vreached']} ({x['vquoted']}) of {x['cited']} | {x['run_min']} | {x['cell_min']:.1f} | {x['tools']} | {x['usage']} |")
for x in rows:
    if x.get('status'): print(f"| {x['cell']} | {x['label']} | {x['status']} |")
print()
print('C-3 reference, same cells, the recognition question (compliance, run min, weekly pts, docs, reader):')
for k, v in C3REF.items(): print(' ', k, v)
last = max((x for x in done if x['ranking']), key=lambda x: len(x['ranking']), default=None)
label_to_cell = {v['label']: k for k, v in keymap.items()}
if last: print('Final judge ranking:', ' > '.join(label_to_cell.get(l, l) for l in last['ranking']))
print()
print('READINGS (design §6):')
print(f"  Use: {sum(1 for x in done if x['ops'])} of {len(done)} runs ran a vector operation; operations per run {[x['ops'] for x in done]}; digests compared in {sum(1 for x in done if x['digests'])} of {len(done)}")
print(f"  Reach: vector-reached documents per run {[(x['cell'], x['vreached'], x['vquoted']) for x in done]} (count, of which quoted)")
for base in ['O-med', 'S-high']:
    xs = [x for x in done if x['cell'].startswith(base)]
    if not xs: continue
    ref = C3REF[base]
    print(f"  Appendix cost, {base}: compliance on the 35 items {[round(x['comp35'], 3) for x in xs]} against C-3's {[r[0] for r in ref]}; "
          f"run min {[x['run_min'] for x in xs]} against {[r[1] for r in ref]}; weekly pts {[x['usage'] for x in xs]} against {[r[2] for r in ref]}; "
          f"documents {[x['docs'] for x in xs]} against {[r[3] for r in ref]}")
print(f"  Reader: items {[(x['cell'], x['reader']) for x in done]}")
below = [x['cell'] for x in done if x['comp35'] < FLOOR]
print(f"  Compliance floor {FLOOR} on the 35 items: below it — {below or 'none'}")
