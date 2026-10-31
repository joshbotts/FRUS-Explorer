#!/usr/bin/env python3
"""Save one workflow invocation's agent results from its journal (R16's save_verdicts.py, extended for
this tier's split invocations): run, score and refute results merge into runs/<label>/verdicts.json, a
judge's into judges/judge<block>.json, and the calibration's into runs/<cal label>/verdicts.json.
    python3 save_f.py <transcript dir>"""
import json, os, sys, pathlib

d = pathlib.Path(sys.argv[1])
labels, results = {}, {}
for line in open(d / 'journal.jsonl'):
    r = json.loads(line)
    if r.get('type') == 'started':
        labels[r['key']] = r.get('label')
    if r.get('type') == 'result':
        results[labels.get(r['key'], r['key'])] = r.get('result')
root = pathlib.Path(__file__).parent
for name, res in results.items():
    kind, _, lab = (name or '?').partition(':')
    if kind == 'judge':
        p = root / 'judges' / f'judge{lab}.json'
        p.parent.mkdir(exist_ok=True)
        p.write_text(json.dumps({name: res}, indent=2, ensure_ascii=False) + '\n')
    else:
        p = root / 'runs' / lab / 'verdicts.json'
        p.parent.mkdir(parents=True, exist_ok=True)
        cur = json.loads(p.read_text()) if p.exists() else {}
        cur[name] = res
        p.write_text(json.dumps(cur, indent=2, ensure_ascii=False) + '\n')
    print('saved', name, '->', p.relative_to(root))
