# EDI: A4 and See also by page. A same-volume reference to a printed page (#pg_N) inside a
# document: how many documents BEGIN on the page it names. IndexingPipeline's same-volume pass
# (resolvePageBasedCrossReferences, IndexingPipeline.swift:10631-10729) stores ONE of them: the one
# the reference's footnote names by number or day, else the first in source order.
# A document's start page: the n of the last <pb> met in document order before its first word
# (a <pb> that opens the division counts as its own). Approximate replica, stdlib only.
# Usage: python3 -I same_volume_pages.py <volumes-dir> <manifest.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest = sys.argv[1], sys.argv[2]
vols = [v['volumeId'] for v in json.load(open(manifest))]

def is_doc(el):
    return el.tag == TEI + 'div' and (el.get('type') == 'document' or el.get('subtype') == 'editorial-note')

tot = collections.Counter()
by_era = collections.defaultdict(collections.Counter)
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p):
        continue
    m = re.match(r'frus(\d{4})', vid); y = int(m.group(1)) if m else 0
    era = 'before 1955' if y < 1955 else ('1955-68' if y < 1969 else '1969 on')
    root = ET.parse(p).getroot()
    body = root.find('.//' + TEI + 'body')
    if body is None:
        continue
    starts = collections.defaultdict(list)   # page -> documents beginning on it
    cur = [None]
    refs = []   # (doc, page)
    def walk(el, doc, started):
        # returns started flag for the current doc
        for ch in el:
            if ch.tag == TEI + 'pb' and ch.get('n'):
                cur[0] = ch.get('n')
            if is_doc(ch):
                did = ch.get(XMLID)
                # a pb as the division's first child belongs to it
                first = next(iter(ch), None)
                if first is not None and first.tag == TEI + 'pb' and first.get('n'):
                    cur[0] = first.get('n')
                if cur[0] is not None:
                    starts[cur[0]].append(did)
                walk(ch, did, True)
                continue
            if ch.tag == TEI + 'ref' and doc is not None:
                t = ch.get('target') or ''
                mm = re.fullmatch(r'(?:' + re.escape(vid) + r')?#pg_(\d+)', t)
                if mm:
                    refs.append((doc, mm.group(1)))
            walk(ch, doc, started)
    walk(body, None, False)
    for doc, page in refs:
        n = len(starts.get(page, []))
        k = 'several begin on it' if n > 1 else ('one begins on it' if n == 1 else 'none begins on it')
        tot[k] += 1; by_era[era][k] += 1
        tot['refs'] += 1; by_era[era]['refs'] += 1
print('all', dict(tot))
for e in sorted(by_era):
    print(e, dict(by_era[e]))
