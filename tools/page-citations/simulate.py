#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 review round 1: the committed page rule (C) against the round-1 fix (F), over the
replica's emission (replica.py: documents, editorial notes and promoted quasi-documents, in
emission order).

  C: a start row for every emitted AST; "[N]" read as page N whatever its id.
  F: a start row for documents and editorial notes only; "[N]" read as page N only when the
     break's xml:id is "pg_N"; a volume numbering its pages per document (at least one document
     in four restarts the numbering) places a document by a start only when that start is page 1,
     and answers a page with every document certainly printed on it, never as one document.
     Per-document = at least one in four of the documents with a recorded start restarts.

F is the rule the app ships (`PageSpanResolver` 2.0 after review round 1). The rule functions
below (page, rows, per_document, spans, lookup) are imported by simulate2.py, quasi_starts.py,
rules_f.py, xrefs_f.py, sections_by_volume.py and brackets.py, so every round-1 figure is measured
under one copy of the rule.

Usage: simulate.py REPLICA_DIR   (replica.py's output)
"""
import json, os, re, sys, collections
DIG = re.compile(r'^\s*(\d+)\s*$'); BR = re.compile(r'^\s*\[(\d+)\]\s*$')
def micro(v): return 'msupp' in v['volumeId'].lower() or 'microfiche' in v['title'].lower()
def real(d): return d['kind'] in ('document', 'editorialNote')

def page(pb, regime):
    n, i = pb
    m = DIG.match(n)
    if m: return int(m.group(1))
    m = BR.match(n)
    if m:
        if regime == 'C' or i == 'pg_' + m.group(1): return int(m.group(1))
    return None

def rows(docs, regime):
    out = []  # [(id, kind, start, breaks)]
    for d in docs:
        s = None
        if d['start'] is not None and (regime == 'C' or real(d)):
            s = page(d['start'], regime)
        b = [p for p in (page(x, regime) for x in d['pbs']) if p is not None]
        if s is None and not b: continue   # no arabic row: not in the lookup at all
        out.append({'id': d['id'], 'kind': d['kind'], 'start': s, 'breaks': b})
    return out

def per_document(table):
    prev = None; restarts = 0; placed = 0
    for d in table:
        if d['start'] is None: continue   # documents with a recorded start only (round 1)
        pages = [d['start']] + d['breaks']
        placed += 1; r = False
        for p in pages:
            if prev is not None and p < prev: r = True
            prev = p
        restarts += r
    return placed > 0 and restarts * 4 >= placed, restarts, placed

def spans(d, perdoc):
    s, b = d['start'], d['breaks']
    placing = s if (s is not None and all(x >= s for x in b) and (not perdoc or s == 1)) else None
    if placing is not None:
        cert = (placing, max([placing] + b))
    elif b:
        cert = (min(b), max(b))
    else:
        cert = None
    if cert is None: poss = None
    elif placing is None and cert[0] > 1: poss = (cert[0] - 1, cert[1])
    else: poss = cert
    return placing, cert, poss

def lookup(p, table, sp, perdoc, regime):
    if regime == 'F' and perdoc:
        pr = [d['id'] for d in table if sp[d['id']][1] and sp[d['id']][1][0] <= p <= sp[d['id']][1][1]]
        return ('perdoc', pr) if pr else ('none', [])
    b = [d['id'] for d in table if sp[d['id']][0] == p]
    if b: return ('begins', b)
    pr = [d['id'] for d in table if sp[d['id']][1] and sp[d['id']][1][0] <= p <= sp[d['id']][1][1]]
    return ('printed', pr) if pr else ('none', [])

def replica_volumes(R):
    """Yields each replica volume in filename order; exits when the directory holds none."""
    names = sorted(fn for fn in os.listdir(R) if fn.endswith('.json'))
    if not names:
        sys.exit('no replica volumes in %s: run replica.py first' % R)
    for fn in names:
        yield fn, json.load(open(os.path.join(R, fn)))

def main(R):
    C = collections.defaultdict(collections.Counter); EX = collections.defaultdict(list)
    flagged = []
    for fn, v in replica_volumes(R):
        vid = v['volumeId']
        if micro(v): continue
        kinds = {d['id']: d['kind'] for d in v['docs']}
        res = {}
        for regime in ('C', 'F'):
            table = rows(v['docs'], regime)
            pd, restarts, placed = per_document(table)
            if regime == 'F' and pd: flagged.append((vid, restarts, placed))
            # C never detects; its spans ignore the per-document rule
            sp = {d['id']: spans(d, pd if regime == 'F' else False) for d in table}
            pages = set()
            for d in table:
                pages.update(d['breaks'])
                if d['start'] is not None: pages.add(d['start'])
            ans = {p: lookup(p, table, sp, pd, regime) for p in pages}
            res[regime] = (table, sp, ans, pd)
        g = 'perdoc' if res['F'][3] else 'printed'
        c = C[g]; c['volumes'] += 1
        tC, spC, aC, _ = res['C']; tF, spF, aF, _ = res['F']
        for regime, (t, sp, a, pd) in res.items():
            for p, (kind, ids) in a.items():
                c['%s pages' % regime] += 1
                if ids and not real({'kind': kinds[ids[0]]}): c['%s pages: first answer a quasi-document' % regime] += 1
                if any(not real({'kind': kinds[i]}) for i in ids): c['%s pages: a quasi-document among the answers' % regime] += 1
                one = len(ids) == 1 and kind != 'perdoc'
                c['%s pages: %s, %s' % (regime, kind, 'one' if one else ('none' if not ids else 'several'))] += 1
        # pages whose first answer moved
        for p in set(aC) | set(aF):
            a1 = aC.get(p, ('none', [])); a2 = aF.get(p, ('none', []))
            f1 = a1[1][0] if a1[1] else None; f2 = a2[1][0] if a2[1] else None
            if f1 != f2:
                c['C->F: first answer differs'] += 1
                key = '%s->%s' % ('quasi' if f1 and not real({'kind': kinds[f1]}) else ('doc' if f1 else 'none'),
                                  'quasi' if f2 and not real({'kind': kinds[f2]}) else ('doc' if f2 else 'none'))
                c['C->F: first answer ' + key] += 1
                if len(EX[g + key]) < 6: EX[g + key].append((vid, p, a1[0], a1[1][:3], a2[0], a2[1][:3]))
        # references: same-volume #pg_N (digits) in any emitted AST
        for d in v['docs']:
            for r in d['refs']:
                if not r.isdigit(): continue
                n = int(r)
                for regime, (t, sp, a, pd) in res.items():
                    ans = a.get(n) or lookup(n, t, sp, pd, regime)
                    tgt = ans[1][0] if ans[1] else None
                    if tgt is None: c['%s refs: unresolved' % regime] += 1
                    elif not real({'kind': kinds[tgt]}): c['%s refs: stored against a quasi-document' % regime] += 1
                    else: c['%s refs: stored against a document' % regime] += 1
        # the page check over real documents
        for d in v['docs']:
            if not real(d): continue
            pc = spC.get(d['id']); pf = spF.get(d['id'])
            oc = pc[2] if pc else None; of = pf[2] if pf else None
            if oc == of: c['check: same'] += 1
            elif oc is None: c['check: F places, C nil'] += 1
            elif of is None:
                c['check: C places, F nil'] += 1
                if len(EX[g + 'check-unplaced']) < 6: EX[g + 'check-unplaced'].append((vid, d['id'], oc))
            else:
                c['check: both place, differ'] += 1
                if len(EX[g + 'check-differ']) < 6: EX[g + 'check-differ'].append((vid, d['id'], oc, of))
    for g in C:
        print(g)
        for k in sorted(C[g]): print('  %8d  %s' % (C[g][k], k))
    print('flagged per-document:', len(flagged))
    for f in flagged: print('   ', f)
    for k, xs in EX.items():
        print(k)
        for x in xs: print('   ', x)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('usage: simulate.py REPLICA_DIR')
    main(sys.argv[1])
