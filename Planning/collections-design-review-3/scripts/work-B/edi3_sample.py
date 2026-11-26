import sys, os, json, re, random, xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'
vdir = sys.argv[1]; vols = sys.argv[2].split(',')
EDI = re.compile(r'\b(?:POL|DEF|ECON|FN|AID|CSM|ORG|PER|PS|INCO|SOC|CUL|TEL|AV|LEG|IT|SCI|STR|FT|INT|LAB|PET|POW|TP|XR|FSE|E)\s*(?:\(US\)\s*)?\d+(?:\s?[–—-]\s?\d+)*\s+(?:[A-Z]{2,}|US\b)')
MINE = re.compile(r'Central Files?,\s+(?:[A-Z]{2,5}(?:\s?\([A-Z]+\))?)\s+\d+(?:[-–]\d+)*\s+[A-Z]')
random.seed(7); out = []; n_edi = n_mine = n_both = 0
for vid in vols:
    root = ET.parse(os.path.join(vdir, vid + '.xml')).getroot()
    for d in root.iter(TEI+'div'):
        if d.get('type') != 'document': continue
        hn = {id(n) for h in d.findall(TEI+'head') for n in h.iter(TEI+'note')}
        for n in d.iter(TEI+'note'):
            if id(n) in hn or n.get('type') == 'source': continue
            s = re.sub(r'\s+', ' ', ''.join(n.itertext()))
            a, b = bool(EDI.search(s)), bool(MINE.search(s))
            n_edi += a; n_mine += b; n_both += a and b
            if a and not b: out.append(s[:230])
print('edi', n_edi, 'mine', n_mine, 'both', n_both)
for s in random.sample(out, min(12, len(out))): print('-', s)
