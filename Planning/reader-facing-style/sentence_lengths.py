#!/usr/bin/env python3
"""Prose sentence lengths of the 25 measured overviews, with the citation parentheticals the block
requires stripped first, so the measure is of the writing and not of the citation form. List items
count as their own blocks; headings, tables and block quotes are left out.
    python3 sentence_lengths.py <worktree>"""
import re, statistics, sys, pathlib
ROOT = pathlib.Path(sys.argv[1]) / 'Planning'
TIERS = [('C-3', 'c3-reader-test', [f'r{i}' for i in range(1, 13)]), ('V', 'c3-vectors-tier', ['v1', 'v2', 'v3', 'v4']),
         ('R16', 'c3-steering-tier', [f's{i}' for i in range(1, 10)])]
CIT = re.compile(r'\((?:[^()]|\([^()]*\))*?(?:Foreign Relations|history\.state\.gov|Document \d)(?:[^()]|\([^()]*\))*\)')
for tier, folder, labs in TIERS:
    lengths, cites = [], []
    for lab in labs:
        blocks, cur = [], []
        for line in (ROOT / folder / 'runs' / lab / 'overview.md').read_text().splitlines():
            s = line.strip()
            item = re.match(r'^([-*]|\d+\.)\s', s)
            if not s or s.startswith(('#', '|', '>')) or item:
                if cur: blocks.append(' '.join(cur)); cur = []
                if item: blocks.append(re.sub(r'^([-*]|\d+\.)\s+', '', s))
                continue
            cur.append(s)
        if cur: blocks.append(' '.join(cur))
        for b in blocks:
            cites += [len(c.split()) for c in CIT.findall(b)]
            b = re.sub(r'https?://\S+', '', CIT.sub('', b))
            lengths += [n for n in (len(x.split()) for x in re.split(r'(?<=[.!?])["”’]?\s+(?=[A-Z“"])', b)) if n >= 3]
    p90 = sorted(lengths)[int(0.9 * (len(lengths) - 1))]
    print(f'{tier}: {len(lengths)} sentences, median {statistics.median(lengths)}, p90 {p90}, '
          f'over 40 words {sum(x > 40 for x in lengths)} ({100 * sum(x > 40 for x in lengths) / len(lengths):.0f}%); '
          f'{len(cites)} citation parentheticals, median {statistics.median(cites)} words')
