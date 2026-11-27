# Skeptic B: which documents link given term ids, and the term list's entries for them.
import sys, re, xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'; XMLID='{http://www.w3.org/XML/1998/namespace}id'
path, ids = sys.argv[1], sys.argv[2].split(',')
root = ET.parse(path).getroot()
def txt(e): return re.sub(r'\s+',' ',''.join(e.itertext())).strip()
# term list entries: innermost <item> holding the <term xml:id>
for item in root.iter(TEI+'item'):
    for t in item.findall('.//'+TEI+'term'):
        if t.get(XMLID) in ids:
            print('LIST', t.get(XMLID), '|', txt(item)[:120])
docs = [d for d in root.iter(TEI+'div') if d.get('type')=='document']
for tid in ids:
    hits = []
    for d in docs:
        n = 0; forms = set()
        for g in d.iter(TEI+'gloss'):
            if (g.get('target') or '') == '#'+tid:
                n += 1; forms.add(txt(g))
        if n: hits.append((d.get(XMLID), n, sorted(forms)))
    print(tid, len(hits), 'documents:', hits)
