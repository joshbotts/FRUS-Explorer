# Skeptic B, EDI-5: does a document's heading (its first <head>, notes left out) open with a
# number ("No. 307." / "307.")? Compared with the document's @n. Volumes grouped by the first year
# in the volume id: before 1952; 1952-54 (frus1952-54*); others ignored. Stdlib only.
import sys, os, json, re, collections, xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'
vdir, manifest = sys.argv[1], sys.argv[2]
vols = [v['volumeId'] for v in json.load(open(manifest))]
LEAD = re.compile(r'^(?:No\.\s*(\d+)[a-z]?\b|(\d+)[a-z]?\.\s)')
def head_text(h):
    out = []
    def walk(e, top):
        if not top and e.tag == TEI+'note':
            if e.tail: out.append(e.tail); return
            return
        if e.tag == TEI+'lb': out.append(' ')
        if e.text: out.append(e.text)
        for c in e: walk(c, False)
        if not top and e.tail: out.append(e.tail)
    walk(h, True)
    return re.sub(r'\s+', ' ', ''.join(out)).strip()
pre = collections.Counter(); pre_vols = collections.Counter(); per = collections.Counter()
mid_vols = {}
for vid in vols:
    m = re.match(r'frus(\d{4})', vid); y = int(m.group(1))
    grp = 'pre' if y < 1952 else ('mid' if vid.startswith('frus1952-54') else None)
    if grp is None: continue
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p): continue
    root = ET.parse(p).getroot()
    numbered = 0; docs = 0
    for d in root.iter(TEI+'div'):
        if d.get('type') != 'document': continue
        h = d.find(TEI+'head')
        if h is None: continue
        docs += 1
        mm = LEAD.match(head_text(h) + ' ')
        if not mm: continue
        numbered += 1
        if grp == 'pre':
            pre['numbered'] += 1
            num = mm.group(1) or mm.group(2); same = (d.get('n') or '') == num
            pre['equal to @n' if same else 'not @n'] += 1
            pre_vols[vid] += 1
    if grp == 'mid': mid_vols[vid] = (numbered, docs)
print('before 1952:', dict(pre), 'volumes with any:', len(pre_vols), 'with >=50:', sum(1 for v in pre_vols.values() if v >= 50))
print('1952-54 volumes:', len(mid_vols), 'none numbered:', sum(1 for a, b in mid_vols.values() if a == 0))
for v, (a, b) in sorted(mid_vols.items()): print('  ', v, a, 'of', b)
