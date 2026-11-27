# Term ids that recur across the manifest's volumes, and how many recur with definitions that share
# no word of three letters or more (a crude test of a different meaning, not of a different wording).
# Stdlib only. Usage: python3 -I id_collisions.py <volumes-dir> <manifest.json>
import sys, os, json, re, collections, itertools
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, mp = sys.argv[1], sys.argv[2]
vols = sorted(v['volumeId'] for v in json.load(open(mp)))
def text_of(el): return re.sub(r'\s+', ' ', ''.join(el.itertext())).strip()
by_id = collections.defaultdict(dict)    # id -> {vol: (term, definition)}
glossed = collections.Counter()          # (vol, id) -> gloss count
for vol in vols:
    root = ET.parse(os.path.join(vdir, vol + '.xml')).getroot()
    parent = {c: p for p in root.iter() for c in p}
    text_el = root.find(TEI + 'text')
    for el in text_el.iter(TEI + 'term'):
        i = el.get(XMLID)
        if not i: continue
        term = text_of(el)
        item = el
        while item is not None and item.tag != TEI + 'item':
            item = parent.get(item)
        whole = text_of(item) if item is not None else term
        d = whole[len(term):].lstrip(' ,:;—–-').strip() if whole.startswith(term) else whole
        by_id[i][vol] = (term, d)
    for g in text_el.iter(TEI + 'gloss'):
        t = g.get('target')
        if t: glossed[(vol, t.split('#')[-1])] += 1
def words(s): return {w for w in re.findall(r'[a-z]{3,}', s.lower())} - {'the', 'and', 'for', 'department', 'state'}
multi = {i: v for i, v in by_id.items() if len(v) > 1}
disjoint = {}
for i, v in multi.items():
    items = list(v.items())
    for (va, (ta, da)), (vb, (tb, db)) in itertools.combinations(items, 2):
        wa, wb = words(da), words(db)
        if wa and wb and not (wa & wb) and glossed[(va, i)] and glossed[(vb, i)]:
            disjoint[i] = (va, ta, da, glossed[(va, i)], vb, tb, db, glossed[(vb, i)])
            break
print('ids in more than one volume:', len(multi))
print('of which two glossed volumes give definitions sharing no word:', len(disjoint))
for i, row in list(sorted(disjoint.items()))[:25]:
    print(i, '|', row[0], row[1], '=', row[2][:60], f'({row[3]} links)', '||', row[4], row[5], '=', row[6][:60], f'({row[7]} links)')
