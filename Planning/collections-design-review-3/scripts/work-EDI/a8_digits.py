# EDI: which source-note class keys DecimalClassLabelTable.gloss can put in words: only the
# country-arranged classes of the governing schedule (6, 7, 8 for 1910-1949; 3 to 9 for 1950-1963),
# per decimal-class-labels.json. Counts documents by era and by the key's first digit.
# Stdlib only. Usage: python3 -I a8_digits.py <volumes-dir> <manifest.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
vdir, manifest = sys.argv[1], sys.argv[2]
vols = [v['volumeId'] for v in json.load(open(manifest))]
KEY = re.compile(r'(?<![\d.])(\d{3}[A-Z]?\.\d{1,4}[A-Za-z0-9]*)\s?/\s?\d')
ARR = {'1910-1949': set('678'), '1950-1959': set('3456789'), '1960-1963': set('3456789')}
tally = collections.defaultdict(collections.Counter)
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p):
        continue
    root = ET.parse(p).getroot()
    for div in root.iter(TEI + 'div'):
        if div.get('type') != 'document':
            continue
        dmin = next((v for k, v in div.attrib.items() if k.endswith('doc-dateTime-min')), None)
        if not dmin or not dmin[:4].isdigit():
            continue
        y = int(dmin[:4])
        era = '1910-1949' if 1910 <= y <= 1949 else ('1950-1959' if 1950 <= y <= 1959 else ('1960-1963' if 1960 <= y <= 1963 else None))
        if not era:
            continue
        src = next((''.join(n.itertext()) for n in div.iter(TEI + 'note') if n.get('type') == 'source'), None)
        if not src:
            continue
        m = KEY.search(src)
        if not m:
            continue
        d = m.group(1)[0]
        tally[era]['documents'] += 1
        tally[era]['country-arranged' if d in ARR[era] else 'other classes'] += 1
for e in sorted(tally):
    print(e, dict(tally[e]))
