"""Which link attribute do the marked layer's 9,215 'linked' persName rows carry? (read-only TEI scan)"""
import json, glob, os, re, collections
heads = {os.path.basename(f)[:-len('.head.json')]: json.load(open(f)) for f in glob.glob(os.path.expanduser('~/frus-ner-raw/marked/*.head.json'))}
linked = {v: h['linked'] for v, h in heads.items() if h.get('linked')}
print('volumes with linked>0:', len(linked), 'sum', sum(linked.values()))
VD = '/Users/jbotts/Development/frus/volumes'
tag = re.compile(r'<persName\b[^>]*>')
attr = re.compile(r'\b(corresp|ref|sameAs)=')
kinds = collections.Counter(); per = {}
for v in sorted(linked):
    p = os.path.join(VD, v + '.xml')
    if not os.path.exists(p): print('missing', p); continue
    x = open(p, encoding='utf-8', errors='replace').read()
    c = collections.Counter()
    for m in tag.finditer(x):
        for a in attr.findall(m.group(0)): c[a] += 1
    per[v] = dict(c); kinds.update(c)
print('persName link-attribute kinds over those volumes:', dict(kinds))
print('sample per-volume:', dict(list(per.items())[:8]))
json.dump({'linked_volumes': linked, 'kinds': dict(kinds), 'per_volume': per}, open('linked_check.json','w'), indent=1)
