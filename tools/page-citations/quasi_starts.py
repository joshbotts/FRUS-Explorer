#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 review round 1: the quasi-documents' start rows alone — F against F plus a start row
for every promoted section (bracket rule and per-document rule as F). This is the measurement
behind round 1's finding 1 (a promoted section's start made it a page's answer).

Usage: quasi_starts.py REPLICA_DIR   (replica.py's output)
"""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulate as ns

def rows_q(docs):
    out = []
    for d in docs:
        s = ns.page(d['start'], 'F') if d['start'] is not None else None
        b = [p for p in (ns.page(x, 'F') for x in d['pbs']) if p is not None]
        if s is None and not b: continue
        out.append({'id': d['id'], 'kind': d['kind'], 'start': s, 'breaks': b})
    return out

if len(sys.argv) != 2:
    sys.exit('usage: quasi_starts.py REPLICA_DIR')
C = collections.Counter(); vols = set()
for fn, v in ns.replica_volumes(sys.argv[1]):
    if ns.micro(v): continue
    kinds = {d['id']: d['kind'] for d in v['docs']}
    for d in v['docs']:
        if not ns.real(d) and d['start'] is not None and ns.page(d['start'], 'F') is not None:
            C['quasi-documents with an arabic start (pg_ bracket rule)'] += 1
    tq = rows_q(v['docs']); tf = ns.rows(v['docs'], 'F')
    pdq = ns.per_document(tq)[0]; pdf = ns.per_document(tf)[0]
    spq = {d['id']: ns.spans(d, pdq) for d in tq}; spf = {d['id']: ns.spans(d, pdf) for d in tf}
    pages = set()
    for d in tq:
        pages.update(d['breaks'])
        if d['start'] is not None: pages.add(d['start'])
    for p in pages:
        aq = ns.lookup(p, tq, spq, pdq, 'F'); af = ns.lookup(p, tf, spf, pdf, 'F')
        fq = aq[1][0] if aq[1] else None; ff = af[1][0] if af[1] else None
        if ff and ns.real({'kind': kinds[ff]}) and fq and not ns.real({'kind': kinds[fq]}):
            C['pages whose first answer moves from a document to a section'] += 1; vols.add(v['volumeId'])
        if af[0] in ('begins', 'printed') and len(af[1]) == 1 and ns.real({'kind': kinds[af[1][0]]}) and aq[0] == 'begins' and all(not ns.real({'kind': kinds[i]}) for i in aq[1]):
            C['pages where a section alone beginning there hides the one document'] += 1
for k in sorted(C): print(C[k], k)
print('volumes', len(vols))
