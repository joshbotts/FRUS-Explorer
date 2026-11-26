# EDI: what A3 ("Unprinted material cited") can list, against the files the footnotes name.
# The harvest (SourceNoteKit/FootnoteCitationGrammar.swift; IndexingPipeline.swift:6713-6770) reads
# three things in a body footnote: a lot file, a presidential library (or the Hoover Institution, or
# the Nixon Presidential Materials), and a decimal central-file class that carries a serial and is
# not subject-numeric. This classes every body footnote (not type="source", not inside the <head>)
# of every manifest volume by the kinds of file it names, approximately, by pattern:
#   lot, library, decimal  -> kinds the harvest can read
#   subjnum   e.g. "POL 27 VIET S", "DEF 12-5 ISR"        (1963-73 central files; refused)
#   cfpf      "Central Foreign Policy File", D740123-0456  (1973- electronic telegrams; no anchor)
#   frc       "FRC 69 A 7425" accessions                   (no anchor)
#   cia       "Job 79R01012A", "Central Intelligence Agency" (no anchor)
# and whether it says "not printed" / "neither printed" / "none printed".
# Stdlib only. Usage: python3 -I a3_reach.py <volumes-dir> <manifest.json> <out.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest, out = sys.argv[1], sys.argv[2], sys.argv[3]
vols = [v['volumeId'] for v in json.load(open(manifest))]

PAT = {
    'lot': re.compile(r'\bLots?\s*\d{1,4}\s*[–—-]?\s*[DFM]\s*[–—-]?\s*\d+|\bFiles?\s*[:,]?\s*Lot\s+\d{1,4}\b', re.I),
    'library': re.compile(r'(?:Roosevelt|Truman|Eisenhower|Kennedy|Johnson|Nixon|Ford|Carter|Reagan|Bush|Clinton)\s+(?:Presidential\s+)?(?:Librar(?:y|ies)|Presidential\s+Materials)|Hoover\s+Institution'),
    'decimal': re.compile(r'\b\d{3}[A-Z]?\.\d{1,4}[A-Za-z0-9]*(?:\s?[A-Z][A-Za-z]{0,3})?\s?/\s?[0-9]'),
    'subjnum': re.compile(r'\b(?:POL|DEF|ECON|FN|AID|CSM|ORG|PER|PS|INCO|SOC|CUL|TEL|AV|LEG|IT|SCI|STR|FT|INT|LAB|PET|POW|TP|XR|FSE|E)\s*(?:\(US\)\s*)?\d+(?:\s?[–—-]\s?\d+)*\s+(?:[A-Z]{2,}|US\b)'),
    'cfpf': re.compile(r'Central\s+Foreign\s+Policy\s+Files?|\b[DPN]\d{6}\s?[–—-]\s?\d{3,4}\b|\b[DPN]\d{9,10}\b'),
    'frc': re.compile(r'\bFRC\s*\d{2}\s*[–—-]?\s*[A-Z]\s*[–—-]?\s*\d+'),
    'cia': re.compile(r'\bJob\s+\d{2}\s*[–—-]?\s*[A-Z]?\d+|Central\s+Intelligence\s+Agency,\s+(?:DCI|DDI|DDO|DDA|NIC|ODDI|Executive|Office|Files|History|Job)'),
}
NOTPR = re.compile(r'\b(?:not|neither|none)\s+(?:\w+\s+){0,2}printed\b', re.I)

def fold(s):
    return re.sub(r'\s+', ' ', s).strip()

def is_doc(div):
    return div.tag == TEI + 'div' and (div.get('type') == 'document' or div.get('subtype') == 'editorial-note')

def era_of(vid):
    m = re.match(r'frus(\d{4})', vid)
    y = int(m.group(1)) if m else 0
    if y < 1955: return 'a: before 1955'
    if y < 1964: return 'b: 1955-63'
    if y < 1969: return 'c: 1964-68'
    if y < 1977: return 'd: 1969-76'
    return 'e: 1977 on'

READ = {'lot', 'library', 'decimal'}
tally = collections.defaultdict(collections.Counter)
samples = collections.defaultdict(list)
for vid in vols:
    path = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(path):
        continue
    era = era_of(vid)
    root = ET.parse(path).getroot()
    for div in root.iter(TEI + 'div'):
        if not is_doc(div):
            continue
        head_notes = set()
        for h in div.findall(TEI + 'head'):
            for n in h.iter(TEI + 'note'):
                head_notes.add(id(n))
        def notes_of(el):
            for ch in el:
                if is_doc(ch):
                    continue
                if ch.tag == TEI + 'note':
                    yield ch
                    continue
                yield from notes_of(ch)
        for n in notes_of(div):
            if id(n) in head_notes or n.get('type') == 'source':
                continue
            text = fold(''.join(n.itertext()))
            kinds = {k for k, p in PAT.items() if p.search(text)}
            notpr = bool(NOTPR.search(text))
            t = tally[era]
            t['notes'] += 1
            if notpr:
                t['not printed'] += 1
            if not kinds:
                if notpr:
                    t['not printed, no file named'] += 1
                continue
            t['names a file'] += 1
            for k in sorted(kinds & READ):
                t['  names (readable kind) ' + k] += 1
            readable = bool(kinds & READ)
            other = kinds - READ
            if readable:
                t['names a kind the harvest reads'] += 1
            if other and not readable:
                t['names only kinds the harvest does not read'] += 1
                for k in other:
                    t['  only-unread: ' + k] += 1
                if len(samples[era]) < 6:
                    samples[era].append((vid, div.get(XMLID), n.get('n'), sorted(other), text[:200]))
            if notpr:
                t['not printed, names a file'] += 1
                if readable:
                    t['not printed, a kind the harvest reads'] += 1
                elif other:
                    t['not printed, only kinds it does not read'] += 1
res = {'tally': tally, 'samples': samples}
json.dump(res, open(out, 'w'), indent=1, ensure_ascii=False)
for era in sorted(tally):
    print(era)
    for k, v in sorted(tally[era].items()):
        print('   ', k, v)
