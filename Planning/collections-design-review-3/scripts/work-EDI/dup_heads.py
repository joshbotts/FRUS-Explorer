# EDI: documents whose heading's words (notes left out, the volume's leading number left out) are
# the same as another document's in the same volume. Under "Summaries" the volume's heading leads
# (decision 158) and no text, so no dateline, prints at a document's head (design §3.4).
# Stdlib only. Usage: python3 -I dup_heads.py <volumes-dir> <manifest.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest = sys.argv[1], sys.argv[2]
vols = [v['volumeId'] for v in json.load(open(manifest))]
def text_no_notes(el):
    out = [el.text or '']
    for ch in el:
        if ch.tag != TEI + 'note':
            out.append(text_no_notes(ch))
        out.append(ch.tail or '')
    return ''.join(out)
tot = collections.Counter()
by_era = collections.defaultdict(collections.Counter)
ex = {}
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p):
        continue
    m = re.match(r'frus(\d{4})', vid); y = int(m.group(1)) if m else 0
    era = 'before 1952' if y < 1952 else ('1952-1968' if y < 1969 else '1969 on')
    root = ET.parse(p).getroot()
    heads = []
    for div in root.iter(TEI + 'div'):
        if div.get('type') != 'document':
            continue
        h = div.find(TEI + 'head')
        if h is None:
            continue
        w = re.sub(r'\s+', ' ', text_no_notes(h)).strip()
        w = re.sub(r'^\d+[a-z]?\.\s+', '', w)
        heads.append(w)
    cnt = collections.Counter(heads)
    for w in heads:
        by_era[era]['documents'] += 1
        if cnt[w] > 1:
            by_era[era]['heading shared in its volume'] += 1
    if vid == 'frus1946v06':
        ex[vid] = cnt.most_common(5)
for e in sorted(by_era):
    print(e, dict(by_era[e]))
print(ex)
