#!/usr/bin/env python3
"""Tally one workflow run's transcript dir: per agent, the model it ran on, its tokens by kind,
its tool calls and its wall clock from the transcript's own timestamps (design §4, runbook §7).

    python3 tally.py <transcript dir> [label]

Writes nothing; prints a markdown table and a totals line. Paste into usage.md."""
import glob, json, os, sys
from datetime import datetime

d = sys.argv[1]
rows = []
for f in sorted(glob.glob(os.path.join(d, 'agent-*.jsonl'))):
    meta = json.load(open(f[:-6] + '.meta.json')) if os.path.exists(f[:-6] + '.meta.json') else {}
    tot = {'input_tokens': 0, 'cache_creation_input_tokens': 0, 'cache_read_input_tokens': 0, 'output_tokens': 0}
    first = last = None
    tools = 0
    n = 0
    for line in open(f):
        try:
            r = json.loads(line)
        except Exception:
            continue
        n += 1
        ts = r.get('timestamp')
        if ts:
            first = first or ts
            last = ts
        m = r.get('message')
        if isinstance(m, dict):
            u = m.get('usage')
            if u:
                for k in tot:
                    tot[k] += u.get(k, 0) or 0
            c = m.get('content')
            if isinstance(c, list):
                tools += sum(1 for b in c if isinstance(b, dict) and b.get('type') == 'tool_use')
    secs = None
    if first and last:
        p = lambda s: datetime.fromisoformat(s.replace('Z', '+00:00'))
        secs = (p(last) - p(first)).total_seconds()
    rows.append((meta.get('description', '?'), meta.get('model', '?'), tot, tools, n, secs))

print('| agent | model | input | cache write | cache read | output | tool calls | records | wall clock |')
print('|---|---|---|---|---|---|---|---|---|')
T = {'input_tokens': 0, 'cache_creation_input_tokens': 0, 'cache_read_input_tokens': 0, 'output_tokens': 0}
tools_all = 0
for label, model, tot, tools, n, secs in rows:
    for k in T:
        T[k] += tot[k]
    tools_all += tools
    print(f"| {label} | {model} | {tot['input_tokens']:,} | {tot['cache_creation_input_tokens']:,} | "
          f"{tot['cache_read_input_tokens']:,} | {tot['output_tokens']:,} | {tools} | {n} | "
          f"{'' if secs is None else f'{secs/60:.1f} min'} |")
print(f"TOTAL input {T['input_tokens']:,}; cache write {T['cache_creation_input_tokens']:,}; "
      f"cache read {T['cache_read_input_tokens']:,}; output {T['output_tokens']:,}; tool calls {tools_all}")
