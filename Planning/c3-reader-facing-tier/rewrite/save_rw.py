#!/usr/bin/env python3
"""Merge one rewrite invocation's judges from its journal into results.json.  python3 save_rw.py <transcript dir>"""
import json, sys, pathlib
d = pathlib.Path(sys.argv[1]); out = pathlib.Path(__file__).parent / 'results.json'
res = json.loads(out.read_text()) if out.exists() else {}
labels = {}
for line in open(d / 'journal.jsonl'):
    r = json.loads(line)
    if r.get('type') == 'started': labels[r['key']] = r.get('label')
    if r.get('type') == 'result' and (labels.get(r['key']) or '').startswith('judge:'):
        res[labels[r['key']].split(':')[1]] = {'judge': r.get('result')}
out.write_text(json.dumps(res, indent=1, ensure_ascii=False) + '\n'); print('pairs saved:', sorted(res))
