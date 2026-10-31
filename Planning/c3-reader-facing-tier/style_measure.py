#!/usr/bin/env python3
"""The writing, measured (Planning/C-3-Reader-Facing-Tier-Design.md §3): the pilot's measures
(reader-facing-style/pilot/pilot_measure.py, unchanged) on one overview, plus the Documents cited
list's resolution of the text's short citations, part 2's lists and first person per 1,000 words.
Writes <out>/style.json.   python3 style_measure.py <run directory> [--out <dir>]"""
import json, re, statistics, sys, pathlib

CIT = re.compile(r'\((?:[^()]|\([^()]*\))*?(?:Foreign Relations|history\.state\.gov|Document \d)(?:[^()]|\([^()]*\))*\)')
TOOL = r'\b(the index|indexed|hits?|returned|matched|full-text|TEI|corpus|quer(?:y|ies)|stems?|vectors?|Hamming)\b'
NUMW = r'\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|twenty|thirty|forty|fifty|hundred|hundreds|thousand|thousands|dozen|half|third|quarter|twice|double)\b'
ROMAN = {'I': 1, 'V': 5, 'X': 10, 'L': 50, 'C': 100}


def roman(s):
    s = s.upper()
    if s.isdigit():
        return int(s)
    if not re.fullmatch(r'[IVXLC]+', s):
        return s
    v = 0
    for a, b in zip(s, s[1:] + ' '):
        v += -ROMAN[a] if b in ROMAN and ROMAN[b] > ROMAN[a] else ROMAN[a]
    return v


def measure(ov):
    """The pilot's measure(), unchanged."""
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
                numwords=len(re.findall(NUMW, body, re.I)), tool=len(re.findall(TOOL, body, re.I)), first=len(re.findall(r'\bI\b', body)),
                _sentence_lengths=lens)


SHORT = re.compile(r'\b(1[6-9]\d\d)(?:[–-]\d{2,4})?,\s*(?:(?:Volume|Vol\.)\s+(E?[–-]?\d+|[IVXLC]+),\s*)?'
                   r'(?:Part\s+(\d+),\s*)?Documents?\s+(\d+[a-z]?(?:\s*(?:,|and)\s*\d+[a-z]?)*)')


def vol_key(vol_id):
    """frus1969-76ve09p2 -> (1969, 1976, 'e9', '2'); frus1944v06 -> (1944, 1944, '6', None).
    A multi-year volume is cited by the document's own year as often as by its first ("1953, Volume
    XII, Part 2" for frus1952-54v12p2), so a citation resolves on any year in the volume's span."""
    y = re.match(r'frus(\d{4})(?:-(\d{2,4}))?', vol_id)
    v = re.search(r'v(e?)0*(\d+)', vol_id[4:])
    p = re.search(r'p(\d+)$', vol_id)
    if not y:
        return (None, None, None, None)
    a = int(y.group(1))
    b = int(str(a)[:4 - len(y.group(2))] + y.group(2)) if y.group(2) else a
    return (a, b, (v.group(1) + v.group(2)) if v else None, p.group(1) if p else None)


def cite_vol(raw):
    if raw is None:
        return None
    raw = raw.replace('–', '').replace('-', '')
    if raw.upper().startswith('E') and raw[1:].isdigit():
        return 'e' + str(int(raw[1:]))
    return str(roman(raw))


def documents_cited(ov):
    """Each short citation in the text, and whether the Documents cited list resolves it, matched
    through each entry's history.state.gov link (volume and document ids)."""
    m = re.search(r'^#+\s*Documents cited\s*$(.*?)(?=^#+\s|\Z)', ov, re.M | re.S | re.I)
    if not m:
        return {'present': False}
    entries = []
    for line in m.group(1).splitlines():
        if 'Foreign Relations' in line or 'history.state.gov' in line:
            u = re.search(r'historicaldocuments/([\w-]+)/(d\d+[a-z]?)', line)
            entries.append({'line': line.strip(), 'vol': vol_key(u.group(1)) if u else None, 'doc': u.group(2) if u else None})
    text = re.sub(r'https?://\S+', ' ', ov[:m.start()] + ov[m.end():])
    text = re.sub(r'Foreign Relations of the United States,\s*', '', text)
    cites = []
    for c in SHORT.finditer(text):
        for n in re.findall(r'\d+[a-z]?', c.group(4)):
            cites.append((c.group(1), cite_vol(c.group(2)), c.group(3), 'd' + n, c.group(0)))
    def resolves(c):
        by_link = any(e['vol'] and e['vol'][0] and e['doc'] == c[3] and e['vol'][0] <= int(c[0]) <= e['vol'][1]
                      and (c[1] is None or e['vol'][2] == c[1]) and (c[2] is None or e['vol'][3] == c[2]) for e in entries)
        # the edition's printed number can differ from the link's id ("Document 550 … /frus1874/d552")
        by_text = any(c[0] in e['line'] and re.search(r'Documents?\s+' + c[3][1:] + r'\b', e['line']) for e in entries)
        return by_link or by_text
    unresolved = [c[4] for c in cites if not resolves(c)]
    return {'present': True, 'entries': len(entries), 'entriesWithLink': sum(1 for e in entries if e['doc']),
            'shortCitations': len(cites), 'unresolved': unresolved[:40], 'unresolvedCount': len(unresolved)}


def part2_lists(ov):
    bl = re.search(r'##\s+The bottom line\s*\n(.*?)(?=\n##\s)', ov, re.S | re.I)
    p2 = re.search(r'\*\*2\.(.*?)(?=\*\*3\.)', bl.group(1), re.S) if bl else None
    if not p2:
        return {'found': False}
    runs, inrun, items = 0, False, 0
    for line in p2.group(1).splitlines():
        s = line.strip()
        if re.match(r'^([-*]|\d+\.)\s', s):
            items += 1
            if not inrun:
                runs, inrun = runs + 1, True
        elif s:
            inrun = False
    return {'found': True, 'listItems': items, 'lists': runs}


def run(run_dir, out_dir=None):
    d = pathlib.Path(run_dir)
    ov = (d / 'overview.md').read_text(errors='replace')
    m = measure(ov)
    lens = m.pop('_sentence_lengths')
    m['first_per_1k'] = round(1000 * m['first'] / max(1, m['words']), 1)
    m['documents_cited_list'] = documents_cited(ov)
    m['part2'] = part2_lists(ov)
    m['sentence_lengths'] = lens
    out = pathlib.Path(out_dir) if out_dir else d / 'checks'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'style.json').write_text(json.dumps(m, indent=1, ensure_ascii=False) + '\n')
    return m


if __name__ == '__main__':
    args = sys.argv[1:]
    out = None
    if '--out' in args:
        k = args.index('--out'); out = args[k + 1]; del args[k:k + 2]
    m = run(args[0], out)
    print({k: v for k, v in m.items() if k != 'sentence_lengths'})
