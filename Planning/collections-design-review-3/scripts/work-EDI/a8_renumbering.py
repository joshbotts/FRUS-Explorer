# EDI: A8 groups central files "by class". The Department renumbered its decimal classes on
# 1 January 1950 (decimal-class-labels.json's provenance: "class 7 is Political Relations of States
# before that date and Internal Political and National Defense Affairs after it"). This counts the
# class keys that documents' SOURCE NOTES cite on both sides of 1950, and the documents involved.
# A key is the text before the slash of a decimal file number (861.00 of 861.00/2-2246).
# The document's year is the first four characters of frus:doc-dateTime-min.
# Stdlib only. Usage: python3 -I a8_renumbering.py <volumes-dir> <manifest.json> <out.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
FRUS = '{http://history.state.gov/frus/ns/1.0}'
vdir, manifest, out = sys.argv[1], sys.argv[2], sys.argv[3]
vols = [v['volumeId'] for v in json.load(open(manifest))]
KEY = re.compile(r'(?<![\d.])(\d{3}[A-Z]?\.\d{1,4}[A-Za-z0-9]*(?:\s?[A-Z][A-Za-z]{0,3})?)\s?/\s?\d')

def fold(s):
    return re.sub(r'\s+', ' ', s).strip()

def era(y):
    if y < 1910: return None
    if y <= 1949: return '1910-1949'
    if y <= 1959: return '1950-1959'
    if y <= 1963: return '1960-1963'
    return None

key_eras = collections.defaultdict(lambda: collections.Counter())
key_docs = collections.defaultdict(list)
for vid in vols:
    path = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(path):
        continue
    root = ET.parse(path).getroot()
    for div in root.iter(TEI + 'div'):
        if div.get('type') != 'document':
            continue
        dmin = None
        for k, v in div.attrib.items():
            if k.endswith('doc-dateTime-min'):
                dmin = v
        if not dmin or not dmin[:4].isdigit():
            continue
        y = int(dmin[:4])
        e = era(y)
        if not e:
            continue
        src = None
        for n in div.iter(TEI + 'note'):
            if n.get('type') == 'source':
                src = fold(''.join(n.itertext()))
                break
        if not src:
            continue
        m = KEY.search(src)
        if not m:
            continue
        key = re.sub(r'\s+', ' ', m.group(1))
        key_eras[key][e] += 1
        if len(key_docs[key]) < 400:
            key_docs[key].append((vid, div.get(XMLID), y))

both = {k: c for k, c in key_eras.items() if '1910-1949' in c and ('1950-1959' in c or '1960-1963' in c)}
docs_in_both = sum(sum(c.values()) for c in both.values())
all_docs = sum(sum(c.values()) for c in key_eras.values())
minority = sum(min(c['1910-1949'], c.get('1950-1959', 0) + c.get('1960-1963', 0)) for c in both.values())
balanced = sorted(((k, dict(c)) for k, c in both.items() if min(c['1910-1949'], c.get('1950-1959', 0) + c.get('1960-1963', 0)) >= 10), key=lambda kv: -sum(kv[1].values()))
print('minority-side documents', minority, 'keys with >=10 on each side', len(balanced))
for k, c in balanced[:30]:
    print('  ', k, c)
top = sorted(both.items(), key=lambda kv: -sum(kv[1].values()))[:25]
res = {'keys': len(key_eras), 'documents_with_a_key': all_docs,
       'keys_cited_before_and_after_1950': len(both),
       'documents_under_such_keys': docs_in_both,
       'top': [(k, dict(c)) for k, c in top]}
json.dump(res, open(out, 'w'), indent=1)
print(json.dumps(res, indent=1)[:3000])
