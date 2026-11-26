# Skeptic B, EDI-1: in how many manifest volumes does the terms list give one abbreviation (the
# first <term>'s words, whitespace folded) in two or more items? Terms section = a <div> whose
# xml:id or type is terms / abbreviations / listofabbreviations (the parser's rule).
import sys, os, json, re, collections, xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'; XMLID='{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest = sys.argv[1], sys.argv[2]
vols = [v['volumeId'] for v in json.load(open(manifest))]
names = {'terms','abbreviations','listofabbreviations'}
def txt(e): return re.sub(r'\s+',' ',''.join(e.itertext())).strip()
vol_hits = 0; words_total = 0; entries = 0; examples = []
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p): continue
    root = ET.parse(p).getroot()
    secs = [d for d in root.iter(TEI+'div') if (d.get(XMLID) or '').lower() in names or (d.get('type') or '').lower() in names]
    seen = collections.defaultdict(list)
    for sec in secs:
        for item in sec.iter(TEI+'item'):
            if item.find('.//'+TEI+'item') is not None: continue
            t = item.find('.//'+TEI+'term')
            if t is None: continue
            entries += 1
            seen[txt(t)].append(txt(item)[:70])
    dups = {w: v for w, v in seen.items() if len(v) > 1}
    if dups:
        vol_hits += 1; words_total += len(dups)
        if vid in ('frus1946v11','frus1946v05'): examples.append((vid, sorted(dups)))
print('entries', entries, 'volumes with a word listed twice', vol_hits, 'words', words_total)
for e in examples: print(e)
