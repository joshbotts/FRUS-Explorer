#!/usr/bin/env python3
"""C-3 steering tier (R16): the table and the seven pre-registered readings (design §6), from each
run's saved verdicts and tally. Prints markdown; writes nothing.   python3 results_s.py"""
import json, re, pathlib

K = json.load(open('keymap.json'))
RUNS = [(name, v) for name, v in K.items() if name != 'cal']
RUNS.sort(key=lambda x: x[1]['order'])

def load(lab):
    p = pathlib.Path(f'runs/{lab}/verdicts.json')
    return json.load(open(p)) if p.exists() else None

def minutes(lab, who):
    t = pathlib.Path(f'runs/{lab}/tally.md')
    if not t.exists(): return None
    m = re.search(r'^\| ' + who + ':' + lab + r' \|.*\| ([0-9.]+) min \|$', t.read_text(), re.M)
    return float(m.group(1)) if m else None

rows = []
for name, k in RUNS:
    lab = k['label']; v = load(lab)
    if not v: continue
    s, r, j = v.get('score:' + lab) or {}, v.get('refute:' + lab) or {}, v.get('judge:' + lab) or {}
    it = {x['id']: x['verdict'] for x in s.get('items', [])}
    main = [x for x in it if x[0] in 'CIETRSAP' or x in ('O1', 'O2', 'O3')]
    ob = sum(it[x] == 'obeyed' for x in main); vi = [x for x in main if it[x] == 'violated']
    reach = r.get('reach') or {}; v7 = (r.get('v7') or {}).get('verdict')
    ops = [o.split(':')[0].split(' (')[0].strip() for o in (r.get('vectorUse') or {}).get('operations', [])]
    rows.append(dict(name=name, lab=lab, arm=k['arm'], cell=name.split(' ')[0], ob=ob, vi=vi, n35=ob + len(vi),
                     V={x: it.get(x) for x in ('V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V8')}, O4=it.get('O4'), O2p=it.get("O2'"),
                     num=f"{r.get('numbersReproduced')}/{r.get('numbersTotal')}", quo=f"{r.get('quotationsVerified')}/{r.get('quotationsTotal')}",
                     fab=r.get('fabrications'), ids=f"{r.get('identifiersConfirmed')}/{r.get('identifiersChecked')}",
                     docs=(r.get('collection') or {}).get('documents'), opens=(r.get('collection') or {}).get('opens'),
                     strict=reach.get('strictVectorReached'), strictq=reach.get('strictQuoted'), practical=reach.get('practicalVectorReached'),
                     strict_pairs=reach.get('strictPairs', ''), v7=v7, ops=ops, judge=j.get('yes'), ranking=j.get('ranking') or [],
                     run_min=minutes(lab, 'run')))

print('| # | run | label | arm | the 35 | lost of the 35 | V1–V6, V8 lost | O4 | O2\' | numbers | quotes | ids | docs | strict (quoted) | practical | V7 | judge | run min |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
for n, x in enumerate(rows, 1):
    vl = [k for k, v in x['V'].items() if v == 'violated']
    print(f"| {n} | {x['name']} | {x['lab']} | {x['arm']} | {x['ob']}/{x['n35']} | {', '.join(x['vi']) or '—'} | {', '.join(vl) or '—'} | "
          f"{x['O4']} | {x['O2p']} | {x['num']} | {x['quo']} | {x['ids']} | {x['docs']} | {x['strict']} ({x['strictq']}) | {x['practical']} | {x['v7']} | {x['judge']}/5 | {x['run_min']} |")

A = [x for x in rows if x['arm'] == 'A']; B = [x for x in rows if x['arm'] == 'B']; B0 = [x for x in rows if x['arm'] == 'B0']
final = max((x['ranking'] for x in rows), key=len)
pos = {lab: i for i, lab in enumerate(final)}
print('\nfinal ranking (the last judge, %d overviews): %s' % (len(final), ', '.join(final)))
print('\nREADINGS')
req = lambda ops: any('neighbour' in o for o in ops) and any('near-duplicate' in o for o in ops)
print('(1) use: B ran both required operations in %d of %d; operations by run:' % (sum(req(x['ops']) for x in B), len(B)))
for x in A + B: print('     ', x['arm'], x['lab'], x['ops'])
print('(2) V6: A', [x['V']['V6'] for x in A], ' B', [x['V']['V6'] for x in B])
print('(3) reach, strict: A %d (%s), B %d (%s); V7 in B %s; in A %s' % (
    sum(x['strict'] or 0 for x in A), [x['strict'] for x in A], sum(x['strict'] or 0 for x in B), [x['strict'] for x in B],
    [x['v7'] for x in B], [x['v7'] for x in A]))
la, lb = sum(len(x['vi']) for x in A), sum(len(x['vi']) for x in B)
print(f'(4) the cost: items of the 35 lost, A {la} {[x["vi"] for x in A]}, B {lb} {[x["vi"] for x in B]} -> {"holds" if lb <= la else "FAILS"}')
pairs = [('O-med', 1), ('S-high', 1), ('O-med', 2), ('S-high', 2)]
wins = []
for cell, n in pairs:
    a = next(x for x in A if x['name'] == f'{cell} A ({n})'); b = next(x for x in B if x['name'] == f'{cell} B ({n})')
    wins.append((cell, n, a['lab'], b['lab'], pos.get(b['lab'], 99) < pos.get(a['lab'], 99)))
print('(5) V8 in B', [x['V']['V8'] for x in B], '; in A', [x['V']['V8'] for x in A], '; judge B above A in %d of 4 pairs: %s' % (sum(w[-1] for w in wins), wins))
ra = [x['run_min'] for x in A]; rb = [x['run_min'] for x in B]
print('(6) price: run minutes A', ra, 'mean %.1f; B' % (sum(ra) / len(ra)), rb, 'mean %.1f' % (sum(rb) / len(rb)))
for x in B0:
    print('(7) run 9:', x['lab'], 'the 35', f"{x['ob']}/{x['n35']} = {x['ob'] / max(1, x['n35']):.3f}", 'lost', x['vi'], 'V', x['V'], 'ops', x['ops'])
print("\nO2' (the pass's baseline): A", [x['O2p'] for x in A], 'B', [x['O2p'] for x in B], 'B0', [x['O2p'] for x in B0])
print('O4: A', [x['O4'] for x in A], 'B', [x['O4'] for x in B], 'B0', [x['O4'] for x in B0])
