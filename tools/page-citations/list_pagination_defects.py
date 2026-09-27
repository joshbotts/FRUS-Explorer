#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 lane P: the pagination defects the new start-page rule meets in the 533 printed volumes
(not microfiche, not per-document), for #1309's next report.

BACKWARDS - a document's own arabic break is below the page it begins on (the break before its
            first text): pagination runs backwards across the boundary, so a break is out of
            order or misnumbered. (frus1948v04 d192/d193: d192 holds pb 270, d193 then pb 269.)

(The lane's plan also named a GAP shape — consecutive breaks that skip a page number, which a
missing <pb> leaves, as frus1902app1's missing pb 327 does — but plates and maps skip numbers
legitimately, and this script reports the BACKWARDS shape only.)

Usage: list_pagination_defects.py SCAN_DIR   (scan_corpus.py's output)
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_rules import PER_DOCUMENT, scan_volumes

if len(sys.argv) != 2:
    sys.exit('usage: list_pagination_defects.py SCAN_DIR')
def ar(x):
    if x is None: return None
    m = re.match(r'^\[?(\d+)\]?$', x)
    return int(m.group(1)) if m else None
back = []
for fn, v in scan_volumes(sys.argv[1]):
    vid = v['volumeId']
    if 'msupp' in vid.lower() or 'microfiche' in v['title'].lower() or vid in PER_DOCUMENT: continue
    for d in v['docs']:
        s = ar(d['start']); b = [ar(x) for x in d['pbs'] if ar(x) is not None]
        if s is not None and b and min(b) < s:
            back.append((vid, d['id'], d['start'], d['pbs'][:4]))
print('BACKWARDS: %d documents in %d volumes' % (len(back), len({b[0] for b in back})))
for b in back: print('  %-16s %-7s begins on %-6s own breaks %s' % b)
