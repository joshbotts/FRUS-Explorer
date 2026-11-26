# Check the a2 note's two frus1969-76v06 examples: which part links each term in d1 and d4.
import sys
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
root = ET.parse(sys.argv[1]).getroot()
for div in root.iter(TEI + 'div'):
    if div.get(XMLID) not in ('d1', 'd4') or div.get('type') != 'document':
        continue
    out = {}
    def walk(el, anc):
        for ch in el:
            if ch.tag == TEI + 'gloss':
                notes = [a for a in anc if a.tag == TEI + 'note']
                part = ('source' if any(n.get('type') == 'source' for n in notes) else
                        ('footnote ' + (notes[-1].get('n') or '?')) if notes else
                        'head' if any(a.tag == TEI + 'head' for a in anc) else 'text')
                out.setdefault(ch.get('target'), set()).add(part)
            walk(ch, anc + [ch])
    walk(div, [])
    print(div.get(XMLID), {k: sorted(v) for k, v in out.items()})
