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

Usage: brackets.py REPLICA_DIR   (replica.py's output)
"""
import collections, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
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
