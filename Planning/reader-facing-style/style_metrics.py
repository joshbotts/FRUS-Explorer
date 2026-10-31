#!/usr/bin/env python3
"""Mechanical style measures over the 25 measured runs' reader-facing text (the overview and the
collection's introduction, prose and notes), for the reader-facing style review. Read-only."""
import json, re, statistics, sys, pathlib

ROOT = pathlib.Path(sys.argv[1])          # the worktree
TIERS = [('C-3', 'c3-reader-test', [f'r{i}' for i in range(1, 13)]),
         ('V', 'c3-vectors-tier', ['v1', 'v2', 'v3', 'v4']),
         ('R16', 'c3-steering-tier', [f's{i}' for i in range(1, 10)])]
NUMWORDS = r'\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|hundreds|thousand|thousands|dozen|dozens|half|third|thirds|quarter|quarters|fifth|fifths|tenth|tenths|twice|double|doubles|triple)\b'
TOOL = r'\b(SQL|quer(?:y|ies)|database|index(?:ed|es)?|FTS5?|stem(?:s|med|mer)?|regex|scripts?|columns?|tables?|MATCH|Hamming|cosines?|vectors?|neighbou?rs?|clusters?|embedding|digest|tokeni[sz]\w*|search(?:es|ed)?|hits?|returned|matched)\b'
HEDGE = r'\b(may|might|appears?|seems?|suggests?|likely|perhaps|probably|possibly|apparently)\b'
SKELETON = ['the bottom line', 'decisions this needs from you', 'findings', 'how this was done', 'read next']

def sentences(text):
    t = re.sub(r'https?://[^\s)\]]+', lambda m: 'URL' + ('.' if m.group(0).endswith('.') else ''), text)
    t = re.sub(r'\b(No|Nos|Vol|Doc|Mr|Mrs|Dr|U\.S|e\.g|i\.e|cf|pp|p)\.', lambda m: m.group(1) + '<dot>', t)
    parts = re.split(r'(?<=[.!?])["”’)]?\s+(?=[A-Z“"(\[])', t)
    return [p for p in (x.strip() for x in parts) if len(p.split()) >= 3]

def prose_of(md):
    lines = []
    for l in md.splitlines():
        s = l.strip()
        if not s or s.startswith('#') or s.startswith('|') or s.startswith('>'):
            continue
        lines.append(re.sub(r'^[-*]\s+|^\d+\.\s+', '', s))
    return ' '.join(lines)

rows = []
for tier, folder, labels in TIERS:
    for lab in labels:
        d = ROOT / 'Planning' / folder / 'runs' / lab
        ov = (d / 'overview.md').read_text()
        body = prose_of(ov)
        words = body.split()
        sents = sentences(body)
        slen = [len(s.split()) for s in sents]
        heads = [h.strip().lower() for h in re.findall(r'^##\s+(.*)$', ov, re.M)]
        skel = sum(any(k in h for h in heads) for k in SKELETON)
        quotes = re.findall(r'[“"]([^”"]{25,})[”"]', ov) + re.findall(r'^>\s?(.+)$', ov, re.M)
        frus = len(re.findall(r'Foreign Relations of the United States', ov))
        urls = len(re.findall(r'history\.state\.gov/historicaldocuments/', ov))
        bare = len(re.findall(r'(?<!historicaldocuments/)\bfrus[0-9][\w-]*/d\d+', ov))
        nums = re.findall(r'(?<![\w/])\d[\d,]*(?:\.\d+)?', re.sub(r'https?://\S+', '', body))
        years = [n for n in nums if re.fullmatch(r'1[89]\d\d|20[0-3]\d', n)]
        numw = re.findall(NUMWORDS, body, re.I)
        tool = re.findall(TOOL, body, re.I)
        hedge = re.findall(HEDGE, body, re.I)
        first = re.findall(r'\bI\b', body)
        memo = re.findall(r'\bmemo\b', body, re.I)
        bl = re.search(r'##\s+The bottom line\s*\n(.*?)(?=\n##\s)', ov, re.S | re.I)
        blw = len(prose_of(bl.group(1)).split()) if bl else None
        how = re.search(r'##\s+How this was done\s*\n(.*?)(?=\n##\s|\Z)', ov, re.S | re.I)
        howw = len(prose_of(how.group(1)).split()) if how else None
        col = json.load(open(d / 'collection.fruscollection'))
        notes = [n for e in col.get('entries', []) for n in (e.get('notes') or [])]
        prose = [e.get('text') or '' for e in col.get('entries', []) if e.get('kind') == 'prose']
        v = json.load(open(d / 'verdicts.json'))
        j = v.get('judge:' + lab) or {}
        s = v.get('score:' + lab) or {}
        it = {x['id']: x['verdict'] for x in s.get('items', [])}
        rows.append(dict(
            tier=tier, lab=lab, words=len(words), sents=len(sents),
            mean_sent=round(statistics.mean(slen), 1) if slen else None,
            p90_sent=sorted(slen)[int(0.9 * (len(slen) - 1))] if slen else None, max_sent=max(slen) if slen else None,
            over40=sum(x > 40 for x in slen), skel=skel, heads=len(heads), quotes=len(quotes),
            frus=frus, urls=urls, bare=bare, numerals=len(nums) - len(years), years=len(years),
            numwords=len(numw), tool=len(tool), tool_per_1k=round(1000 * len(tool) / max(1, len(words)), 1),
            hedge_per_1k=round(1000 * len(hedge) / max(1, len(words)), 1), first=len(first), memo=len(memo),
            paren_per_1k=round(1000 * body.count('(') / max(1, len(words)), 1),
            semi_per_1k=round(1000 * body.count(';') / max(1, len(words)), 1),
            bottom_words=blw, how_words=howw, intro_words=len((col.get('introductionText') or '').split()),
            notes=len(notes), note_mean=round(statistics.mean(len(n.split()) for n in notes), 1) if notes else 0,
            prose_blocks=len(prose), prose_words=sum(len(p.split()) for p in prose),
            judge=j.get('yes'), O1=it.get('O1'), O2=it.get('O2'), O3=it.get('O3'), O2p=it.get("O2'"),
            tool_top=sorted({t.lower() for t in tool}, key=lambda t: -[x.lower() for x in tool].count(t))[:6]))
json.dump(rows, open(sys.argv[2], 'w'), indent=1)
cols = ['tier', 'lab', 'words', 'mean_sent', 'p90_sent', 'max_sent', 'over40', 'skel', 'quotes', 'frus', 'urls', 'bare',
        'numerals', 'numwords', 'tool_per_1k', 'hedge_per_1k', 'first', 'memo', 'paren_per_1k', 'bottom_words', 'how_words',
        'notes', 'note_mean', 'judge', 'O2']
print(' '.join(f'{c[:9]:>9}' for c in cols))
for r in rows:
    print(' '.join(f'{str(r[c])[:9]:>9}' for c in cols))
for tier in ('C-3', 'V', 'R16'):
    rs = [r for r in rows if r['tier'] == tier]
    print(tier, 'median words', statistics.median(r['words'] for r in rs), 'mean sentence', round(statistics.mean(r['mean_sent'] for r in rs), 1),
          'tool/1k', round(statistics.mean(r['tool_per_1k'] for r in rs), 1), 'bottom words median', statistics.median(r['bottom_words'] or 0 for r in rs))
print('top tool words over all:', __import__('collections').Counter(t for r in rows for t in r['tool_top']).most_common(12))
