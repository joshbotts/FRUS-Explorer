#!/usr/bin/env python3
"""Calibrate o2p_check.py on known answers (design §5.3 and §6 step 0), at no agent cost: every
number R16's scorers named as having no trace row must come back WEAK or UNTRACED. For the pilot's
rewrites, only the misses its scorer called "no row" are held to that rule: its O2' also failed a
number whose row cites the wrong memo line, which R16's rubric ("has a row") does not.
    python3 o2p_calibrate.py <scratch dir>"""
import json, re, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import o2p_check as oc

REC = pathlib.Path('/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/elastic-kowalevski-07a5ac/Planning')
SCR = pathlib.Path(sys.argv[1])
MARK = re.compile(r'(?i)without (?:a )?(?:trace[- ])?row|with no trace(?:-table)? row|no row in the memo|'
                  r'(?:have|has) no trace row|no trace-table row|without one|have no row')

def norm(t):
    t = t.lower().replace('*', '').replace('“', '"').replace('”', '"').replace('’', "'")
    return re.sub(r'\s+', ' ', re.sub(r'["\'`]', '', t)).strip()

def phrases_after_marker(ev):
    m = MARK.search(ev)
    tail = ev[m.end():] if m else ''
    return [p for p in re.findall(r'[“"]([^”"]{3,120})[”"]', tail)]

def recall(label, run_dir, phrases, trace=None):
    p = oc.check(run_dir, trace, SCR / ('o2p_' + label))
    flagged = [r for r in p['list'] if r['class'] != 'traced']
    traced = [r for r in p['list'] if r['class'] == 'traced']
    got, missed, unloc = [], [], []
    for ph in phrases:
        nums = [t for t, *_ in oc.mentions_of(ph)]
        if not nums:
            continue                                            # an ordinal list marker or no number
        n = norm(oc.clean_overview(ph))
        same = lambda r: n in norm(r['sentence']) and any(norm(x) == norm(r['text']) or norm(x) in norm(r['text']) for x in nums)
        if [r for r in flagged if same(r)]:
            got.append(ph)
            continue
        bad = [r for r in traced if same(r)]
        (missed if bad else unloc).append(ph + ((' <- row: ' + bad[0]['row'][:80]) if bad else ''))
    print(f"{label}: {p['mentions']} numbers, flagged {len(flagged)}; named misses {len(got) + len(missed) + len(unloc)}: "
          f"recalled {len(got)}, classed traced {len(missed)} {missed}, not located {len(unloc)} {unloc}")
    return len(flagged), len(got), missed, unloc

tot = [0, 0, 0, 0]
for k in range(1, 10):
    lab = f's{k}'
    v = json.load(open(REC / 'c3-steering-tier' / 'runs' / lab / 'verdicts.json'))
    ev = next(x['evidence'] for x in v['score:' + lab]['items'] if x['id'] == "O2'")
    f, g, m, u = recall(lab, REC / 'c3-steering-tier' / 'runs' / lab, phrases_after_marker(ev))
    tot[0] += f; tot[1] += g; tot[2] += len(m); tot[3] += len(u)
print('R16 total: flagged', tot[0], 'recalled', tot[1], 'classed traced', tot[2], 'not located', tot[3])

pilot = json.load(open(REC / 'reader-facing-style' / 'pilot' / 'results.json'))
pins = {p['pair']: p for p in json.load(open(REC / 'reader-facing-style' / 'pilot' / 'pins.json'))['pairs']}
for pair, res in sorted(pilot.items()):
    for slot in 'AB':
        o = res['o2p'][slot]
        lab = pins[pair][slot]['label']
        items = re.split(r'\s(?=\d+\.\s)', ' ' + o['misses'])
        phrases = []
        for it in items:
            if re.search(r'(?i)\bno row\b', it):
                q = re.findall(r"'([^']{3,120})'", it)
                phrases += q[:1]
        run = REC / 'reader-facing-style' / 'pilot' / 'runs' / lab
        recall(f'{pair}-{lab}', run, phrases, run / 'trace.md')
