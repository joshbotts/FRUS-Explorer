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
  head_at    - how many of those pbs the div held when its own <head> (a child of the div) closed,
               or null when it has none: pbs[head_at:] follow the heading (added for #1512 review
               round 2: rules_f.py counts the per-document volumes' page-1 breaks by it)
  date       - frus:doc-dateTime-min
  n          - the div's @n, its printed document number (added for #1509)
  date_win   - the raw <date> attribute IndexingPipeline's `winningMinDateAttribute` takes for the
               document's day — a dateline <date>'s @when, else its @from, else its @notBefore, else
               the first @when outside notes — or null (added for #1509: with `date`, it gives the day
               `document_dates.date_iso` stores and its precision; v63.py reads both)
and, per <ref target="#pg_N"> inside a document div: the source document, N's raw text, the
text of the innermost enclosing <note> (or '' when the ref is in running text), and the ref's own
text (`text`) with where it starts and ends in the note's text (`at`, `end`; all three added for
#1509: v63.py's `nearest_day` variant reads `at`, and `text` and `end` were read only by the lane's
exploratory passes, which were not committed); and, per volume,
pbs_outside, the @n of every <pb> outside every document div, in order (added for #1512 review
round 1: rules_f.py counts the per-document volumes' page-1 breaks written between documents).

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
        self.pbs_outside = []    # the @n of each <pb> outside every document div
        self.fc_pending = []     # document records whose first child element has not been seen
        self.open_refs = []      # #pg_ ref records whose element is still open (their text so far)
        self.dateline = 0        # open <dateline> elements (#1509: the day the index stores)
    def startElement(self, name, attrs):
        local = name.split(':')[-1]
        for d in self.fc_pending:
            # first child element of that div
            if local == 'pb' and not d['text_seen_fc']:
                d['start_fc'] = attrs.get('n', '').strip()
        self.fc_pending = []
        if local == 'div' and attrs.get('type') == 'document':
            d = {'id': attrs.get('xml:id', ''), 'start': self.last_pb, 'start_fc': self.last_pb,
                 'pbs': [], 'head_at': None, 'date': attrs.get('frus:doc-dateTime-min', '') or '',
                 'subtype': attrs.get('subtype', ''), 'text_seen_fc': False,
                 'nested': bool(self.doc_stack), 'n': attrs.get('n', '').strip(), '_dates': []}
            self.docs.append(d); self.doc_stack.append(d); self.awaiting.append(d)
            self.fc_pending = [d]
        elif local == 'pb':
            n = attrs.get('n', '').strip()
            self.last_pb = n
            self.pb_total += 1
            if self.notes: self.pb_in_note += 1
            for d in self.awaiting: d['start'] = n
            if self.doc_stack: self.doc_stack[-1]['pbs'].append(n)
            else: self.pbs_outside.append(n)
        elif local == 'note':
            self.notes.append([[], []])
        elif local == 'dateline':
            self.dateline += 1
        elif local == 'date' and self.doc_stack and not self.notes:
            # IndexingPipeline.collectDateNodes skips footnotes; a dateline's dates rank first.
            self.doc_stack[-1]['_dates'].append((self.dateline > 0, attrs.get('when'),
                                                  attrs.get('from'), attrs.get('notBefore')))
        elif local == 'ref':
            t = attrs.get('target', '')
            if t.startswith('#pg_') and self.doc_stack:
                r = {'src': self.doc_stack[-1]['id'], 'n': t[4:], 'note': None, 'text': ''}
                self.refs.append(r)
                if self.notes:
                    self.notes[-1][1].append(r)
                    r['at'] = self.note_offset()
                else: r['note'] = ''
                self.open_refs.append((len(self.stack), r))
        self.stack.append(local)
    def endElement(self, name):
        local = self.stack.pop()
        self.fc_pending = []
        while self.open_refs and self.open_refs[-1][0] >= len(self.stack):
            r = self.open_refs.pop()[1]
            r['text'] = ' '.join(r['text'].split())
            if 'at' in r: r['end'] = self.note_offset()
        if local == 'dateline': self.dateline -= 1
        if local == 'div':
            # a document div closes when the innermost open document's depth matches
            if self.doc_stack and self.doc_stack[-1].get('_depth') == len(self.stack):
                d = self.doc_stack.pop()
                if d in self.awaiting: self.awaiting.remove(d)
        elif local == 'head':
            # the innermost open document's own heading: a child of its div, the first to close
            d = self.doc_stack[-1] if self.doc_stack else None
            if d is not None and d['head_at'] is None and d.get('_depth') == len(self.stack) - 1:
                d['head_at'] = len(d['pbs'])
        elif local == 'note':
            texts, refs = self.notes.pop()
            text = ' '.join(''.join(texts).split())
            for r in refs: r['note'] = text
            if self.notes: self.notes[-1][0].append(''.join(texts))
    def note_offset(self):
        # where the innermost open note's text has reached, in its whitespace-collapsed form: the
        # coordinates of `note` (#1509: v63.py's `nearest_day` reads the words before a ref, to `at`)
        return len(' '.join(''.join(self.notes[-1][0]).split()))
    def characters(self, content):
        if content.strip():
            self.awaiting = []
            for d in self.doc_stack: d['text_seen_fc'] = True
        if self.notes: self.notes[-1][0].append(content)
        for _, r in self.open_refs: r['text'] += content

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
        dates = d.pop('_dates', [])
        win = (next((w for dl, w, f, nb in dates if dl and w), None)
               or next((f for dl, w, f, nb in dates if dl and f), None)
               or next((nb for dl, w, f, nb in dates if dl and nb), None)
               or next((w for dl, w, f, nb in dates if w), None))
        d['date_win'] = win
    json.dump({'volumeId': e['volumeId'], 'title': e['title'], 'subseries': e['subseries'],
               'docs': h.docs, 'refs': h.refs, 'pb_total': h.pb_total, 'pb_in_note': h.pb_in_note,
               'pbs_outside': h.pbs_outside},
              open(os.path.join(OUT, e['volumeId'] + '.json'), 'w'))
    done += 1
print('volumes scanned:', done)
if missing:
    print('manifest volumes missing from %s: %d (first: %s)' % (V, len(missing), ', '.join(missing[:5])))
if done == 0:
    sys.exit('scanned nothing: is VOLUMES_DIR right?')
