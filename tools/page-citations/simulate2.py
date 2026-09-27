#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 review round 1, companion to simulate.py: under F, the pages whose answers mix a
quasi-document with a document; and the #pg_N references each rule leaves unresolved, against
v2's rule (O: a document claims [its first own arabic break, its last]; no start rows; "[N]"
unparseable) — the check behind "none that resolved stops resolving".

Usage: simulate2.py REPLICA_DIR   (replica.py's output)
"""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulate as ns

if len(sys.argv) != 2:
    sys.exit('usage: simulate2.py REPLICA_DIR')
C = collections.Counter(); EX = collections.defaultdict(list)
for fn, v in ns.replica_volumes(sys.argv[1]):
    if ns.micro(v): continue
    kinds = {d['id']: d['kind'] for d in v['docs']}
    t = ns.rows(v['docs'], 'F'); pd = ns.per_document(t)[0]
    sp = {d['id']: ns.spans(d, pd) for d in t}
    old = []
    for d in v['docs']:
        b = [int(x[0]) for x in d['pbs'] if x[0].strip().isdigit()]
        if b: old.append((d['id'], min(b), max(b)))
    pages = set()
    for d in t:
        pages.update(d['breaks'])
        if d['start'] is not None: pages.add(d['start'])
    for p in pages:
        kind, ids = ns.lookup(p, t, sp, pd, 'F')
        q = [i for i in ids if not ns.real({'kind': kinds[i]})]
        if q and len(q) < len(ids):
            C['F pages mixing a quasi-document and a document'] += 1
            if len(EX['mix']) < 8: EX['mix'].append((v['volumeId'], p, kind, ids[:4]))
    for d in v['docs']:
        for r in d['refs']:
            if not r.isdigit(): continue
            n = int(r)
            o = [i for (i, a, b) in old if a <= n <= b]
            kind, ids = ns.lookup(n, t, sp, pd, 'F')
            C['refs'] += 1
            C['refs: O %s, F %s' % ('resolves' if o else 'unresolved', 'resolves' if ids else 'unresolved')] += 1
            if o and not ids and len(EX['OnotF']) < 10: EX['OnotF'].append((v['volumeId'], d['id'], n, o[:3]))
for k in sorted(C): print('%8d  %s' % (C[k], k))
for k, xs in EX.items():
    print(k)
    for x in xs: print('   ', x)
