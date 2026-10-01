#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1503 review round 1: a SAX replica of TEIParserDelegate's full-volume emission.

Where scan_corpus.py records `div[@type="document"]` alone, this records everything the parser
emits as an AST, in emission order: documents (type="document"), legacy editorial notes
(type="editorialNote") and the quasi-documents it promotes (prose-only structural sections). Per
emitted AST: its kind, id, start page (@n and @xml:id of the last <pb> before its first printed
text), the <pb>s its nodes hold and the #pg_ refs its nodes hold. simulate.py, simulate2.py,
quasi_starts.py, rules_f.py, xrefs_f.py, brackets.py, sections_by_volume.py and v63.py read its
output.

The emission is the parser's as of index v63 (#1510, owner decision D1) unless RULE=v62 is set: a
compilation, chapter or subchapter holding a promoted section (a CONTAINER) is not emitted when it
holds nothing of its own but a heading and page breaks, and keeps only the breaks within its own
text when it has text; the breaks either leaves are given, ahead of its own, to the emitted AST
whose div opens first after the break when that AST is a section (`carried`, which counts them
among `pbs` too), and dropped when it is a document or an editorial note, whose start page is that
break or a later one. Each section emitted under v63 also records `carried`, the number of its
`pbs` a container gave it, and each volume `carried_to`, how many carried breaks went to a section,
a document (dropped) or nothing. RULE=v62 reproduces the emission every figure before v63 was measured
over, byte for byte.

Read-only over the corpus. Stdlib only (macOS's bundled python3).

Usage: replica.py OUT_DIR [VOLUME_ID ...]   (volume ids restrict the run; default every volume)
Env:   VOLUMES_DIR  the corpus volumes (default ~/Development/frus/volumes)
       MANIFEST     the app manifest (default FRUSExplorer/Resources/manifest.json in this repo)
       RULE         v63 (default, the shipped parser) or v62 (before #1510)
"""
import json, os, sys, xml.sax

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
V = os.environ.get('VOLUMES_DIR', os.path.expanduser('~/Development/frus/volumes'))
MANIFEST = os.environ.get('MANIFEST', os.path.join(REPO, 'FRUSExplorer', 'Resources', 'manifest.json'))
RULE = os.environ.get('RULE', 'v63')
if RULE not in ('v62', 'v63'):
    sys.exit('RULE must be v62 or v63')
if len(sys.argv) < 2:
    sys.exit('usage: replica.py OUT_DIR [VOLUME_ID ...]')
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
man = json.load(open(MANIFEST))

STRUCTURAL = {"compilation", "chapter", "subchapter", "appendix", "preface", "intro", "introduction",
              "errata", "index", "foreword", "prefatoryNote", "sources", "persons", "terms"}
PROMOTABLE = {"compilation", "chapter", "subchapter", "appendix", "preface", "intro", "introduction",
              "errata", "foreword", "prefatoryNote", "terms", "press-release", "volume-summary",
              "about-frus-series", "historical-document"}
# TEIParserDelegate.containerKindsLeftOut (#1510)
CONTAINERS = {"compilation", "chapter", "subchapter"}
SUPPRESSED = {"teiHeader", "fileDesc", "encodingDesc", "profileDesc", "revisionDesc", "titleStmt",
              "publicationStmt", "sourceDesc", "textClass"}

def kind_of(t, st, xid):
    if t == 'section':
        if st == 'index':
            x = xid.lower()
            if x in ('persons', 'persname', 'listofpersons'): return 'persons'
            if x in ('terms', 'abbreviations', 'listofabbreviations'): return 'terms'
            return 'index'
        if st: return st
        if xid: return xid.lower()
        return 'section'
    if t == 'toc': return 'table-of-contents'
    return t if t in STRUCTURAL else None

def transparent(name, a):
    if name in ('TEI', 'text', 'body', 'front', 'back', 'group'): return True
    if name == 'div': return a.get('type', '') not in ('document', 'editorialNote')
    if name == 'note':
        if a.get('type') == 'source': return False
        return a.get('rend') == 'inline'
    return False

class F:
    # kids: the frame's children as the parser holds them — ('pb', pb, divs opened before it),
    # ('head',) or ('other',) — for the v63 container rule (ParseFrame.children and
    # directBreakOpenCounts). holds: ParseFrame.holdsPromotedSection. open: ParseFrame.openIndex.
    __slots__ = ('name', 'a', 'pbs', 'refs', 'nonempty', 'hcd', 'start', 'text', 'kids', 'holds', 'open')
    def __init__(self, name, a):
        self.name = name; self.a = a; self.pbs = []; self.refs = []; self.nonempty = False
        self.hcd = False; self.start = None; self.text = False
        self.kids = []; self.holds = False; self.open = -1

class H(xml.sax.ContentHandler):
    def __init__(self):
        self.stack = []; self.awaiting = []; self.last = None; self.docs = []
        self.opened = 0; self.carried = []   # [(divs opened before the break, pb)]
    def flush(self):
        if self.stack and self.stack[-1].text:
            self.stack[-1].nonempty = True; self.stack[-1].text = False
            self.stack[-1].kids.append(('other',))
    def emit(self, f, rec):
        rec['_open'] = f.open
        self.docs.append(rec)
    def startElement(self, name, attrs):
        self.flush()
        a = dict(attrs)
        if name == 'pb':
            pb = (a.get('n', ''), a.get('xml:id', ''))
            self.last = pb
            for i in self.awaiting: self.stack[i].start = pb
        f = F(name, a)
        if name == 'div':
            f.start = self.last
            self.awaiting.append(len(self.stack))
            f.open = self.opened; self.opened += 1
        self.stack.append(f)
    def characters(self, c):
        if not self.stack: return
        if c.strip():
            self.stack[-1].text = True
            if self.awaiting: self.awaiting = []
    def endElement(self, name):
        f = self.stack.pop()
        if self.awaiting: self.awaiting = [i for i in self.awaiting if i < len(self.stack)]
        if f.text: f.nonempty = True; f.kids.append(('other',))
        a = f.a
        parent = self.stack[-1] if self.stack else None
        xid = a.get('xml:id', a.get('id', ''))
        if name == 'div' and a.get('type') == 'document':
            self.emit(f, {'kind': 'document', 'subtype': a.get('subtype', ''), 'id': xid,
                          'start': f.start, 'pbs': f.pbs, 'refs': f.refs})
            if parent: parent.hcd = True
            return
        if name == 'div' and a.get('type') == 'editorialNote':
            self.emit(f, {'kind': 'editorialNote', 'subtype': '', 'id': xid,
                          'start': f.start, 'pbs': f.pbs, 'refs': f.refs})
            if parent: parent.hcd = True
            return
        if name == 'div':
            k = kind_of(a.get('type', ''), a.get('subtype', ''), xid)
            if k in PROMOTABLE and not f.hcd and xid and f.nonempty:
                pbs = f.pbs
                if RULE == 'v63' and f.holds and k in CONTAINERS:
                    own = [(kid[2], kid[1]) for kid in f.kids if kid[0] == 'pb']
                    if all(kid[0] in ('pb', 'head') for kid in f.kids):
                        self.carried += own
                        if parent: parent.holds = True
                        return
                    trailing = 0
                    for kid in reversed(f.kids):
                        if kid[0] != 'pb': break
                        trailing += 1
                    if trailing:
                        self.carried += own[-trailing:]
                        pbs = pbs[:-trailing]
                self.emit(f, {'kind': 'quasi:' + k, 'subtype': a.get('subtype', ''), 'id': xid,
                              'start': f.start, 'pbs': pbs, 'refs': f.refs})
                if parent: parent.holds = True
                return
        if transparent(name, a):
            if parent:
                if f.hcd: parent.hcd = True
                if f.holds: parent.holds = True
                parent.pbs += f.pbs; parent.refs += f.refs; parent.kids += f.kids
                if f.nonempty: parent.nonempty = True
            return
        if name in SUPPRESSED: return
        # buildNode: a node carrying its children
        if parent:
            if name == 'pb':
                pb = (a.get('n', ''), a.get('xml:id', ''))
                parent.pbs.append(pb); parent.kids.append(('pb', pb, self.opened))
            elif name == 'head': parent.kids.append(('head',))
            else: parent.kids.append(('other',))
            parent.pbs += f.pbs
            if name == 'ref':
                t = a.get('target', '')
                if t.startswith('#pg_'): parent.refs.append(t[4:])
            parent.refs += f.refs
            parent.nonempty = True
    def finish(self):
        # TEIParserDelegate.finishParse: each carried break to the AST whose div opens first after it.
        given = {}
        self.carried_to = {'section': 0, 'document': 0, 'none': 0}
        for before, pb in sorted(self.carried, key=lambda c: c[0]):   # stable, as the parser sorts
            later = [d for d in self.docs if d['_open'] >= before]
            if not later:
                self.carried_to['none'] += 1; continue
            target = min(later, key=lambda d: d['_open'])
            if target['kind'].startswith('quasi:'):
                given.setdefault(id(target), (target, []))[1].append(pb)
                self.carried_to['section'] += 1
            else:
                self.carried_to['document'] += 1
        for target, pbs in given.values():
            target['pbs'] = pbs + target['pbs']
            target['carried'] = len(pbs)
        for d in self.docs: d.pop('_open', None)

done = 0
only = set(sys.argv[2:])
for e in man:
    if only and e['volumeId'] not in only: continue
    p = os.path.join(V, e['filename'])
    if not os.path.exists(p): continue
    h = H()
    parser = xml.sax.make_parser()
    parser.setFeature(xml.sax.handler.feature_namespaces, False)
    parser.setContentHandler(h)
    parser.parse(p)
    h.finish()
    out = {'volumeId': e['volumeId'], 'title': e['title'], 'docs': h.docs}
    if RULE == 'v63': out['carried_to'] = h.carried_to
    json.dump(out, open(os.path.join(OUT, e['volumeId'] + '.json'), 'w'))
    done += 1
print('volumes', done)
if done == 0:
    sys.exit('replicated nothing: is VOLUMES_DIR right?')
