# Where each document's term links sit: body, heading, a footnote, or the source note.
# Stdlib only. Usage: python3 where_terms.py <volumes-dir> <out.json>
import sys, os, json, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, out = sys.argv[1], sys.argv[2]

def is_doc(div):
    return div.tag == TEI + 'div' and (div.get('type') == 'document' or div.get('subtype') == 'editorial-note')

pairs = collections.Counter()   # frozenset(locations) -> count of (doc, term) pairs
docs_with_terms = 0
vol_pairs = collections.Counter()
per_vol_only_note = collections.Counter()
listed_terms = {}
examples = collections.defaultdict(list)
total_links = 0
for fn in sorted(os.listdir(vdir)):
    if not fn.endswith('.xml'):
        continue
    vol = fn[:-4]
    try:
        root = ET.parse(os.path.join(vdir, fn)).getroot()
    except ET.ParseError as e:
        print('PARSE', fn, e, file=sys.stderr); continue
    # the volume's own term list: any element with xml:id starting t_ inside a list of terms
    tids = set()
    for el in root.iter():
        i = el.get(XMLID)
        if i and i.startswith('t_'):
            tids.add(i)
    listed_terms[vol] = len(tids)
    # walk documents; a nested document div is its own document
    def walk(el, doc, loc, acc):
        for ch in el:
            if is_doc(ch):
                continue  # visited separately
            nloc = loc
            if ch.tag == TEI + 'note':
                nloc = 'source' if ch.get('type') == 'source' else ('note' if loc in ('body', 'head') else loc)
                if loc == 'source':
                    nloc = 'source'
            elif ch.tag == TEI + 'head' and loc == 'body':
                nloc = 'head'
            if ch.tag == TEI + 'gloss':
                t = ch.get('target')
                if t:
                    ref = t.split('#')[-1].strip()
                    if ref:
                        acc[ref].add(nloc)
            walk(ch, doc, nloc, acc)
    for div in root.iter(TEI + 'div'):
        if not is_doc(div):
            continue
        did = div.get(XMLID)
        acc = collections.defaultdict(set)
        walk(div, did, 'body', acc)
        ana = div.get('ana')
        if ana:
            for p in ana.split():
                r = p.split('#')[-1]
                if r.startswith('t_') and r in tids:
                    acc[r].add('ana')
        if acc:
            docs_with_terms += 1
        for ref, locs in acc.items():
            key = '+'.join(sorted(locs))
            pairs[key] += 1
            vol_pairs[vol] += 1
            total_links += 1
            if locs <= {'note', 'source'}:
                per_vol_only_note[vol] += 1
            if len(examples[key]) < 6:
                examples[key].append(f'{vol}#{did}:{ref}')
json.dump({'pairs_by_locations': pairs, 'docs_with_terms': docs_with_terms,
           'total_pairs': total_links, 'volumes_with_pairs': len(vol_pairs),
           'only_in_notes_by_volume_top': per_vol_only_note.most_common(25),
           'examples': examples}, open(out, 'w'), indent=1)
print('done', total_links, docs_with_terms, len(vol_pairs))
