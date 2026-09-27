#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 lane P: how the corpus spells its page numbers, and how many documents begin on a
bracketed arabic page ("[31]" - a page printed without its number, which PageNumber.parse read as
unparseable before #1503). Over the scan scan_corpus.py wrote.

Usage: count_brackets.py SCAN_DIR   (scan_corpus.py's output)
"""
import collections, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_rules import scan_volumes

if len(sys.argv) != 2:
    sys.exit('usage: count_brackets.py SCAN_DIR')
shape = collections.Counter(); vols = collections.Counter(); starts = collections.Counter()
ex = []
def kind(n):
    if n is None: return 'none'
    if re.match(r'^\d+$', n): return 'digits'
    if re.match(r'^\[\d+\]$', n): return '[digits]'
    if re.match(r'^\[?[ivxlcdmIVXLCDM]+\]?$', n): return 'roman'
    return 'other'
for fn, v in scan_volumes(sys.argv[1]):
    micro = 'msupp' in v['volumeId'].lower() or 'microfiche' in v['title'].lower()
    for d in v['docs']:
        for n in d['pbs']:
            k = kind(n); shape[k] += 1
            if k == '[digits]': vols[v['volumeId']] += 1
            if k == 'other' and len(ex) < 25: ex.append((v['volumeId'], d['id'], n))
        if not micro: starts[kind(d['start'])] += 1
print('page breaks inside document divs, by shape:', dict(shape))
print('volumes with [digits] breaks inside documents:', len(vols), vols.most_common(8))
print('document starts (548 non-microfiche volumes), by shape:', dict(starts))
print('other-shape examples:', ex)
