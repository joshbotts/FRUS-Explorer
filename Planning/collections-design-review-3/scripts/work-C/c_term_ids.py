# Skeptic C's recount for FMT-5: term ids (<term xml:id> under <text>) that recur across volumes.
# Usage: python3 -I c_term_ids.py <volumes-dir> <manifest.json>
import sys, os, json, collections, re
import xml.etree.ElementTree as ET

TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest_path = sys.argv[1], sys.argv[2]
manifest = sorted(v['volumeId'] for v in json.load(open(manifest_path)))

by_id = collections.defaultdict(dict)    # id -> {volume: (word, definition)}
linked = collections.defaultdict(lambda: collections.Counter())  # id -> volume -> links
nterms = 0
vols = set()
for vol in manifest:
    root = ET.parse(os.path.join(vdir, vol + '.xml')).getroot()
    text = root.find(TEI + 'text')
    if text is None:
        continue
    # definitions: the text of the innermost <item> holding the term, less the term's words
    parent = {}
    for p in text.iter():
        for c in p:
            parent[c] = p
    for t in text.iter(TEI + 'term'):
        i = t.get(XMLID)
        if not i:
            continue
        nterms += 1
        vols.add(vol)
        word = ' '.join(''.join(t.itertext()).split())
        item = t
        while item is not None and item.tag != TEI + 'item':
            item = parent.get(item)
        defn = ' '.join(''.join(item.itertext()).split()) if item is not None else ''
        by_id[i][vol] = (word, defn)
    for g in text.iter(TEI + 'gloss'):
        tg = g.get('target')
        if tg:
            r = tg.split('#')[-1].strip()
            if r:
                linked[r][vol] += 1

recur = {i: v for i, v in by_id.items() if len(v) > 1}
diff_words = sum(1 for i, v in recur.items() if len({w.lower() for w, d in v.values()}) > 1)

def content_words(s, word):
    ws = set(re.findall(r'[a-z]{3,}', s.lower()))
    ws -= set(re.findall(r'[a-z]{3,}', word.lower()))
    return ws

# ids recurring where two volumes that LINK the id give definitions sharing no word of 3+ letters
no_shared = 0
for i, v in recur.items():
    lv = [vol for vol in v if linked[i][vol] > 0]
    found = False
    for a in range(len(lv)):
        for b in range(a + 1, len(lv)):
            wa, da = v[lv[a]]
            wb, db = v[lv[b]]
            if not (content_words(da, wa) & content_words(db, wb)):
                found = True
    if found:
        no_shared += 1

print('terms with xml:id under <text>:', nterms, 'in', len(vols), 'volumes')
print('distinct ids:', len(by_id))
print('ids in more than one volume:', len(recur))
print('  of them with differing words:', diff_words)
print('  where two linking volumes share no definition word (3+ letters, the term left out):', no_shared)
for i in ('t_ADA1', 't_CIA1', 't_NATO1'):
    print(i, {vol: (wd, linked[i][vol]) for vol, wd in by_id.get(i, {}).items()
              if vol in ('frus1946v01', 'frus1948v09', 'frus1946v08', 'frus1948v01p1', 'frus1943', 'frus1949v04')})
