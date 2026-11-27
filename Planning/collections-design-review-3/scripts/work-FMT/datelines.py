# Where a document's dateline sits, over the manifest's volumes: a direct child of the document
# division (the one place a collection reads it today, #1994), inside an opener, inside a closer,
# elsewhere, or nowhere. Counts documents (div type="document"); a nested document is its own.
# Stdlib only. Usage: python3 -I datelines.py <volumes-dir> <manifest.json>
import sys, os, json, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
vdir, manifest_path = sys.argv[1], sys.argv[2]
vols = sorted(v['volumeId'] for v in json.load(open(manifest_path)))
c = collections.Counter()
for vol in vols:
    root = ET.parse(os.path.join(vdir, vol + '.xml')).getroot()
    for div in root.iter(TEI + 'div'):
        if div.get('type') != 'document':
            continue
        c['documents'] += 1
        direct = any(ch.tag == TEI + 'dateline' for ch in div)
        # walk the division without entering a nested document division
        in_opener = in_closer = elsewhere = False
        stack = [(ch, None) for ch in div]
        while stack:
            el, ctx = stack.pop()
            if el.tag == TEI + 'div' and el.get('type') == 'document':
                continue
            nctx = ctx
            if el.tag == TEI + 'opener':
                nctx = 'opener'
            elif el.tag == TEI + 'closer':
                nctx = 'closer'
            elif el.tag == TEI + 'note':
                nctx = 'note'
            if el.tag == TEI + 'dateline' and el not in div:
                if ctx == 'opener':
                    in_opener = True
                elif ctx == 'closer':
                    in_closer = True
                elif ctx != 'note':
                    elsewhere = True
            stack.extend((ch, nctx) for ch in el)
        if direct:
            c['a dateline is a direct child'] += 1
        elif in_opener:
            c['no direct dateline; one in an opener'] += 1
        elif in_closer:
            c['no direct dateline; one only in a closer'] += 1
        elif elsewhere:
            c['no direct dateline; one elsewhere (not in a note)'] += 1
        else:
            c['no dateline outside notes'] += 1
print(json.dumps(c, indent=1))
