# Skeptic B: for one abbreviation word, each volume's list entries (id, definition) and how many
# documents link each id. Innermost <item> holding the <term>; word = the <term>'s text.
import sys, os, re, xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'; XMLID='{http://www.w3.org/XML/1998/namespace}id'
vdir, word, vols = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
def txt(e): return re.sub(r'\s+',' ',''.join(e.itertext())).strip()
for v in vols:
    root = ET.parse(os.path.join(vdir, v + '.xml')).getroot()
    ids = {}
    for item in root.iter(TEI+'item'):
        if item.find('.//'+TEI+'item') is not None: continue
        for t in item.findall('.//'+TEI+'term'):
            if txt(t) == word and t.get(XMLID):
                ids[t.get(XMLID)] = txt(item)[:90]
    counts = {i: set() for i in ids}
    for d in root.iter(TEI+'div'):
        if d.get('type') != 'document': continue
        for g in d.iter(TEI+'gloss'):
            tg = (g.get('target') or '').lstrip('#')
            if tg in counts: counts[tg].add(d.get(XMLID))
    print(v, {i: (ids[i], len(counts[i]), sorted(counts[i])[:4]) for i in ids})
