# EDI: A3 "Unprinted material cited" against what a footnote's file pointer points at.
# For every body footnote of a document (not type="source", not inside the <head>), find the
# central-file numbers with a serial (e.g. 861.00/2-1246, 711.61/2–2246) and the lot files
# (Lot 66 D 95), and class the note:
#   unprinted   - the note says "not printed" (any case), "not reproduced", "not found" is NOT counted
#   printed_ref - the note links a document or a page of FRUS (<ref target> to #d.., #pg_.., frus...#)
#                 or says "printed" without "not", "Document N", "ante, p.", "post, p.", "p. N" etc.
#   neither     - neither
# A note can be both: counted as "unprinted" if it says not printed anywhere.
# Stdlib only. Usage: python3 -I footnote_file_pointers.py <volumes-dir> <manifest.json> <out.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest, out = sys.argv[1], sys.argv[2], sys.argv[3]
vols = [v['volumeId'] for v in json.load(open(manifest))]

DEC = re.compile(r'\b\d{3}\.\d{1,4}[A-Za-z0-9]*(?:\s?[A-Z]{1,3})?/\s?\d')   # 861.00/2..., 711.61/..
LOT = re.compile(r'\blot\s+\d{2,4}\s?[–-]?\s?[DFM]\s?[–-]?\s?\d+', re.I)
NOTPR = re.compile(r'not\s+(?:printed|reproduced)|none\s+printed|not\s+found\s+in', re.I)
PRINTED = re.compile(r'\b(?:printed\b|Document\s+\d+|ante,\s*p|post,\s*p|\bp\.\s*\d+|\bpp\.\s*\d+|Foreign Relations)', re.I)

def fold(s):
    return re.sub(r'\s+', ' ', s).strip()

def is_doc(div):
    return div.tag == TEI + 'div' and (div.get('type') == 'document' or div.get('subtype') == 'editorial-note')

stats = collections.Counter()
by_era = collections.defaultdict(collections.Counter)
samples = collections.defaultdict(list)
for vid in vols:
    path = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(path):
        continue
    m = re.match(r'frus(\d{4})', vid)
    year = int(m.group(1)) if m else 0
    era = 'pre1955' if year < 1955 else ('1955-68' if year < 1969 else '1969on')
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
                    continue   # nested notes are inside this one
                yield from notes_of(ch)
        for n in notes_of(div):
            if id(n) in head_notes or n.get('type') == 'source':
                continue
            text = fold(''.join(n.itertext()))
            has_dec = bool(DEC.search(text))
            has_lot = bool(LOT.search(text))
            if not (has_dec or has_lot):
                continue
            refs = [r.get('target') or '' for r in n.iter(TEI + 'ref')]
            links_frus = any(re.search(r'#d\d|#pg_|^frus', t) for t in refs)
            kind = 'unprinted' if NOTPR.search(text) else ('printed_ref' if (links_frus or PRINTED.search(text)) else 'neither')
            key = ('dec' if has_dec else 'lot') + ':' + kind
            stats[key] += 1
            by_era[era][key] += 1
            if len(samples[era + ':' + key]) < 8:
                samples[era + ':' + key].append((vid, div.get(XMLID), n.get('n'), text[:260]))
res = {'stats': stats, 'by_era': by_era, 'samples': samples}
json.dump(res, open(out, 'w'), indent=1, ensure_ascii=False)
print(json.dumps({'stats': stats, 'by_era': by_era}, indent=1))
