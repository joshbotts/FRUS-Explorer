import sys, os, json, re, xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'
vdir, manifest = sys.argv[1], sys.argv[2]
vols = [v['volumeId'] for v in json.load(open(manifest))]
def head_text(h):
    out = []
    def walk(e, top):
        if not top and e.tag == TEI+'note':
            if e.tail: out.append(e.tail)
            return
        if e.text: out.append(e.text)
        for c in e: walk(c, False)
        if not top and e.tail: out.append(e.tail)
    walk(h, True)
    return re.sub(r'\s+', ' ', ''.join(out)).strip()
n = 0; vs = set(); sub = 0
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p): continue
    root = ET.parse(p).getroot()
    for d in root.iter(TEI+'div'):
        if d.get('type') != 'document': continue
        h = d.find(TEI+'head')
        if h is None: continue
        t = re.sub(r'^(?:No\.\s*\d+[a-z]?\b\s*|\d+[a-z]?\.\s*)', '', head_text(h)).rstrip('.').strip()
        if t.lower() == 'editorial note':
            n += 1; vs.add(vid)
            if d.get('subtype') == 'editorial-note': sub += 1
print('documents headed Editorial Note:', n, 'volumes:', len(vs), 'of them subtype editorial-note:', sub)
