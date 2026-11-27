# Skeptic C's recount for FMT-8: where a document's <dateline> sits, outside notes.
# Classes: a direct child of the document div; else inside an <opener>; else inside a <closer>;
# else elsewhere; else none. Nested document divs are their own documents.
# Usage: python3 -I c_datelines.py <volumes-dir> <manifest.json>
import sys, os, json, collections
import xml.etree.ElementTree as ET

TEI = '{http://www.tei-c.org/ns/1.0}'
vdir, mp = sys.argv[1], sys.argv[2]
counts = collections.Counter()
docs = 0
for vol in sorted(v['volumeId'] for v in json.load(open(mp))):
    root = ET.parse(os.path.join(vdir, vol + '.xml')).getroot()
    for div in root.iter(TEI + 'div'):
        if div.get('type') != 'document':
            continue
        docs += 1
        where = set()
        def walk(el, anc):
            for ch in el:
                if ch.tag == TEI + 'div' and ch.get('type') == 'document':
                    continue
                if ch.tag == TEI + 'note':
                    continue
                if ch.tag == TEI + 'dateline':
                    if not anc:
                        where.add('direct')
                    elif TEI + 'opener' in anc:
                        where.add('opener')
                    elif TEI + 'closer' in anc:
                        where.add('closer')
                    else:
                        where.add('other')
                walk(ch, anc + [ch.tag])
        walk(div, [])
        if 'direct' in where:
            counts['direct child'] += 1
        elif 'opener' in where:
            counts['only in an opener'] += 1
        elif 'closer' in where:
            counts['only in a closer'] += 1
        elif 'other' in where:
            counts['only elsewhere'] += 1
        else:
            counts['none outside a note'] += 1
print('documents:', docs)
for k, v in counts.most_common():
    print(k, v)
