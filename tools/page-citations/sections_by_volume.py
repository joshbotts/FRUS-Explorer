#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 review round 1, by volume: the page numbers of the printed volumes that the round-1 rule
(F, simulate.py) answers with a promoted section, and how many of those answer with several
sections at once. simulate.py states the total ("F pages: a quasi-document among the answers");
this splits it by volume, which is where `frus1919Parisv13` stands out: its compilations are
indexed beside the chapters they hold (a promoted chapter does not mark its parent as holding
documents), so a page there answers with several sections at once: a compilation with a chapter
or subchapter it holds, or a chapter with its subchapter. The last column splits each volume's
several-section pages by the kinds of section among the answers.

(Added for #1512: the round-1 plan entry states 926 of 1,182 and 740, and none of the lane's
recorded outputs carries the split, so no committed script would otherwise reproduce it.)

Usage: sections_by_volume.py REPLICA_DIR   (replica.py's output)
"""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulate as ns

if len(sys.argv) != 2:
    sys.exit('usage: sections_by_volume.py REPLICA_DIR')
with_section = collections.Counter()      # pages answered with at least one section, by volume
several = collections.Counter()           # ... with two or more sections among the answers
kinds_seen = collections.defaultdict(collections.Counter)
for fn, v in ns.replica_volumes(sys.argv[1]):
    if ns.micro(v): continue
    kinds = {d['id']: d['kind'] for d in v['docs']}
    t = ns.rows(v['docs'], 'F'); pd = ns.per_document(t)[0]
    if pd: continue                      # the printed volumes only, as simulate.py's 'printed'
    sp = {d['id']: ns.spans(d, pd) for d in t}
    pages = set()
    for d in t:
        pages.update(d['breaks'])
        if d['start'] is not None: pages.add(d['start'])
    for p in pages:
        kind, ids = ns.lookup(p, t, sp, pd, 'F')
        q = [i for i in ids if not ns.real({'kind': kinds[i]})]
        if not q: continue
        with_section[v['volumeId']] += 1
        if len(q) > 1:
            several[v['volumeId']] += 1
            kinds_seen[v['volumeId']][' + '.join(sorted({kinds[i] for i in q}))] += 1
print('printed-volume pages answered with a section: %d in %d volumes'
      % (sum(with_section.values()), len(with_section)))
print('  of them answered with several sections at once: %d in %d volumes'
      % (sum(several.values()), len(several)))
for vid, n in with_section.most_common(12):
    print('  %-20s %5d pages with a section, %5d with several   %s'
          % (vid, n, several[vid], dict(kinds_seen[vid].most_common())))
