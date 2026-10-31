#!/usr/bin/env python3
"""C-3 reader-facing tier: the tables and the pre-registered readings (design §8), from each run's saved
verdicts, its checks/ and its tally, and the block judges. Prints markdown; writes nothing.
    python3 results_f.py"""
import json, re, statistics, pathlib

root = pathlib.Path(__file__).parent
K = json.load(open(root / 'keymap.json'))
RUNS = sorted([(n, v) for n, v in K.items() if 'label' in v and v.get('arm')], key=lambda x: x[1]['order'])
JUDGES = {v['block']: v['slots'] for n, v in K.items() if n.startswith('judge')}


def load(p):
    p = root / p
    return json.load(open(p)) if p.exists() else None


def minutes(lab):
    t = root / 'runs' / lab / 'tally.md'
    if not t.exists():
        return None
    m = re.search(r'^\| run:' + lab + r' \|.*\| ([0-9.]+) min \|$', t.read_text(), re.M)
    return float(m.group(1)) if m else None


rows = []
for name, k in RUNS:
    lab = k['label']
    v = load(f'runs/{lab}/verdicts.json') or {}
    s, r = v.get('score:' + lab) or {}, v.get('refute:' + lab) or {}
    it = {x['id']: x['verdict'] for x in s.get('items', [])}
    main = [x for x in it if x[0] in 'CIETRSAP' or x in ('O1', 'O2', 'O3')]
    st = load(f'runs/{lab}/checks/style.json') or {}
    mc = load(f'runs/{lab}/checks/match_check.json') or {}
    dc = st.get('documents_cited_list') or {}
    pre = [p for p in mc.get('prefixes', []) if p.get('firstLogLine')]
    rows.append(dict(name=name, lab=lab, arm=k['arm'], block=k['block'], cell=name.split(' ')[0], scored=bool(it),
                     ob=sum(it[x] == 'obeyed' for x in main), vi=[x for x in main if it[x] == 'violated'],
                     V={x: it.get(x) for x in ('V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V8')}, O4=it.get('O4'), O2p=it.get("O2'"), O2=it.get('O2'),
                     T1=it.get('T1'), R3=it.get('R3'), P6=it.get('P6'),
                     num=f"{r.get('numbersReproduced')}/{r.get('numbersTotal')}", quo=f"{r.get('quotationsVerified')}/{r.get('quotationsTotal')}",
                     fab=r.get('fabrications'), ids=f"{r.get('identifiersConfirmed')}/{r.get('identifiersChecked')}",
                     docs=(r.get('collection') or {}).get('documents'), strict=(r.get('reach') or {}).get('strictVectorReached'),
                     v7=(r.get('v7') or {}).get('verdict'), zeros=r.get('zeros') or {}, figs=r.get('houseFigures') or {}, dead=r.get('deadTerms') or {},
                     prefixes=len(pre), prefixes_looked=sum(1 for p in pre if p.get('vocabLookupBefore')),
                     median=st.get('median_sentence'), over40=st.get('share_over40'), part1=st.get('part1_words'), bottom=st.get('bottom_words'),
                     lens=st.get('sentence_lengths') or [], docc=dc.get('present'), unres=dc.get('unresolvedCount'),
                     lists=(st.get('part2') or {}).get('lists'), first=st.get('first_per_1k'), tool=st.get('tool'), words=st.get('words'),
                     run_min=minutes(lab)))

print("| # | run | label | arm | the 35 | lost of the 35 | V lost | O4 | O2' | O2 | numbers | quotes | ids | docs | strict | V7 | run min |")
print('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
for n, x in enumerate(rows, 1):
    vl = [k for k, v in x['V'].items() if v == 'violated']
    print(f"| {n} | {x['name']} | {x['lab']} | {x['arm']} | {x['ob']}/{x['ob'] + len(x['vi'])} | {', '.join(x['vi']) or '—'} | {', '.join(vl) or '—'} | "
          f"{x['O4']} | {x['O2p']} | {x['O2']} | {x['num']} | {x['quo']} | {x['ids']} | {x['docs']} | {x['strict']} | {x['v7']} | {x['run_min']} |")
print('\n| run | label | arm | median sentence | over 40 | part 1 words | bottom line words | Documents cited | unresolved | part 2 lists | I per 1,000 | tool words |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|')
for x in rows:
    print(f"| {x['name']} | {x['lab']} | {x['arm']} | {x['median']} | {x['over40']} | {x['part1']} | {x['bottom']} | {x['docc']} | {x['unres']} | {x['lists']} | {x['first']} | {x['tool']} |")
print('\n| run | label | arm | T1 | prefixes (looked up first) | dead terms (reported from, noticed) | R3 | zeros (relaxed, other, nothing) | P6 | house figures (re-derived, attributed, own) |')
print('|---|---|---|---|---|---|---|---|---|---|')
for x in rows:
    z, f, d = x['zeros'], x['figs'], x['dead']
    print(f"| {x['name']} | {x['lab']} | {x['arm']} | {x['T1']} | {x['prefixes']} ({x['prefixes_looked']}) | {d.get('listed', '-')} - {d.get('notATerm', 0)} not terms "
          f"({d.get('reportedFrom', '-')}, {d.get('noticed', '-')}) | {x['R3']} | {z.get('total', '-')} ({z.get('relaxed', '-')}, {z.get('other', '-')}, {z.get('nothing', '-')}) | "
          f"{x['P6']} | {f.get('occurrences', '-')} - {f.get('notOne', 0)} not ({f.get('rederived', '-')}, {f.get('attributed', '-')}, {f.get('own', '-')}) |")

by = lambda arm: [x for x in rows if x['arm'] == arm and x['scored']]
A, W, KK = by('A'), by('W'), by('K')
lab_arm = {x['lab']: x['arm'] for x in rows}
print('\nTHE JUDGES')
places = {}
for b, slots in sorted(JUDGES.items()):
    j = (load(f'judges/judge{b}.json') or {}).get(f'judge:{b}') or {}
    rk = [slots[s] for s in j.get('ranking', [])]
    places[b] = {lab_arm[l]: i for i, l in enumerate(rk)}
    yes = {slots[o['slot']]: sum(i['verdict'] == 'yes' for i in o['items']) for o in j.get('overviews', [])}
    cit = {slots[o['slot']]: o['citations']['verdict'] for o in j.get('overviews', [])}
    for x in rows:
        if x['lab'] in yes:
            x['J'] = yes[x['lab']]; x['cit'] = cit[x['lab']]
    print(f"block {b}: ranking {[(l, lab_arm[l]) for l in rk]}; J yes {yes}; citations {cit} | {(j.get('reason') or '')[:300]}")


def guard(T):
    la, lt = sum(len(x['vi']) for x in A), sum(len(x['vi']) for x in T)
    return lt <= la + 1 and all(len(x['vi']) < 2 for x in T), la, lt


print('\nREADINGS — W against A')
wa = [b for b, p in places.items() if 'W' in p and 'A' in p and p['W'] < p['A']]
jw, ja = sum(x.get('J', 0) for x in W), sum(x.get('J', 0) for x in A)
print(f"(1) reader: W above A in {len(wa)} of {len(places)} blocks {sorted(wa)}; J1-J5 summed W {jw} A {ja} -> {'holds' if len(wa) >= 3 and jw >= ja else 'FAILS'}")
form = [(x['lab'], x.get('cit'), x['docc'], x['unres'], x['lists']) for x in W]
ok2 = all(c == 'yes' and d and u == 0 and (l or 0) >= 2 for _, c, d, u, l in form)
print(f"(2) form: {form} -> {'holds' if ok2 and len(W) == 4 else 'FAILS'}")
lw = [n for x in W for n in x['lens']]; la_ = [n for x in A for n in x['lens']]
med = statistics.median(lw) if lw else None; sh = round(sum(n > 40 for n in lw) / max(1, len(lw)), 3)
p1 = [x['part1'] for x in W]
print(f"(3) length: W pooled median {med}, over 40 {sh}; part 1 {p1}; A pooled median {statistics.median(la_) if la_ else None}, "
      f"over 40 {round(sum(n > 40 for n in la_) / max(1, len(la_)), 3)} -> {'holds' if med is not None and med <= 22 and sh <= 0.10 and sum((p or 999) <= 200 for p in p1) >= 3 else 'misses'}")
print(f"(4) numbers: O2' W {[x['O2p'] for x in W]} A {[x['O2p'] for x in A]}; O2 W {[x['O2'] for x in W]} (untraced counts from the scorers' evidence, by hand)")
g, la, lt = guard(W)
print(f"(5) cost: lost of the 35, A {la} {[x['vi'] for x in A]}, W {lt} {[x['vi'] for x in W]} -> {'holds' if g else 'FAILS'}")
print(f"(6) vocabulary: V8 W {[x['V']['V8'] for x in W]} A {[x['V']['V8'] for x in A]} K {[x['V']['V8'] for x in KK]}")
mean = lambda xs: round(sum(xs) / len(xs), 1) if xs and all(v is not None for v in xs) else None
print(f"(7) price: run minutes W {[x['run_min'] for x in W]} mean {mean([x['run_min'] for x in W])}; A {[x['run_min'] for x in A]} mean {mean([x['run_min'] for x in A])}")
print(f"(8) voice: I per 1,000 words W {[x['first'] for x in W]} A {[x['first'] for x in A]}")
print('\nREADINGS — K against A')
print(f"(9) stems: T1 K {[x['T1'] for x in KK]} A {[x['T1'] for x in A]}; prefixes looked up first K {[(x['prefixes_looked'], x['prefixes']) for x in KK]} A {[(x['prefixes_looked'], x['prefixes']) for x in A]}")
print(f"(10) zeros: K {[(x['zeros'].get('total'), x['zeros'].get('relaxed')) for x in KK]} A {[(x['zeros'].get('total'), x['zeros'].get('relaxed')) for x in A]}; R3 K {[x['R3'] for x in KK]}")
print(f"(11) figures: K own {[x['figs'].get('own') for x in KK]} of {[x['figs'].get('occurrences') for x in KK]}; A own {[x['figs'].get('own') for x in A]}; P6 K {[x['P6'] for x in KK]}")
g, la, lt = guard(KK)
print(f"(12) cost: lost of the 35, A {la}, K {lt} {[x['vi'] for x in KK]} -> {'holds' if g else 'FAILS'}")
print(f"(13) price: run minutes K {[x['run_min'] for x in KK]} mean {mean([x['run_min'] for x in KK])}")
