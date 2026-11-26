# What a gloss link in a collection's web page could point at, over the manifest's volumes.
# Stdlib only. Usage: python3 -I gloss_targets.py <volumes-dir> <manifest.json> <out.json>
#
# For each volume in the manifest:
#   - its term list: every element whose xml:id starts with "t_", with the term's text and the
#     rest of its <item> as the definition (normalised whitespace);
#   - every <gloss target> inside a document division (type="document" or subtype="editorial-note"),
#     classed as: bare id defined in the own volume; bare id NOT defined in the own volume
#     (dangling); a target naming another volume ("frusX#t_..."), and whether that volume defines it.
# Across volumes:
#   - how many term ids recur in more than one volume (an anchor keyed by the id alone collides);
#   - of those, how many have different definitions;
#   - how many term TEXTS recur with different definitions.
import sys, os, json, collections, re
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
manifest = json.load(open(manifest_path))
vol_ids = sorted({(v.get('id') or v.get('volumeId')) for v in manifest})

def text_of(el):
    return re.sub(r'\s+', ' ', ''.join(el.itertext())).strip()

defs = {}             # vol -> {id: (term, definition)}
stats = collections.Counter()
dangling_examples = []
crossvol_examples = []
per_vol_dangling = collections.Counter()
docs_with_dangling = 0
missing_files = []
for vol in vol_ids:
    path = os.path.join(vdir, vol + '.xml')
    if not os.path.exists(path):
        missing_files.append(vol); continue
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as e:
        print('PARSE', vol, e, file=sys.stderr); continue
    parent = {c: p for p in root.iter() for c in p}
    d = {}
    for el in root.iter():
        i = el.get(XMLID)
        if i and i.startswith('t_'):
            term = text_of(el)
            item = el
            while item is not None and item.tag != TEI + 'item':
                item = parent.get(item)
            whole = text_of(item) if item is not None else term
            definition = whole[len(term):].lstrip(' ,:;—–-').strip() if whole.startswith(term) else whole
            d[i] = (term, definition)
    defs[vol] = d
    for div in root.iter(TEI + 'div'):
        if not (div.get('type') == 'document' or div.get('subtype') == 'editorial-note'):
            continue
        doc_dangling = False
        # glosses of this division, not of a nested document division
        stack = list(div)
        while stack:
            el = stack.pop()
            if el.tag == TEI + 'div' and (el.get('type') == 'document' or el.get('subtype') == 'editorial-note'):
                continue
            stack.extend(list(el))
            if el.tag != TEI + 'gloss':
                continue
            t = el.get('target')
            if not t:
                stats['gloss without target'] += 1
                continue
            t = t.strip()
            stats['gloss with target'] += 1
            if '#' in t and not t.startswith('#'):
                other, ref = t.split('#', 1)
                stats['target names a volume'] += 1
                if other == vol:
                    stats['target names its own volume'] += 1
                else:
                    stats['target names another volume'] += 1
                    if len(crossvol_examples) < 12:
                        crossvol_examples.append(f'{vol}#{div.get(XMLID)} -> {t}')
                continue
            ref = t.lstrip('#')
            if ref in d:
                stats['bare id defined in own volume'] += 1
            else:
                stats['bare id NOT defined in own volume'] += 1
                per_vol_dangling[vol] += 1
                doc_dangling = True
                if len(dangling_examples) < 15:
                    dangling_examples.append(f'{vol}#{div.get(XMLID)} -> {t} ({text_of(el)[:30]})')
        if doc_dangling:
            docs_with_dangling += 1

# Across volumes
id_vols = collections.defaultdict(list)
text_defs = collections.defaultdict(set)
for vol, d in defs.items():
    for i, (term, definition) in d.items():
        id_vols[i].append((vol, definition))
        text_defs[term].add(definition.lower())
ids_multi = {i: v for i, v in id_vols.items() if len(v) > 1}
ids_multi_diffdef = {i: v for i, v in ids_multi.items() if len({x[1].lower() for x in v}) > 1}
texts_multi_def = {t: s for t, s in text_defs.items() if len(s) > 1}
summary = {
    'volumes_in_manifest': len(vol_ids),
    'volumes_missing_file': missing_files,
    'volumes_with_a_term_list': sum(1 for d in defs.values() if d),
    'term_entries': sum(len(d) for d in defs.values()),
    'stats': stats,
    'documents_with_a_dangling_gloss': docs_with_dangling,
    'volumes_with_dangling': len(per_vol_dangling),
    'top_dangling_volumes': per_vol_dangling.most_common(15),
    'dangling_examples': dangling_examples,
    'crossvol_examples': crossvol_examples,
    'term_ids_in_more_than_one_volume': len(ids_multi),
    'term_ids_in_more_than_one_volume_with_different_definitions': len(ids_multi_diffdef),
    'examples_id_diffdef': {i: v[:4] for i, v in list(sorted(ids_multi_diffdef.items(), key=lambda kv: -len(kv[1])))[:6]},
    'term_texts_with_more_than_one_definition': len(texts_multi_def),
    'example_Dept_definitions': sorted(text_defs.get('Dept', set()))[:12],
}
json.dump(summary, open(out, 'w'), indent=1, ensure_ascii=False)
print(json.dumps({k: summary[k] for k in ('volumes_in_manifest', 'volumes_with_a_term_list', 'term_entries', 'stats',
                                         'documents_with_a_dangling_gloss', 'volumes_with_dangling',
                                         'term_ids_in_more_than_one_volume',
                                         'term_ids_in_more_than_one_volume_with_different_definitions',
                                         'term_texts_with_more_than_one_definition')}, indent=1))
