#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 review round 1: measure_xrefs.py's categories again, with the page tables as the index
builds them after review round 1 — every emitted AST (documents, editorial notes, promoted
sections) from replica.py, start rows for documents only, "[N]" only with pg_N (F) — against v2's
rule over the same ASTs' own digit breaks (O: [min, max]; several -> '*several*'). The references
and the documents' dates are lane P's scan (scan_corpus.py): same-volume #pg_ refs inside
document divs.

Usage: xrefs_f.py REPLICA_DIR SCAN_DIR   (replica.py's and scan_corpus.py's outputs)
"""
import collections, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulate as ns

if len(sys.argv) != 3:
    sys.exit('usage: xrefs_f.py REPLICA_DIR SCAN_DIR')
S = sys.argv[2]
MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
          'October', 'November', 'December']
def day_names(date):
    m = re.match(r'^(\d{4})-(\d\d)-(\d\d)', date or '')
    return ['%s %d' % (MONTHS[int(m.group(2)) - 1], int(m.group(3)))] if m else []
C = collections.Counter()
for fn, v in ns.replica_volumes(sys.argv[1]):
    if ns.micro(v): continue
    t = ns.rows(v['docs'], 'F'); pd = ns.per_document(t)[0]
    if pd: continue
    sc = json.load(open(os.path.join(S, fn)))
    if not sc['refs']: continue
    byid = {d['id']: d for d in sc['docs']}
    sp = {d['id']: ns.spans(d, pd) for d in t}
    old = []
    for d in v['docs']:
        b = [int(x[0]) for x in d['pbs'] if re.match(r'^\s*\d+\s*$', x[0])]
        if b: old.append((d['id'], min(b), max(b)))
    cache = {}
    for r in sc['refs']:
        if not re.match(r'^\d+$', r['n']) or int(r['n']) <= 0: continue
        p = int(r['n']); C['refs'] += 1
        if p not in cache:
            o = [i for (i, a, b) in old if a <= p <= b]
            cache[p] = (o, ns.lookup(p, t, sp, pd, 'F'))
        o, (kind, ids) = cache[p]
        old_t = o[0] if len(o) == 1 else ('*several*' if o else None)
        new_t = ids[0] if ids else None
        C['new: %s, %s' % (kind, 'none' if not ids else 'one' if len(ids) == 1 else 'several')] += 1
        if new_t is not None and new_t not in byid: C['new: stored against a promoted section'] += 1
        if len(ids) > 1:
            hits = [i for i in ids if i in byid and any(re.search(r'\b%s\b' % n, r['note'] or '') for n in day_names(byid[i]['date']))]
            C['ambiguous (%s): note date names ' % kind + ('none of them' if not hits else 'the first' if hits[0] == ids[0] else 'only a later one')] += 1
        if old_t == new_t and old_t is not None: C['edge: unchanged'] += 1; continue
        if old_t is None and new_t is None: C['edge: unresolved by both'] += 1; continue
        if old_t is None: C['edge: newly resolved (old: none)'] += 1
        elif new_t is None: C['edge: newly UNresolved'] += 1
        elif old_t == '*several*': C['edge: old arbitrary (several) -> new'] += 1
        else: C['edge: moved to another document'] += 1
        note = r['note'] or ''
        if old_t in byid and new_t in byid and old_t != new_t:
            on = [n for n in day_names(byid[old_t]['date']) if re.search(r'\b%s\b' % n, note)]
            nn = [n for n in day_names(byid[new_t]['date']) if re.search(r'\b%s\b' % n, note)]
            if on or nn: C['evidence (moved, note names a date): ' + ('both' if on and nn else 'new only' if nn else 'OLD only')] += 1
            else: C['evidence (moved): note names neither date'] += 1
for k in sorted(C): print('%8d  %s' % (C[k], k))
