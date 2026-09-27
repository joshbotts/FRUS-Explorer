#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 lane P: how the stored page cross-reference edges move when <ref target="#pg_N"> is
resolved by the new rule instead of the old one, and which rule the editors' own words agree with.

Scope: the refs IndexingPipeline.resolvePageBasedCrossReferences rewrites - a same-volume
`#pg_<digits>` target (target_volume_id IS NULL) inside a document div - in the 548 volumes that
are not microfiche supplements (the pipeline rewrites them there too; they are reported apart).
OLD: the document whose own arabic breaks span N ([min, max]); several -> Dictionary order.
NEW: the documents whose recorded start page is N ("[N]" read as N); when none, those certainly
  printed on N. The edge is written to the FIRST in source order.
EVIDENCE: a reference whose footnote names a date ("June 5") is checked against each candidate's
  frus:doc-dateTime-min day; the rule whose document carries a date the note names is the one the
  editors meant. Only refs where the two rules pick different documents are counted.

The scan holds document divs only, so these are the lane's figures; xrefs_f.py re-measures them
over the parser's whole emission under the round-1 rule.

Usage: measure_xrefs.py SCAN_DIR   (scan_corpus.py's output)
"""
import collections, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_rules import scan_volumes

if len(sys.argv) != 2:
    sys.exit('usage: measure_xrefs.py SCAN_DIR')
MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
          'October', 'November', 'December']
def ar_old(x): return int(x) if x is not None and re.match(r'^\d+$', x) else None
def ar_new(x):
    if x is None: return None
    m = re.match(r'^\[?(\d+)\]?$', x)
    return int(m.group(1)) if m else None
def micro(v): return 'msupp' in v['volumeId'].lower() or 'microfiche' in v['title'].lower()
PER_DOCUMENT = {'frus1969-76ve01', 'frus1969-76ve02', 'frus1969-76ve03', 'frus1969-76ve04',
                'frus1969-76ve05p1', 'frus1969-76ve05p2', 'frus1969-76ve06', 'frus1969-76ve07',
                'frus1969-76ve08', 'frus1969-76ve10', 'frus1969-76ve12', 'frus1969-76ve13',
                'frus1969-76ve14p1', 'frus1969-76ve15p1', 'frus1981-88v16'}
def spans(d):
    s = ar_new(d['start']); b = [ar_new(x) for x in d['pbs'] if ar_new(x) is not None]
    if s is not None and (not b or min(b) >= s): return (s, (s, max([s] + b)))
    if b: return (None, (min(b), max(b)))
    return (None, None)
def new_lookup(page, table):
    begins = [i for (i, s, c) in table if s == page]
    if begins: return ('begins', begins)
    printed = [i for (i, s, c) in table if c and c[0] <= page <= c[1]]
    return ('printed', printed) if printed else ('none', [])
def old_claims(page, docs):
    out = []
    for d in docs:
        b = [ar_old(x) for x in d['pbs'] if ar_old(x) is not None]
        if b and min(b) <= page <= max(b): out.append(d['id'])
    return out
def day_names(date):
    m = re.match(r'^(\d{4})-(\d\d)-(\d\d)', date or '')
    if not m: return []
    return ['%s %d' % (MONTHS[int(m.group(2)) - 1], int(m.group(3)))]

C = collections.defaultdict(collections.Counter); ex = collections.defaultdict(list)
for fn, v in scan_volumes(sys.argv[1]):
    vid = v['volumeId']
    g = 'microfiche (5)' if micro(v) else 'per-document (15)' if vid in PER_DOCUMENT else 'printed (533)'
    docs = v['docs']
    if not v['refs']: continue
    table = [(d['id'],) + spans(d) for d in docs]
    byid = {d['id']: d for d in docs}
    c = C[g]
    oc = {}; nc = {}
    for r in v['refs']:
        if not re.match(r'^\d+$', r['n']) or int(r['n']) <= 0:
            c['refs: not an arabic page (left unresolved by both)'] += 1; continue
        p = int(r['n']); c['refs: same-volume arabic pg_N inside a document'] += 1
        if p not in oc: oc[p] = old_claims(p, docs); nc[p] = new_lookup(p, table)
        o = oc[p]
        kind, ids = nc[p]
        old_t = o[0] if len(o) == 1 else ('*several*' if o else None)
        new_t = ids[0] if ids else None
        c['new: %s, %s' % (kind, 'none' if not ids else 'one' if len(ids) == 1 else 'several')] += 1
        if len(ids) > 1:
            # Of the documents the page names, which does the note's date name? The edge stores
            # the first. Counted over every ambiguous reference, whatever the old rule did.
            hits = [i for i in ids if any(re.search(r'\b%s\b' % n, r['note'] or '') for n in day_names(byid[i]['date']))]
            c['ambiguous (%s): note date names ' % kind + ('none of them' if not hits else 'the first' if hits[0] == ids[0] else 'only a later one')] += 1
        if old_t == new_t and old_t is not None: c['edge: unchanged'] += 1; continue
        if old_t is None and new_t is None: c['edge: unresolved by both'] += 1; continue
        if old_t is None: c['edge: newly resolved (old: none)'] += 1
        elif new_t is None: c['edge: newly UNresolved'] += 1
        elif old_t == '*several*': c['edge: old arbitrary (several) -> new'] += 1
        else: c['edge: moved to another document'] += 1
        # evidence where both name a document and they differ
        note = r['note'] or ''
        if old_t in byid and new_t in byid and old_t != new_t:
            on = [n for n in day_names(byid[old_t]['date']) if re.search(r'\b%s\b' % n, note)]
            nn = [n for n in day_names(byid[new_t]['date']) if re.search(r'\b%s\b' % n, note)]
            if on or nn:
                key = 'evidence (moved, note names a date): ' + ('both' if on and nn else 'new only' if nn else 'OLD only')
                c[key] += 1
                if len(ex[g + key]) < 6: ex[g + key].append((vid, r['src'], p, old_t, new_t, note[:160]))
            else:
                c['evidence (moved): note names neither date'] += 1
        if old_t is None and new_t in byid:
            nn = [n for n in day_names(byid[new_t]['date']) if re.search(r'\b%s\b' % n, note)]
            c['evidence (newly resolved): note names the new document\'s date' if nn else 'evidence (newly resolved): no date match'] += 1
for g in sorted(C):
    print(g)
    for k in sorted(C[g]): print('  %8d  %s' % (C[g][k], k))
for k, xs in ex.items():
    print(k)
    for x in xs: print('   ', x)
