#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 lane P: one SAX pass over the manifest volumes of the local corpus, mirroring the event
order Foundation's XMLParser gives TEIParserDelegate, writing per-volume JSON the measurement
scripts read (measure_rules.py, measure_xrefs.py, count_brackets.py, inspect_gaps.py,
list_pagination_defects.py, and xrefs_f.py for the references and dates).

Records, per <div type="document"> (document divs ONLY — not the prose sections the parser also
promotes to quasi-documents; replica.py records those):
  start      - the @n of the last <pb> seen before the document's first non-whitespace character
               data: the page in effect when its first printed text begins (the break before the
               div when one sits between documents or inside the previous one; a <pb> inside the
               div, before any text, when the document opens on a fresh page)
  start_fc   - M2's variant: the break before the div, unless the div's FIRST CHILD element is a
               <pb> with no text before it (for comparison only)
  pbs        - the @n of every <pb> inside the div (not inside a nested document div), in order
  date       - frus:doc-dateTime-min
and, per <ref target="#pg_N"> inside a document div: the source document, N's raw text, and the
text of the innermost enclosing <note> (or '' when the ref is in running text).

Read-only over the corpus. Stdlib only (macOS's bundled python3).

Usage: scan_corpus.py OUT_DIR
Env:   VOLUMES_DIR  the corpus volumes (default ~/Development/frus/volumes)
       MANIFEST     the app manifest (default FRUSExplorer/Resources/manifest.json in this repo)
"""
import json, os, sys, xml.sax

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
V = os.environ.get('VOLUMES_DIR', os.path.expanduser('~/Development/frus/volumes'))
MANIFEST = os.environ.get('MANIFEST', os.path.join(REPO, 'FRUSExplorer', 'Resources', 'manifest.json'))
if len(sys.argv) != 2:
    sys.exit('usage: scan_corpus.py OUT_DIR')
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
man = json.load(open(MANIFEST))

class H(xml.sax.ContentHandler):
    def __init__(self):
        self.stack = []          # element names
        self.docs = []
        self.doc_stack = []      # open document records
        self.awaiting = []       # document records with no printed text yet
        self.last_pb = None
        self.notes = []          # open note text accumulators: [list_of_str, [ref records]]
        self.refs = []
        self.pb_in_note = 0
        self.pb_total = 0
        self.fc_pending = []     # document records whose first child element has not been seen
    def startElement(self, name, attrs):
        local = name.split(':')[-1]
        for d in self.fc_pending:
            # first child element of that div
            if local == 'pb' and not d['text_seen_fc']:
                d['start_fc'] = attrs.get('n', '').strip()
        self.fc_pending = []
        if local == 'div' and attrs.get('type') == 'document':
            d = {'id': attrs.get('xml:id', ''), 'start': self.last_pb, 'start_fc': self.last_pb,
                 'pbs': [], 'date': attrs.get('frus:doc-dateTime-min', '') or '',
                 'subtype': attrs.get('subtype', ''), 'text_seen_fc': False,
                 'nested': bool(self.doc_stack)}
            self.docs.append(d); self.doc_stack.append(d); self.awaiting.append(d)
            self.fc_pending = [d]
        elif local == 'pb':
            n = attrs.get('n', '').strip()
            self.last_pb = n
            self.pb_total += 1
            if self.notes: self.pb_in_note += 1
            for d in self.awaiting: d['start'] = n
            if self.doc_stack: self.doc_stack[-1]['pbs'].append(n)
        elif local == 'note':
            self.notes.append([[], []])
        elif local == 'ref':
            t = attrs.get('target', '')
            if t.startswith('#pg_') and self.doc_stack:
                r = {'src': self.doc_stack[-1]['id'], 'n': t[4:], 'note': None}
                self.refs.append(r)
                if self.notes: self.notes[-1][1].append(r)
                else: r['note'] = ''
        self.stack.append(local)
    def endElement(self, name):
        local = self.stack.pop()
        self.fc_pending = []
        if local == 'div':
            # a document div closes when the innermost open document's depth matches
            if self.doc_stack and self.doc_stack[-1].get('_depth') == len(self.stack):
                d = self.doc_stack.pop()
                if d in self.awaiting: self.awaiting.remove(d)
        elif local == 'note':
            texts, refs = self.notes.pop()
            text = ' '.join(''.join(texts).split())
            for r in refs: r['note'] = text
            if self.notes: self.notes[-1][0].append(''.join(texts))
    def characters(self, content):
        if content.strip():
            self.awaiting = []
            for d in self.doc_stack: d['text_seen_fc'] = True
        if self.notes: self.notes[-1][0].append(content)

class H2(H):
    # records each document div's stack depth so endElement can match it
    def startElement(self, name, attrs):
        local = name.split(':')[-1]
        depth = len(self.stack)
        H.startElement(self, name, attrs)
        if local == 'div' and attrs.get('type') == 'document':
            self.docs[-1]['_depth'] = depth

done = 0
missing = []
for e in man:
    p = os.path.join(V, e['filename'])
    if not os.path.exists(p):
        missing.append(e['filename']); continue
    h = H2()
    parser = xml.sax.make_parser()
    parser.setFeature(xml.sax.handler.feature_namespaces, False)
    parser.setContentHandler(h)
    parser.parse(p)
    for d in h.docs:
        d.pop('_depth', None); d.pop('text_seen_fc', None)
    json.dump({'volumeId': e['volumeId'], 'title': e['title'], 'subseries': e['subseries'],
               'docs': h.docs, 'refs': h.refs, 'pb_total': h.pb_total, 'pb_in_note': h.pb_in_note},
              open(os.path.join(OUT, e['volumeId'] + '.json'), 'w'))
    done += 1
print('volumes scanned:', done)
if missing:
    print('manifest volumes missing from %s: %d (first: %s)' % (V, len(missing), ', '.join(missing[:5])))
if done == 0:
    sys.exit('scanned nothing: is VOLUMES_DIR right?')
