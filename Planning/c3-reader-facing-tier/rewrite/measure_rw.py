#!/usr/bin/env python3
"""The rewrite test's measures and its six readings (READINGS.md), from runs/w*/, the tier's scripts and
results.json. Prints markdown; writes each rewrite's checks/.   python3 measure_rw.py"""
import json, statistics, sys, pathlib
root = pathlib.Path(__file__).parent
sys.path.insert(0, str(root.parent))
import o2p_check, style_measure

K = json.load(open(root / 'keymap.json')); R = json.load(open(root / 'results.json'))
rows = {}
for lab, k in K.items():
    d = root / 'runs' / lab
    if not (d / 'overview.md').exists():
        continue
    st = style_measure.run(d, d / 'checks')
    o = o2p_check.check(d, d / 'trace.md', d / 'checks')
    j = (R.get(k['pair']) or {}).get('judge') or {}
    one = j.get(k['slot']) or {}
    rows[lab] = dict(k, median=st['median_sentence'], over40=st['share_over40'], lens=st['sentence_lengths'], part1=st['part1_words'],
                     docc=(st['documents_cited_list'] or {}).get('present'), unres=(st['documents_cited_list'] or {}).get('unresolvedCount'),
                     lists=(st['part2'] or {}).get('lists'), first=st['first_per_1k'], tool=st['tool'], words=st['words'],
                     flagged=o['counts']['weak'] + o['counts']['untraced'], numbers=o['mentions'],
                     J=sum(i['verdict'] == 'yes' for i in one.get('items', [])), cit=(one.get('citations') or {}).get('verdict'),
                     preferred=(j.get('preference') == k['slot']))
print('| pair | source | wording | label | median sentence | over 40 | part 1 | Documents cited (unresolved) | part 2 lists | numbers (flagged) | J1–J5 | citations | preferred |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|---|')
for lab, r in sorted(rows.items(), key=lambda x: (x[1]['pair'], x[1]['wording'])):
    print(f"| {r['pair']} | {r['source']} | {r['wording']} | {lab} | {r['median']} | {r['over40']} | {r['part1']} | {r['docc']} ({r['unres']}) | {r['lists']} | {r['numbers']} ({r['flagged']}) | {r['J']} | {r['cit']} | {r['preferred']} |")
new = [r for r in rows.values() if r['wording'] == 'new']; old = [r for r in rows.values() if r['wording'] == 'old']
ln = [n for r in new for n in r['lens']]; lo = [n for r in old for n in r['lens']]
med = lambda xs: statistics.median(xs) if xs else None; sh = lambda xs: round(sum(n > 40 for n in xs) / max(1, len(xs)), 3)
print(f"\nPAIRS judged: {len(R)}; rewrites measured: {len(rows)}")
print(f"(1) sentences: R1 pooled median {med(ln)}, over 40 {sh(ln)}; as it stands {med(lo)}, {sh(lo)} -> {'holds' if med(ln) is not None and med(ln) <= 22 and sh(ln) <= 0.10 else 'FAILS'}")
p1 = [r['part1'] for r in new]
print(f"(2) part 1: R1 {p1}; as it stands {[r['part1'] for r in old]} -> {'holds' if sum((p or 999) <= 200 for p in p1) >= 6 else 'FAILS'}")
fn, fo = sum(r['flagged'] for r in new), sum(r['flagged'] for r in old)
print(f"(3) flagged numbers: R1 {fn} of {sum(r['numbers'] for r in new)}; as it stands {fo} of {sum(r['numbers'] for r in old)} -> {'holds' if fn < fo else 'FAILS'}")
jn, jo = sum(r['J'] for r in new), sum(r['J'] for r in old)
print(f"(4) J1-J5: R1 {jn}; as it stands {jo} -> {'holds' if jn >= jo else 'FAILS'}")
ok5 = [(r['pair'], r['cit'], r['docc'], r['unres']) for r in new]
print(f"(5) one form and a resolving list: {ok5} -> {'holds' if all(c == 'yes' and d and u == 0 for _, c, d, u in ok5) and len(ok5) == 8 else 'FAILS'}")
pref = sum(r['preferred'] for r in new)
print(f"(6) the judge prefers R1 in {pref} of {len(new)} -> {'holds' if pref >= 6 else 'FAILS'}")
print(f"reported: I per 1,000 words R1 {[r['first'] for r in new]} vs {[r['first'] for r in old]}; tool words R1 {sum(r['tool'] for r in new)} vs {sum(r['tool'] for r in old)}; words R1 {sum(r['words'] for r in new)} vs {sum(r['words'] for r in old)}")
