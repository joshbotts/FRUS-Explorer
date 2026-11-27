# Skeptic B: recount ENG-8's distinct word forms for the eight telegrams, two ways:
# (a) notes left out (ENG-8's method), (b) notes kept (what bodyText holds: every node's text).
# Tokens: runs of ASCII letters, length >= 3, lowercased. <lb/> splits words.
import sys, re, xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XML = '{http://www.w3.org/XML/1998/namespace}'
path = sys.argv[1]; ids = set(sys.argv[2].split(','))
root = ET.parse(path).getroot()
def collect(el, keep_notes):
    parts = []
    def walk(e, top):
        if not top and e.tag == TEI + 'note' and not keep_notes:
            parts.append(' ')
            if e.tail: parts.append(e.tail)
            return
        if e.tag == TEI + 'lb': parts.append(' ')
        if e.text: parts.append(e.text)
        for c in e: walk(c, False)
        parts.append(' ')
        if not top and e.tail: parts.append(e.tail)
    walk(el, True)
    return ''.join(parts)
docs = [d for d in root.iter(TEI + 'div') if d.get('type') == 'document' and d.get(XML + 'id') in ids]
for keep in (False, True):
    c = {}
    for d in docs:
        for w in re.findall(r'[A-Za-z]+', collect(d, keep)):
            if len(w) >= 3:
                w = w.lower(); c[w] = c.get(w, 0) + 1
    print('notes kept' if keep else 'notes out', len(docs), 'docs;', len(c), 'distinct;', sum(1 for v in c.values() if v == 1), 'once')
