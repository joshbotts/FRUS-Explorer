#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 review round 1: bracketed page breaks ("[31]") by where they sit (a start, or a break
inside an emitted AST), by whether the AST is a document or a promoted section, and by the form
of the break's xml:id (pg_N, a pg-seq pagination, or other) — the measurement behind
`PageNumber.unnumbered`, which reads "[31]" as page 31 only when its id is pg_31.

Then, added for #1512 review round 1, the DIGIT breaks the same id rule would apply to — the round-1
plan entry's "digit breaks of another pagination are the volume's pages": in the printed volumes
(not those that number pages per document, whose ids are never pg_N), every <pb> an emitted AST
holds or starts on whose @n is an arabic number and whose id is not pg_N, counted once each and once
per AST; and the pages such a break names whose answer under F lists the AST holding it beside
another (`frus1862` and `frus1865p1`: the President's message beside a document; `frus1871`: two
documents).

Usage: brackets.py REPLICA_DIR   (replica.py's output)
"""
import collections, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulate as ns
from simulate import micro, replica_volumes

if len(sys.argv) != 2:
    sys.exit('usage: brackets.py REPLICA_DIR')
BR = re.compile(r'^\[(\d+)\]$')
C = collections.Counter(); ex = collections.defaultdict(list)
for fn, v in replica_volumes(sys.argv[1]):
    if micro(v): continue
    for d in v['docs']:
        real = d['kind'] in ('document', 'editorialNote')
        k = 'real' if real else 'quasi'
        s = d['start']
        if s and BR.match(s[0].strip()):
            m = BR.match(s[0].strip()); idok = s[1] == 'pg_' + m.group(1)
            key = '%s start, id %s' % (k, 'pg_N' if idok else ('pg-seq' if s[1].startswith('pg-seq') else 'other:' + s[1][:8]))
            C[key] += 1
            if len(ex[key]) < 4: ex[key].append((v['volumeId'], d['id'], s))
        for n, i in d['pbs']:
            m = BR.match(n.strip())
            if m:
                idok = i == 'pg_' + m.group(1)
                key = '%s inner, id %s' % (k, 'pg_N' if idok else ('pg-seq' if i.startswith('pg-seq') else 'other:' + i[:8]))
                C[key] += 1
                if len(ex[key]) < 4: ex[key].append((v['volumeId'], d['id'], (n, i)))
for k in sorted(C): print('%6d  %s' % (C[k], k))
for k in sorted(ex): print(k, ex[k])

DIG = re.compile(r'^\s*(\d+)\s*$')
def id_form(i):
    if re.match(r'^pg_0\d', i): return 'pg_ zero-padded'
    if i.startswith('pg-seq'): return i.split('_')[0] + '_' if '_' in i else 'pg-seq-'
    return 'other: ' + i
pbs = collections.defaultdict(set); rows_ = collections.Counter(); forms = collections.defaultdict(collections.Counter)
shared = collections.defaultdict(collections.Counter)
for fn, v in replica_volumes(sys.argv[1]):
    if micro(v): continue
    t = ns.rows(v['docs'], 'F'); pd = ns.per_document(t)[0]
    if pd: continue
    vid = v['volumeId']; kinds = {d['id']: d['kind'] for d in v['docs']}
    holders = collections.defaultdict(set)   # page -> ASTs holding or starting on such a break
    for d in v['docs']:
        for n, i in list(d['pbs']) + ([d['start']] if d['start'] else []):
            m = DIG.match(n)
            if not m or i == 'pg_' + m.group(1): continue
            rows_[vid] += 1; holders[int(m.group(1))].add(d['id'])
            if i not in pbs[vid]: forms[vid][id_form(i)] += 1
            pbs[vid].add(i)
    if not holders: continue
    sp = {d['id']: ns.spans(d, pd) for d in t}
    for p, hs in holders.items():
        kind, ids = ns.lookup(p, t, sp, pd, 'F')
        if len(ids) < 2 or not hs & set(ids): continue
        docs = sum(1 for i in ids if ns.real({'kind': kinds[i]}))
        shared[vid]['a section beside %d document(s)' % docs if docs < len(ids) else '%d documents' % docs] += 1
print('digit breaks with an id other than pg_N, printed volumes: %d <pb>s in %d volumes (%d counted once per AST holding or starting on one)'
      % (sum(len(x) for x in pbs.values()), len(pbs), sum(rows_.values())))
for vid in sorted(pbs, key=lambda k: -len(pbs[k])):
    print('  %-16s %4d <pb>s, %4d per AST   ids %s   pages naming the holder beside another: %s'
          % (vid, len(pbs[vid]), rows_[vid], dict(forms[vid]), dict(shared[vid]) or 'none'))
