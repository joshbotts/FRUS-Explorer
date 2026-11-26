# Skeptic B, EDI-3: body footnotes (not type="source", not inside a <head>, not in a nested
# document) by era of the volume id, and how many name the Central Foreign Policy File, how many
# name a subject-numeric central file ("Central Files, POL 27 VIET S"), and how many name a lot
# file or a presidential library (kinds the grammar reads). Independent patterns, stdlib only.
import sys, os, json, re, collections, xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'
vdir, manifest = sys.argv[1], sys.argv[2]
vols = [v['volumeId'] for v in json.load(open(manifest))]
CFPF = re.compile(r'Central Foreign Policy File', re.I)
SUBJ = re.compile(r'Central Files?,\s+(?:[A-Z]{2,5}(?:\s?\([A-Z]+\))?)\s+\d+(?:[-–]\d+)*\s+[A-Z]')
LOT = re.compile(r'\bLot\s+\d{2,4}\s?[A-Z]\s?\d+', re.I)
LIB = re.compile(r'(Roosevelt|Truman|Eisenhower|Kennedy|Johnson|Nixon|Ford|Carter|Reagan|Bush) (Presidential )?Library|Nixon Presidential Materials')
def era(v):
    y = int(re.match(r'frus(\d{4})', v).group(1))
    return 'before 1955' if y < 1955 else '1955-63' if y < 1964 else '1964-68' if y < 1969 else '1969-76' if y < 1977 else '1977 on'
t = collections.defaultdict(collections.Counter)
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p): continue
    e = era(vid)
    root = ET.parse(p).getroot()
    for d in root.iter(TEI+'div'):
        if d.get('type') != 'document': continue
        headnotes = {id(n) for h in d.findall(TEI+'head') for n in h.iter(TEI+'note')}
        def notes(el):
            for c in el:
                if c.tag == TEI+'div' and c.get('type') == 'document': continue
                if c.tag == TEI+'note': yield c; continue
                yield from notes(c)
        for n in notes(d):
            if id(n) in headnotes or n.get('type') == 'source': continue
            s = re.sub(r'\s+', ' ', ''.join(n.itertext()))
            c = t[e]; c['notes'] += 1
            cf, sj, lot, lib = bool(CFPF.search(s)), bool(SUBJ.search(s)), bool(LOT.search(s)), bool(LIB.search(s))
            if cf: c['cfpf'] += 1
            if sj: c['subject-numeric central files'] += 1
            if lot or lib: c['lot or library'] += 1
            if (cf or sj) and not (lot or lib): c['cfpf/subjnum and no lot or library'] += 1
for e in ['before 1955','1955-63','1964-68','1969-76','1977 on']:
    print(e, dict(t[e]))
