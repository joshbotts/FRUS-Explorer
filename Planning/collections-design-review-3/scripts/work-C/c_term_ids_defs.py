# Companion to c_term_ids.py: of the recurring ids, how many have differing definition texts.
import sys, os, json, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, mp = sys.argv[1], sys.argv[2]
by_id = collections.defaultdict(dict)
for vol in sorted(v['volumeId'] for v in json.load(open(mp))):
    root = ET.parse(os.path.join(vdir, vol + '.xml')).getroot()
    text = root.find(TEI + 'text')
    if text is None: continue
    for item in text.iter(TEI + 'item'):
        if item.find('.//' + TEI + 'item') is not None: continue
        for t in item.iter(TEI + 'term'):
            i = t.get(XMLID)
            if i:
                by_id[i][vol] = ' '.join(''.join(item.itertext()).split()).lower()
recur = {i: v for i, v in by_id.items() if len(v) > 1}
print('recurring ids (in items):', len(recur), 'with differing item text:', sum(1 for v in recur.values() if len(set(v.values())) > 1))
