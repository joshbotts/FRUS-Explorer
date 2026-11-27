# EDI: A10 prints each document's pages. Which manifest volumes have no page breaks at all, and
# which documents begin on no numbered page.
# Stdlib only. Usage: python3 -I pages.py <volumes-dir> <manifest.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
vdir, manifest = sys.argv[1], sys.argv[2]
man = json.load(open(manifest))
vols = [v['volumeId'] for v in man]
no_pb = []; docs_in_no_pb = 0
eonly = [v for v in vols if re.search(r've\d', v)]
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p):
        continue
    root = ET.parse(p).getroot()
    body = root.find('.//' + TEI + 'body')
    pbs = [pb for pb in (body.iter(TEI + 'pb') if body is not None else []) if pb.get('n')]
    if not pbs:
        n = sum(1 for d in root.iter(TEI + 'div') if d.get('type') == 'document')
        no_pb.append((vid, n)); docs_in_no_pb += n
print('volumes with no numbered page break in the body:', len(no_pb), 'documents:', docs_in_no_pb)
print('of which electronic-only (ve):', sum(1 for v, n in no_pb if re.search(r've\d', v)), 'of', len(eonly), 've volumes')
print([v for v, n in no_pb][:40])
