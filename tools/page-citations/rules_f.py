#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 review round 1: measure_rules.py's printed-volume block again under the round-1 rule, with
the page tables as the index builds them (replica.py: documents, editorial notes and promoted
sections; F: start rows for documents only, "[N]" only with pg_N), against v2's rule over the same
ASTs' own digit breaks. Documents = type="document" divs (editorialNote divs: none in the corpus).
These are the figures the shipped code comments state (`PageSpanResolver`'s type doc and the
engine's): 306,463 / 185,470 / 120,993 against the old rule's 156,625 / 32,293 / 117,503 / 40 / 2.

Usage: rules_f.py REPLICA_DIR   (replica.py's output)
"""
import collections, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulate as ns

if len(sys.argv) != 2:
    sys.exit('usage: rules_f.py REPLICA_DIR')
C = collections.defaultdict(collections.Counter)
for fn, v in ns.replica_volumes(sys.argv[1]):
    if ns.micro(v): continue
    t = ns.rows(v['docs'], 'F'); pd = ns.per_document(t)[0]
    g = 'perdoc' if pd else 'printed'
    c = C[g]
    sp = {d['id']: ns.spans(d, pd) for d in t}
    old = []
    for d in v['docs']:
        b = [int(x[0]) for x in d['pbs'] if re.match(r'^\s*\d+\s*$', x[0])]
        if b: old.append((d['id'], min(b), max(b)))
    reals = [d for d in v['docs'] if ns.real(d)]
    order = [d['id'] for d in reals]
    c['document divs'] += len(reals)
    for k, d in enumerate(reals):
        s = ns.page(d['start'], 'F') if d['start'] is not None else None
        if s is None: continue
        c['docs: recorded arabic start'] += 1
        placing = sp.get(d['id'], (None,))[0]
        if placing is None: c['docs: start recorded, but does not place it'] += 1; continue
        c['docs: a start that places it'] += 1
        kind, ids = ns.lookup(s, t, sp, pd, 'F')
        if ids == [d['id']]: c['start page -> new: itself alone'] += 1
        elif d['id'] in ids: c['start page -> new: itself among several'] += 1
        else: c['start page -> new: NOT itself'] += 1
        o = [i for (i, a, b) in old if a <= s <= b]
        if o == [d['id']]: c['start page -> old: itself'] += 1
        elif not o: c['start page -> old: none'] += 1
        elif len(o) > 1: c['start page -> old: several (arbitrary)'] += 1
        elif k > 0 and o[0] == order[k - 1]: c['start page -> old: the preceding document'] += 1
        else: c['start page -> old: an earlier document or a section'] += 1
    for d in reals:
        e = sp.get(d['id'])
        if e is None or e[2] is None: c['check: nothing places it'] += 1
for g in C:
    print(g)
    for k in sorted(C[g]): print('  %8d  %s' % (C[g][k], k))
