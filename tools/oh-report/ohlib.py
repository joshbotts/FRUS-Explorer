#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Shared readers for the Office of the Historian report (#1309).

Everything here is a BYTE scan of the TEI with comments blanked (offsets and line numbers are those
of the file on disk), plus one real parse (ElementTree) used only to prove a simulated repair still
yields well-formed XML. Standard library only, macOS's bundled python3.

    VOLUMES_DIR   the corpus' volumes/ directory (default ~/Development/frus/volumes)
"""
import bisect
import os
import re
import xml.etree.ElementTree as ET

VOLUMES_DIR = os.environ.get('VOLUMES_DIR', os.path.expanduser('~/Development/frus/volumes'))

_COMMENT = re.compile(rb'<!--.*?-->', re.S)
_ATTR = re.compile(rb'([\w:.-]+)\s*=\s*"([^"]*)"')
_DIV = re.compile(rb'<div\b([^>]*)>|</div\s*>', re.S)
_PB = re.compile(rb'<pb\b([^>]*?)/?>', re.S)
_HEAD = re.compile(rb'<head\b[^>]*>(.*?)</head>', re.S)
_NOTE = re.compile(rb'<note\b.*?</note>', re.S)
_TAG = re.compile(rb'<[^>]+>')
# The phrase-level elements of the corpus: one of these inside a word, or against a comma, adds no
# space to the text the file reads. Every other tag (<p>, <lb/>, <item>, <cell>, ...) separates words.
_INLINE_TAG = re.compile(rb'</?(?:hi|gloss|persName|placeName|orgName|name|date|ref|seg|term|del|title'
                         rb'|affiliation|unclear)\b[^>]*>')


def volume_files():
    """Every volumes/*.xml file name, sorted."""
    return sorted(f for f in os.listdir(VOLUMES_DIR) if f.endswith('.xml'))


def attrs(raw):
    """The attributes of one start tag's attribute text, as a str dict."""
    return {k.decode(): v.decode('utf-8', 'replace') for k, v in _ATTR.findall(raw)}


def plain(raw):
    """The text of a byte fragment as the file reads it, whitespace collapsed.

    A footnote and an inline tag leave nothing behind, so `D<hi>epartment</hi>` reads "Department" and
    `State,<gloss>NEA</gloss>` reads "State,NEA": a quote built from this holds no space the file
    lacks. Any other tag reads as a space.
    """
    text = _TAG.sub(b' ', _INLINE_TAG.sub(b'', _NOTE.sub(b'', raw))).decode('utf-8', 'replace')
    return re.sub(r'\s+', ' ', text).strip()


class Volume:
    """One TEI file: its bytes, the same bytes with comments blanked, and a line index."""

    def __init__(self, name, data=None):
        self.name = name
        self.vid = name[:-4] if name.endswith('.xml') else name
        self.raw = data if data is not None else open(os.path.join(VOLUMES_DIR, name), 'rb').read()
        self.blanked = _COMMENT.sub(lambda m: re.sub(rb'[^\n]', b' ', m.group(0)), self.raw)
        self._newlines = [m.start() for m in re.finditer(rb'\n', self.raw)]
        self._divs = None
        self._pbs = None

    def line(self, offset):
        """1-based line number of a byte offset."""
        return bisect.bisect_right(self._newlines, offset - 1) + 1

    def line_text(self, line):
        """The text of a 1-based line (no newline)."""
        start = 0 if line == 1 else self._newlines[line - 2] + 1
        end = self._newlines[line - 1] if line - 1 < len(self._newlines) else len(self.raw)
        return self.raw[start:end].decode('utf-8', 'replace')

    @property
    def divs(self):
        """Every <div> in file order: id, type, subtype, n, open line/offset, close line, parent, depth, head."""
        if self._divs is None:
            stack, nodes = [], []
            b = self.blanked
            for m in _DIV.finditer(b):
                if m.group(0).startswith(b'</'):
                    node = stack.pop()
                    node['close'] = self.line(m.start())
                    node['close_off'] = m.start()
                    continue
                a = attrs(m.group(1))
                h = _HEAD.search(b[m.end():m.end() + 1500])
                node = {
                    'id': a.get('xml:id'), 'type': a.get('type'), 'subtype': a.get('subtype'),
                    'n': a.get('n'), 'attrs': a, 'line': self.line(m.start()), 'off': m.start(),
                    'parent': stack[-1] if stack else None, 'depth': len(stack),
                    'head': plain(h.group(1))[:90] if h else '', 'close': None, 'close_off': None,
                }
                nodes.append(node)
                if m.group(0).endswith(b'/>'):
                    node['close'] = node['line']
                    node['close_off'] = m.start()
                else:
                    stack.append(node)
            if stack:
                raise ValueError('%s: %d <div> left open' % (self.name, len(stack)))
            self._divs = nodes
        return self._divs

    def div(self, xml_id):
        """The div carrying an xml:id, or None."""
        for node in self.divs:
            if node['id'] == xml_id:
                return node
        return None

    def parent_id(self, xml_id):
        """The xml:id of a div's parent div ('' at the root of <front>/<body>/<back>)."""
        node = self.div(xml_id)
        if node is None:
            raise KeyError('%s has no div %s' % (self.name, xml_id))
        return node['parent']['id'] if node['parent'] else ''

    def chain(self, xml_id):
        """A div's ancestors, innermost first, as 'id(type)' strings."""
        node, out = self.div(xml_id), []
        while node:
            out.append('%s(%s)' % (node['id'], node['type']))
            node = node['parent']
        return out

    def children(self, xml_id, documents=False):
        """The child divs of a div (documents left out unless asked for)."""
        return [n for n in self.divs if n['parent'] is not None and n['parent']['id'] == xml_id
                and (documents or n['type'] != 'document')]

    def enclosing_div(self, offset, kind=None):
        """The innermost div (of a type, if given) holding a byte offset."""
        best = None
        for node in self.divs:
            if node['off'] <= offset and (node['close_off'] is None or offset <= node['close_off']):
                if kind is None or node['type'] == kind:
                    best = node
            elif node['off'] > offset:
                break
        return best

    @property
    def pbs(self):
        """Every <pb> in file order: n, xml:id, facs, line, offset."""
        if self._pbs is None:
            out = []
            for m in _PB.finditer(self.blanked):
                a = attrs(m.group(1))
                out.append({'n': a.get('n'), 'id': a.get('xml:id'), 'facs': a.get('facs'),
                            'line': self.line(m.start()), 'off': m.start()})
            self._pbs = out
        return self._pbs

    def ids(self):
        """Every xml:id in the file (comments excluded)."""
        return set(x.decode() for x in re.findall(rb'xml:id\s*=\s*"([^"]+)"', self.blanked))


def move_close_tags(volume, moves):
    """A copy of the volume with each lone </div> on a from-line moved to just before its to-line.

    `moves` is a list of (from_line, to_line). Every line number is that of the UNMODIFIED file, as
    a correction is stated, however many moves one file takes. Raises when a from-line does not hold
    only </div>, and when the result is not well-formed XML.
    """
    lines = volume.raw.split(b'\n')
    removed, inserted = set(), {}
    for from_line, to_line in moves:
        if lines[from_line - 1].strip() != b'</div>':
            raise ValueError('%s line %d is not a lone </div>: %r'
                             % (volume.name, from_line, lines[from_line - 1][:80]))
        if from_line in removed:
            raise ValueError('%s line %d is moved twice' % (volume.name, from_line))
        removed.add(from_line)
        inserted.setdefault(to_line, []).append(lines[from_line - 1])
    out = []
    for number, text in enumerate(lines, 1):
        out.extend(inserted.get(number, []))
        if number not in removed:
            out.append(text)
    data = b'\n'.join(out)
    ET.fromstring(data)  # raises ParseError when the repair is not well-formed
    return Volume(volume.name, data)


def move_close_tag(volume, from_line, to_line):
    """move_close_tags for one move."""
    return move_close_tags(volume, [(from_line, to_line)])


def retype_div(volume, xml_id, new_type):
    """A copy of the volume with one div's type attribute replaced."""
    node = volume.div(xml_id)
    end = volume.raw.index(b'>', node['off'])
    tag = volume.raw[node['off']:end]
    new_tag, count = re.subn(rb'(?<![\w:])type="[^"]*"', b'type="' + new_type.encode() + b'"', tag)
    if count != 1:
        raise ValueError('%s %s: expected one type attribute, found %d' % (volume.name, xml_id, count))
    data = volume.raw[:node['off']] + new_tag + volume.raw[end:]
    ET.fromstring(data)
    return Volume(volume.name, data)
