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

Then, added for #1512 review round 1 (figures the shipped comments state that no other script
printed):
  - the printed volumes' pages by how many ASTs F names on each (`sharedPageListLimit`: the most
    is ten, on one page, and three pages name nine);
  - in each volume that numbers its pages per document, page 1 under F (every document printed on
    a page 1) against what the committed rule (C, simulate.py) listed there (`frus1969-76ve10`
    665 against 120, `frus1981-88v16` 88 against 15), and the page naming the most;
  - given SCAN_DIR, each such volume's page-1 breaks outside every document div against the
    documents holding a page-1 break of their own (the `mixedPerDocumentVolume` fixture's comment
    in CitationMatchingEngineTests);
  - the per-document gate's margins (`PageSpanResolver.numbersPagesPerDocument`): the printed
    volume whose documents restart their numbering most often (`frus1902app1`, 2 of 196), and the
    printed volume that restarts most often when every row with a page counts, a promoted section
    by its breaks (`frus1919Parisv13`, 36 of 149, a hair under one in four);
  - the per-document volumes' documents with no break of their own, by where they begin
    (`PageSpanResolver.DocumentPages.placingStart`): on a page 1 written outside every document,
    on a page 1 another document holds, or on a later page.

And, added for #1512 review round 2:
  - the committed rule's answer for `frus1969-76ve05p1`'s page 2 against F's: C named d239 alone,
    a document with no break of its own whose start is d238's last break, where F names the 275
    documents printed on a page 2 (the #1503 round-1 plan entry's finding 3–4);
  - given SCAN_DIR, each per-document volume's page-1 breaks inside document divs, and how many
    of them come before their document's own <head> has closed or sit in a document with none
    (ve10's 657 and `frus1981-88v16`'s 94 all follow the heading);
  - given SCAN_DIR, the breaks outside every document div in the 548 volumes that are not
    microfiche supplements, and how many are arabic (the `startPageVolume` fixture's comment in
    CitationMatchingEngineTests, which read #1474's 97,413 over 540 volumes until then).

Usage: rules_f.py REPLICA_DIR [SCAN_DIR]   (replica.py's and scan_corpus.py's outputs)
"""
import collections, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulate as ns

if len(sys.argv) not in (2, 3):
    sys.exit('usage: rules_f.py REPLICA_DIR [SCAN_DIR]')
SCAN = sys.argv[2] if len(sys.argv) == 3 else None
C = collections.defaultdict(collections.Counter)
names = collections.Counter()   # printed-volume pages by how many ASTs F names
perdoc_rows = []
top_rate = (0.0, 0, 0, '')       # the printed volume restarting most often
top_every = (0.0, 0, 0, '')      # ... when every row with a page counts, a section by its breaks
breakless = collections.Counter()
inside_rows = []                 # (volume, page-1 breaks inside documents, before the heading, no heading)
EXAMPLE = ('frus1969-76ve05p1', 2)
example = None
def restarts_every_row(table):
    """ns.per_document's count over every row with a page, not only rows with a start."""
    prev = None; restarts = 0; paged = 0
    for d in table:
        pages = ([d['start']] if d['start'] is not None else []) + d['breaks']
        if not pages: continue
        paged += 1; r = False
        for p in pages:
            if prev is not None and p < prev: r = True
            prev = p
        restarts += r
    return restarts, paged
def answers(t, sp, pd, regime):
    pages = set()
    for d in t:
        pages.update(d['breaks'])
        if d['start'] is not None: pages.add(d['start'])
    return {p: ns.lookup(p, t, sp, pd, regime) for p in pages}
for fn, v in ns.replica_volumes(sys.argv[1]):
    if ns.micro(v): continue
    t = ns.rows(v['docs'], 'F'); pd = ns.per_document(t)[0]
    g = 'perdoc' if pd else 'printed'
    c = C[g]
    sp = {d['id']: ns.spans(d, pd) for d in t}
    a = answers(t, sp, pd, 'F')
    _, restarts, placed = ns.per_document(t)
    if not pd:
        for p, (kind, ids) in a.items(): names[len(ids)] += 1
        if placed and restarts / placed > top_rate[0]: top_rate = (restarts / placed, restarts, placed, v['volumeId'])
        r, n = restarts_every_row(t)
        if n and r / n > top_every[0]: top_every = (r / n, r, n, v['volumeId'])
    else:
        held = {i for d in v['docs'] for (_, i) in d['pbs']}   # xml:ids some AST's nodes hold
        starts = {d['id']: d['start'] for d in v['docs']}
        for x in t:
            if not ns.real(x) or x['breaks']: continue
            if x['start'] == 1:
                breakless['on a page 1 outside every document' if starts[x['id']][1] not in held
                          else 'on a page 1 another document holds'] += 1
            else:
                breakless['on a later page' if x['start'] else 'no start'] += 1
        tc = ns.rows(v['docs'], 'C')
        ac = answers(tc, {d['id']: ns.spans(d, False) for d in tc}, False, 'C')
        most = max(a, key=lambda p: (len(a[p][1]), -p))
        if v['volumeId'] == EXAMPLE[0]:
            by_id = {d['id']: d for d in v['docs']}
            holder = {i: d['id'] for d in v['docs'] for (_, i) in d['pbs']}
            kc, ic = ac.get(EXAMPLE[1], ('none', [])); kf, idf = a.get(EXAMPLE[1], ('none', []))
            example = (kc, ic, kf, len(idf), [(i, len(by_id[i]['pbs']), by_id[i]['start'], holder.get(by_id[i]['start'][1]),
                                              i in idf) for i in ic])
        row = [v['volumeId'], len(a.get(1, ('none', []))[1]), len(ac.get(1, ('none', []))[1]), most, len(a[most][1])]
        if SCAN:
            sc = json.load(open(os.path.join(SCAN, fn)))
            if 'pbs_outside' not in sc: sys.exit('%s has no pbs_outside: re-run scan_corpus.py' % SCAN)
            if any('head_at' not in d for d in sc['docs']): sys.exit('%s has no head_at: re-run scan_corpus.py' % SCAN)
            row += [sc['pbs_outside'].count('1'), sum(1 for d in sc['docs'] if '1' in d['pbs'])]
            inside_rows.append((v['volumeId'], sum(d['pbs'].count('1') for d in sc['docs']),
                                sum(d['pbs'][:d['head_at']].count('1') for d in sc['docs'] if d['head_at'] is not None),
                                sum(d['pbs'].count('1') for d in sc['docs'] if d['head_at'] is None)))
        perdoc_rows.append(row)
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
print('printed-volume pages by how many ASTs they name (F):', dict(sorted(names.items())))
print('the per-document gate (one start in four restarts the numbering): the printed volume restarting')
print('  most often %s, %d of %d; counting every row with a page, a section by its breaks, %s, %d of %d'
      % (top_rate[3], top_rate[1], top_rate[2], top_every[3], top_every[1], top_every[2]))
print('per-document volumes, documents with no break of their own:', dict(sorted(breakless.items())))
print('volumes that number pages per document: page 1 under F (every document printed on a page 1),')
print('what the committed rule C listed there, and the page naming the most'
      + (';\n  then page-1 breaks outside every document div, and documents holding one of their own' if SCAN else ''))
for r in perdoc_rows:
    print('  %-18s p.1 F %4d  C %4d   most: p.%d, %d' % tuple(r[:5])
          + ('   page-1 breaks outside %4d, documents with one %4d' % tuple(r[5:]) if SCAN else ''))
if example:
    kc, ic, kf, nf, held = example
    print('%s p.%d: C %s %s, F %s %d documents' % (EXAMPLE[0], EXAMPLE[1], kc, ic, kf, nf))
    for (i, nbreaks, start, holder, in_f) in held:
        print('  %s: %d breaks of its own, start %s held by %s; among F\'s: %s' % (i, nbreaks, start, holder, in_f))
if SCAN:
    print('per-document volumes, page-1 breaks inside document divs: all, those before their document\'s')
    print('  own <head> has closed (or inside it), and those in a document with no <head>')
    for r in inside_rows:
        print('  %-18s %4d   before the heading %4d   no heading %4d' % r)
    outside = arabic = volumes = 0
    for fn in sorted(f for f in os.listdir(SCAN) if f.endswith('.json')):
        sc = json.load(open(os.path.join(SCAN, fn)))
        if ns.micro(sc): continue
        volumes += 1; outside += len(sc['pbs_outside'])
        arabic += sum(1 for n in sc['pbs_outside'] if ns.DIG.match(n))
    print('breaks outside every document div, in the %d volumes that are not microfiche supplements: %d, %d of them arabic'
          % (volumes, outside, arabic))
