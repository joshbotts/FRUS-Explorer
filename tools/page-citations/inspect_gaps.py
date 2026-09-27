#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 lane P: who the new rule cannot place (no recorded arabic start, no own arabic break),
and who falls back (own breaks, but no usable start), in the 533 printed volumes. Uses
measure_rules.py's rule functions.

Usage: inspect_gaps.py SCAN_DIR   (scan_corpus.py's output)
"""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_rules import ar, micro, PER_DOCUMENT, new_spans, old_printed, scan_volumes

if len(sys.argv) != 2:
    sys.exit('usage: inspect_gaps.py SCAN_DIR')
cnt = collections.Counter(); ex = collections.defaultdict(list); vols = collections.Counter()
for fn, v in scan_volumes(sys.argv[1]):
    if micro(v) or v['volumeId'] in PER_DOCUMENT: continue
    docs = v['docs']
    for k, d in enumerate(docs):
        s, cert, poss = new_spans(d)
        if cert is None:
            key = 'unplaced: start=%s' % ('none' if d['start'] is None else 'non-arabic' if ar(d['start']) is None else 'arabic?')
            cnt[key] += 1; vols[v['volumeId']] += 1
            if old_printed(k, docs) is not None: cnt[key + ', old placed'] += 1
            if len(ex[key]) < 12: ex[key].append((v['volumeId'], d['id'], d['start'], d['pbs'][:3], old_printed(k, docs)))
        elif s is None:
            key = 'fallback: start=%s' % ('none' if d['start'] is None else 'non-arabic' if ar(d['start']) is None else 'restart (own break below start)')
            cnt[key] += 1
            if len(ex[key]) < 12: ex[key].append((v['volumeId'], d['id'], d['start'], d['pbs'][:4]))
for k in sorted(cnt): print('%7d  %s' % (cnt[k], k))
print('volumes with unplaced docs:', len(vols), vols.most_common(12))
for k, xs in ex.items():
    print(k)
    for x in xs: print('   ', x)
