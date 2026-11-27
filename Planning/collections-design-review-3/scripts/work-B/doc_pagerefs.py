import sys, re, xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'; XMLID='{http://www.w3.org/XML/1998/namespace}id'
path, ids = sys.argv[1], sys.argv[2].split(',')
root = ET.parse(path).getroot()
docs = {d.get(XMLID): d for d in root.iter(TEI+'div') if d.get('type')=='document'}
def txt(e): return re.sub(r'\s+',' ',''.join(e.itertext())).strip()
for did in ids:
    d = docs[did]
    # find notes containing a ref to #pg_
    for note in d.iter(TEI+'note'):
        for r in note.iter(TEI+'ref'):
            t = r.get('target') or ''
            if re.fullmatch(r'#pg_\d+', t):
                print(did, t, '|', txt(note)[:220])
    head = d.find(TEI+'head')
    print(did, 'HEAD:', txt(head)[:120] if head is not None else None)
    dl = d.find('.//'+TEI+'dateline')
    print(did, 'DATELINE:', txt(dl)[:120] if dl is not None else None)
