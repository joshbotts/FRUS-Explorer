#!/usr/bin/env python3
"""Fold one pilot workflow's instrument results into results.json.   python3 save_pairs.py <transcript dir>"""
import json, sys, os, pathlib
d = sys.argv[1]; labels = {}; out = json.load(open('results.json')) if pathlib.Path('results.json').exists() else {}
for line in open(os.path.join(d, 'journal.jsonl')):
    r = json.loads(line)
    if r.get('type') == 'started': labels[r['key']] = r.get('label')
    if r.get('type') == 'result':
        lab = labels.get(r['key'], '')
        if lab.startswith(('o2p:', 'judge:')):
            kind, pair = lab.split(':'); out.setdefault(pair, {})[kind] = r.get('result')
json.dump(out, open('results.json', 'w'), indent=1, ensure_ascii=False)
print('pairs saved:', sorted(out))
