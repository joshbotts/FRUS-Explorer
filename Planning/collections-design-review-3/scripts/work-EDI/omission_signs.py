# EDI: L46's sign for an omission. How often each candidate sign is already printed in documents'
# own text (notes left out), by the volume's year: an ellipsis ("…" or ". . ."), a row of asterisks,
# "[omitted]"/"[not printed]" style brackets, and the declassification brackets "[... not declassified]".
# Stdlib only. Usage: python3 -I omission_signs.py <volumes-dir> <manifest.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
vdir, manifest = sys.argv[1], sys.argv[2]
vols = [v['volumeId'] for v in json.load(open(manifest))]
PAT = {
    'ellipsis': re.compile(r'…|\.\s\.\s\.'),
    'asterisks': re.compile(r'\*\s*\*\s*\*'),
    'not declassified': re.compile(r'not\s+declassified\]', re.I),
    '[omitted]-like': re.compile(r'\[(?:[^\]]{0,40})?omitted(?:[^\]]{0,40})?\]', re.I),
}
def text_no_notes(el):
    out = [el.text or '']
    for ch in el:
        if ch.tag != TEI + 'note':
            out.append(text_no_notes(ch))
        out.append(ch.tail or '')
    return ''.join(out)
by = collections.defaultdict(collections.Counter)
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p):
        continue
    m = re.match(r'frus(\d{4})', vid); y = int(m.group(1)) if m else 0
    era = 'a: before 1925' if y < 1925 else ('b: 1925-1968' if y < 1969 else 'c: 1969 on')
    root = ET.parse(p).getroot()
    for d in root.iter(TEI + 'div'):
        if d.get('type') != 'document':
            continue
        t = text_no_notes(d)
        by[era]['documents'] += 1
        for k, pat in PAT.items():
            if pat.search(t):
                by[era]['documents with ' + k] += 1
for e in sorted(by):
    print(e, dict(by[e]))
