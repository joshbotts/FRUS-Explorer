# Skeptic B, EDI-9: documents whose source note's first decimal file number ("761.00/2-1146") has a
# given class, split by the year of frus:doc-dateTime-min (before 1950 / 1950 on). Manifest volumes.
import sys, os, json, re, collections, xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'; FRUS='{http://history.state.gov/frus/ns/1.0}'
vdir, manifest, keys = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
vols = [v['volumeId'] for v in json.load(open(manifest))]
PAT = re.compile(r'\b(\d{3}(?:\.\d{1,4})?[A-Z]?)\s?/\s?\d')
c = collections.defaultdict(collections.Counter)
for vid in vols:
    m = re.match(r'frus(\d{4})', vid)
    if not m or not (1935 <= int(m.group(1)) <= 1962): continue
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p): continue
    root = ET.parse(p).getroot()
    for d in root.iter(TEI+'div'):
        if d.get('type') != 'document': continue
        dt = d.get(FRUS+'doc-dateTime-min') or ''
        if len(dt) < 4: continue
        y = int(dt[:4])
        for n in d.iter(TEI+'note'):
            if n.get('type') != 'source': continue
            s = re.sub(r'\s+', ' ', ''.join(n.itertext()))
            mm = PAT.search(s)
            if mm:
                k = mm.group(1)
                if k in keys: c[k]['before 1950' if y < 1950 else '1950 on'] += 1
            break
for k in keys: print(k, dict(c[k]))
