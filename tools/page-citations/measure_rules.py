#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 lane P: the page-only lookup and the page check, old rule against new, over the scan
scan_corpus.py wrote (one SAX pass over the 553 manifest volumes at corpus 550a8c5c5).

OLD (v2 @ b192f8fc): page_ranges holds one row per <pb> INSIDE a document div, section_id = the
  document's id, so each document claims [min own arabic break, max own arabic break]; a page
  claimed by several is answered in Swift Dictionary order (arbitrary). printedPages: own breaks
  -> [max(F-1,1), L]; none -> [last break of the nearest earlier document with one, first break
  of the nearest later one - 1] (document order), nil when a side has none or the bound is empty.
NEW (the lane's rule, before review round 1): each document also records the page it BEGINS on -
  the page of the last <pb> before its first printed text (scan 'start'). A document is printed
  on [S, max(S, L)] when that start is arabic and no own arabic break lies below it; otherwise (no
  start, a non-arabic start, or a restart - an own break below the start) it falls back:
  certainly on [F, L], possibly on [max(F-1,1), L]. A page P resolves to the documents whose
  RECORDED start is P; when none begins there, to the documents certainly printed on P. Several
  -> ambiguous.

The scan holds document divs only, so these are the lane's figures; rules_f.py re-measures the
round-1 rule over the parser's whole emission (replica.py), and those are the figures the shipped
code states where the two differ. inspect_gaps.py imports the rule functions below.

Usage: measure_rules.py SCAN_DIR   (scan_corpus.py's output)
"""
import json, os, re, sys, collections
A = re.compile(r'^\d+$')
def ar(x): return int(x) if x is not None and A.match(x) else None
# The new rule also reads a page printed without its number, "[31]", as page 31 (as the index now
# stores it); the old rule's page_ranges held it as unparseable.
def ar_new(x):
    if x is None: return None
    m = re.match(r'^\[?(\d+)\]?$', x)
    return int(m.group(1)) if m and (x[0] == '[') == (x[-1] == ']') else None
def micro(v): return 'msupp' in v['volumeId'].lower() or 'microfiche' in v['title'].lower()
PER_DOCUMENT = {'frus1969-76ve01', 'frus1969-76ve02', 'frus1969-76ve03', 'frus1969-76ve04',
                'frus1969-76ve05p1', 'frus1969-76ve05p2', 'frus1969-76ve06', 'frus1969-76ve07',
                'frus1969-76ve08', 'frus1969-76ve10', 'frus1969-76ve12', 'frus1969-76ve13',
                'frus1969-76ve14p1', 'frus1969-76ve15p1', 'frus1981-88v16'}

def scan_volumes(S):
    """Yields each scanned volume in filename order; exits when the directory holds none."""
    names = sorted(fn for fn in os.listdir(S) if fn.endswith('.json'))
    if not names:
        sys.exit('no scanned volumes in %s: run scan_corpus.py first' % S)
    for fn in names:
        yield fn, json.load(open(os.path.join(S, fn)))

def new_spans(d):
    s = ar_new(d['start']); b = [ar_new(x) for x in d['pbs'] if ar_new(x) is not None]
    if s is not None and (not b or min(b) >= s):
        hi = max([s] + b)
        return (s, (s, hi), (s, hi))         # recorded start, certain, possible
    if b:
        f, l = min(b), max(b)
        return (None, (f, l), (f - 1 if f > 1 else f, l))
    return (None, None, None)

def new_lookup(page, table):
    begins = [i for (i, s, c, p) in table if s == page]
    if begins: return ('begins', begins)
    printed = [i for (i, s, c, p) in table if c and c[0] <= page <= c[1]]
    if printed: return ('printed', printed)
    return ('none', [])

def old_claims(page, docs):
    out = []
    for d in docs:
        b = [ar(x) for x in d['pbs'] if ar(x) is not None]
        if b and min(b) <= page <= max(b): out.append(d['id'])
    return out

def old_printed(k, docs):
    d = docs[k]
    own = [x for x in d['pbs']]
    if own:
        b = [ar(x) for x in own if ar(x) is not None]
        if not b: return None
        f, l = min(b), max(b)
        return (f - 1 if f > 1 else f, l)
    before = after = None
    for j in range(k - 1, -1, -1):
        if docs[j]['pbs']:
            before = ar(docs[j]['pbs'][-1]); break
    for j in range(k + 1, len(docs)):
        if docs[j]['pbs']:
            after = ar(docs[j]['pbs'][0]); break
    if before is None or after is None or before > after - 1: return None
    return (before, after - 1)

def main(S):
    C = collections.defaultdict(collections.Counter)
    begin_sizes = collections.defaultdict(collections.Counter)
    examples = collections.defaultdict(list)
    for fn, v in scan_volumes(S):
        vid = v['volumeId']
        if micro(v):
            C['microfiche (5), not looked up'][ 'volumes'] += 1
            continue
        g = 'per-document (15)' if vid in PER_DOCUMENT else 'printed (533)'
        docs = v['docs']
        table = [(d['id'],) + new_spans(d) for d in docs]
        c = C[g]
        c['volumes'] += 1
        c['document divs'] += len(docs)
        for d, t in zip(docs, table):
            s, cert, poss = t[1], t[2], t[3]
            c['docs: recorded arabic start'] += s is not None
            c['docs: start differs from M2 first-child variant'] += d['start'] != d['start_fc']
            c['docs: no own break'] += not d['pbs']
            if not d['pbs'] and s is not None: c['docs: no own break, recorded start'] += 1
            if cert is None: c['docs: nothing places it (new)'] += 1
            if s is None and cert is not None: c['docs: fallback span (no usable start)'] += 1
        # 1. a page-only citation of the page each document begins on
        for k, (d, t) in enumerate(zip(docs, table)):
            s = t[1]
            if s is None: continue
            kind, ids = new_lookup(s, table)
            if ids == [d['id']]: c['start page -> new: itself alone'] += 1
            elif d['id'] in ids: c['start page -> new: itself among several (ambiguous)'] += 1
            else:
                c['start page -> new: NOT itself'] += 1
                if len(examples['newnot']) < 10: examples['newnot'].append((vid, d['id'], s, kind, ids[:4]))
            old = old_claims(s, docs)
            if old == [d['id']]: c['start page -> old: itself'] += 1
            elif not old: c['start page -> old: none'] += 1
            elif len(old) > 1: c['start page -> old: several (arbitrary)'] += 1
            elif k > 0 and old[0] == docs[k - 1]['id']: c['start page -> old: the preceding document'] += 1
            else: c['start page -> old: an earlier document'] += 1
        # 2. every distinct arabic page a break in the volume carries
        pages = set()
        for d in docs:
            for x in d['pbs']:
                if ar_new(x) is not None: pages.add(ar_new(x))
            if ar_new(d['start']) is not None: pages.add(ar_new(d['start']))
        for p in sorted(pages):
            kind, ids = new_lookup(p, table)
            c['pages'] += 1
            if kind == 'none': c['pages -> new: none'] += 1
            else:
                c['pages -> new: %s, %s' % (kind, 'one' if len(ids) == 1 else 'several')] += 1
                if len(ids) > 1: begin_sizes[g][min(len(ids), 20)] += 1
            o = old_claims(p, docs)
            c['pages -> old: %s' % ('none' if not o else 'one' if len(o) == 1 else 'several')] += 1
        # 3. the page check: old bound vs new
        for k, (d, t) in enumerate(zip(docs, table)):
            o = old_printed(k, docs); n = t[3]
            if o is None and n is None: c['check: both nil'] += 1
            elif o is None: c['check: new places, old nil'] += 1
            elif n is None: c['check: old places, new nil'] += 1
            elif o == tuple(n): c['check: same range'] += 1
            else:
                c['check: range differs'] += 1
                if t[1] is not None and not (o[0] <= t[1] <= o[1]):
                    c['check: old range EXCLUDES the recorded start page'] += 1
                    if len(examples['oldexcl']) < 10: examples['oldexcl'].append((vid, d['id'], o, n))
                if n[1] - n[0] < o[1] - o[0]: c['check: new range narrower'] += 1

    for g in sorted(C):
        print(g)
        for k in sorted(C[g]):
            print('  %8d  %s' % (C[g][k], k))
    for g in sorted(begin_sizes):
        print('ambiguous page claimant counts,', g, dict(sorted(begin_sizes[g].items())))
    for k, xs in examples.items():
        print(k)
        for x in xs: print('   ', x)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('usage: measure_rules.py SCAN_DIR')
    main(sys.argv[1])
