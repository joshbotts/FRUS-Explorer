#!/usr/bin/env python3
"""The pilot's mechanical measures and its six pre-registered readings (style review §5), from the
rewrites in runs/w*/overview.md, keymap.json and the saved instrument results (results.json, one
entry a pair: {"o2p": ..., "judge": ...}).   python3 pilot_measure.py"""
import json, re, statistics, pathlib

K = json.load(open('keymap.json'))
R = json.load(open('results.json')) if pathlib.Path('results.json').exists() else {}
CIT = re.compile(r'\((?:[^()]|\([^()]*\))*?(?:Foreign Relations|history\.state\.gov|Document \d)(?:[^()]|\([^()]*\))*\)')
TOOL = r'\b(the index|indexed|hits?|returned|matched|full-text|TEI|corpus|quer(?:y|ies)|stems?|vectors?|Hamming)\b'
NUMW = r'\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|twenty|thirty|forty|fifty|hundred|hundreds|thousand|thousands|dozen|half|third|quarter|twice|double)\b'

def measure(path):
    ov = path.read_text()
    blocks, cur = [], []
    for line in ov.splitlines():
        s = line.strip(); item = re.match(r'^([-*]|\d+\.)\s', s)
        if not s or s.startswith(('#', '|', '>')) or item:
            if cur: blocks.append(' '.join(cur)); cur = []
            if item: blocks.append(re.sub(r'^([-*]|\d+\.)\s+', '', s))
            continue
        cur.append(s)
    if cur: blocks.append(' '.join(cur))
    lens = []
    for b in blocks:
        b = re.sub(r'https?://\S+', '', CIT.sub('', b))
        lens += [n for n in (len(x.split()) for x in re.split(r'(?<=[.!?])["”’]?\s+(?=[A-Z“"])', b)) if n >= 3]
    bl = re.search(r'##\s+The bottom line\s*\n(.*?)(?=\n##\s)', ov, re.S | re.I)
    bl = bl.group(1) if bl else ''
    p1 = re.search(r'\*\*1\.(.*?)(?=\*\*2\.)', bl, re.S)
    body = re.sub(r'https?://\S+', '', ov)
    return dict(words=len(ov.split()), median_sentence=statistics.median(lens) if lens else None,
                over40=sum(x > 40 for x in lens), sentences=len(lens),
                share_over40=round(sum(x > 40 for x in lens) / max(1, len(lens)), 3),
                bottom_words=len(bl.split()), part1_words=len(p1.group(1).split()) if p1 else None,
                documents_cited=bool(re.search(r'^##\s+Documents cited', ov, re.M | re.I)),
                full_citations=len(re.findall(r'Foreign Relations of the United States', ov)),
                urls=len(re.findall(r'history\.state\.gov/historicaldocuments/', ov)),
                numerals=len([n for n in re.findall(r'(?<![\w/])\d[\d,]*(?:\.\d+)?', body) if not re.fullmatch(r'1[89]\d\d|20[0-3]\d', n)]),
                numwords=len(re.findall(NUMW, body, re.I)), tool=len(re.findall(TOOL, body, re.I)), first=len(re.findall(r'\bI\b', body)))

rows = {}
for lab, k in sorted(K.items()):
    p = pathlib.Path(f'runs/{lab}/overview.md')
    if p.exists(): rows[lab] = {**k, **measure(p)}
print('| label | pair | source | wording | words | median sentence | over 40 | part 1 words | bottom words | Documents cited | full cites | urls | numerals | number-words | tool words | I |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
for lab, r in sorted(rows.items(), key=lambda x: (x[1]['pair'], x[1]['wording'])):
    print(f"| {lab} | {r['pair']} | {r['source']} | {r['wording']} | {r['words']} | {r['median_sentence']} | {r['over40']} of {r['sentences']} | {r['part1_words']} | {r['bottom_words']} | {r['documents_cited']} | {r['full_citations']} | {r['urls']} | {r['numerals']} | {r['numwords']} | {r['tool']} | {r['first']} |")

if R:
    print('\nINSTRUMENTS')
    new = [r for r in rows.values() if r['wording'] == 'new']; old = [r for r in rows.values() if r['wording'] == 'old']
    def slot_of(lab): return K[lab]['slot']
    o2p = {}; jd = {}; pref = {}; cites = {}
    for pair, res in R.items():
        o, j = res.get('o2p') or {}, res.get('judge') or {}
        for s in 'AB':
            lab = (o.get(s) or {}).get('label') or (j.get(s) or {}).get('label')
            lab = next(l for l, k in K.items() if k['pair'] == pair and k['slot'] == s)
            o2p[lab] = (o.get(s) or {}).get('verdict'), (o.get(s) or {}).get('numbers'), (o.get(s) or {}).get('traced')
            items = {x['id']: x['verdict'] for x in (j.get(s) or {}).get('items', [])}
            jd[lab] = sum(v == 'yes' for v in items.values()), items
            cites[lab] = ((j.get(s) or {}).get('citations') or {}).get('verdict')
        winner = j.get('preference')
        if winner:
            wl = next(l for l, k in K.items() if k['pair'] == pair and k['slot'] == winner)
            pref[pair] = K[wl]['wording']
        print(pair, 'O2p', {l: o2p[l] for l in o2p if K[l]['pair'] == pair}, '| judge', {l: jd[l][0] for l in jd if K[l]['pair'] == pair},
              '| citations', {l: cites[l] for l in cites if K[l]['pair'] == pair}, '| preferred:', pref.get(pair), '|', (j.get('reason') or '')[:240])
    print('\nREADINGS (R1, the new wording, against the section as it stands)')
    ms = [r['median_sentence'] for r in new]; sh = [r['share_over40'] for r in new]
    print('(1) median sentence <= 22 and at most one in ten over 40:', [(r['source'], r['median_sentence'], r['share_over40']) for r in new], '; old:', [(r['source'], r['median_sentence'], r['share_over40']) for r in old])
    print('(2) part 1 <= 200 words:', [(r['source'], r['part1_words']) for r in new], '; old:', [(r['source'], r['part1_words']) for r in old])
    print('(3) O2p holds in >= 3 of 4: new', [o2p.get(l) for l, k in K.items() if k['wording'] == 'new'], '; old', [o2p.get(l) for l, k in K.items() if k['wording'] == 'old'])
    print('(4) J1-J5 no worse: new', [jd.get(l, (None,))[0] for l, k in K.items() if k['wording'] == 'new'], '; old', [jd.get(l, (None,))[0] for l, k in K.items() if k['wording'] == 'old'])
    print('(5) citation form consistent in 4 of 4: new', [cites.get(l) for l, k in K.items() if k['wording'] == 'new'], '; old', [cites.get(l) for l, k in K.items() if k['wording'] == 'old'])
    print('(6) the judge prefers R1 in >= 3 of 4:', pref)
