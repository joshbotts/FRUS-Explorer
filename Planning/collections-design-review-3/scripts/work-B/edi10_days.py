# Skeptic B, EDI-10: documents whose frus:doc-dateTime-min and -max fall on the same day (first
# ten characters, i.e. the day at -05:00), counted for each day a presidency changes.
import sys, os, json, re, collections, xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'; FRUS='{http://history.state.gov/frus/ns/1.0}'
vdir, manifest = sys.argv[1], sys.argv[2]
days = {'1865-04-15','1881-09-19','1901-09-14','1923-08-02','1945-04-12','1963-11-22','1974-08-09','1969-01-20','1953-01-20','1961-01-20','1977-01-20','1981-01-20','1989-01-20'}
vols = [v['volumeId'] for v in json.load(open(manifest))]
c = collections.Counter()
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p): continue
    for ev, el in ET.iterparse(p, events=('start',)):
        if el.tag == TEI+'div' and el.get('type') == 'document':
            a, b = (el.get(FRUS+'doc-dateTime-min') or '')[:10], (el.get(FRUS+'doc-dateTime-max') or '')[:10]
            if a and a == b and a in days: c[a] += 1
print(dict(sorted(c.items())), sum(c.values()))
