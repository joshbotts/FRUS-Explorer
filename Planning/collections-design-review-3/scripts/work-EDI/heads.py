# EDI: documents with no <head>, or a head with no words, and heads that open with a number.
# Stdlib only. Usage: python3 -I heads.py <volumes-dir> <manifest.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest = sys.argv[1], sys.argv[2]
vols = [v['volumeId'] for v in json.load(open(manifest))]
c = collections.Counter(); ex = collections.defaultdict(list)
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p):
        continue
    root = ET.parse(p).getroot()
    for div in root.iter(TEI + 'div'):
        if div.get('type') != 'document':
            continue
        c['documents'] += 1
        heads = div.findall(TEI + 'head')
        if not heads:
            c['no head'] += 1
            if len(ex['no head']) < 8: ex['no head'].append((vid, div.get(XMLID)))
            continue
        h = heads[0]
        # words outside notes
        def text_no_notes(el):
            out = [el.text or '']
            for ch in el:
                if ch.tag != TEI + 'note':
                    out.append(text_no_notes(ch))
                out.append(ch.tail or '')
            return ''.join(out)
        words = re.sub(r'\s+', ' ', text_no_notes(h)).strip()
        if not words:
            c['head with no words'] += 1
            if len(ex['empty']) < 8: ex['empty'].append((vid, div.get(XMLID)))
        if re.match(r'^\d+[a-z]?\.\s', words):
            c['head opens with its number'] += 1
        if words.startswith('['):
            c['head opens with a bracket'] += 1
            if len(ex['bracket']) < 8: ex['bracket'].append((vid, div.get(XMLID), words[:90]))
print(dict(c))
for k, v in ex.items():
    print(k, v)
