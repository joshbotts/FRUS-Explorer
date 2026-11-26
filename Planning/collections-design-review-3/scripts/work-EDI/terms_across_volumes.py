# EDI: the same abbreviation defined differently by two volumes.
# Mirrors TermsParserDelegate (FRUSCoreKit/TEI/FRUSDocumentParser.swift:2681-2798): a terms
# section is a <div> whose xml:id or type is terms/abbreviations/listofabbreviations; an entry is
# an <item> whose nested <term> carries the xml:id; the definition is the item's text after the
# term, trimmed of separators ",;:—–-" and whitespace, whitespace folded.
# Stdlib only. Usage: python3 -I terms_across_volumes.py <volumes-dir> <manifest.json> <out.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest, out = sys.argv[1], sys.argv[2], sys.argv[3]
vols = json.load(open(manifest))
vol_ids = [v['volumeId'] for v in vols]
subseries = {v['volumeId']: v.get('subseries') for v in vols}
SEP = ',;:—–- \t\r\n'

def fold(s):
    return re.sub(r'\s+', ' ', s).strip()

def item_entry(item):
    term_el = None
    for el in item.iter(TEI + 'term'):
        term_el = el
        break
    if term_el is None:
        return None
    tid = term_el.get(XMLID) or item.get(XMLID)
    term = fold(''.join(term_el.itertext()))
    # text after </term>: everything in the item, minus the term's own text, in document order
    parts = []
    seen_term = [False]
    def walk(el):
        if el is term_el:
            seen_term[0] = True
            if el.tail and seen_term[0]:
                parts.append(el.tail)
            return
        if seen_term[0] and el.text:
            parts.append(el.text)
        for ch in el:
            walk(ch)
        if el is not item and seen_term[0] and el.tail:
            parts.append(el.tail)
    walk(item)
    definition = fold(''.join(parts)).strip(SEP)
    definition = fold(definition)
    return tid, term, definition or None

entries = []   # (vol, ref, term, definition)
for vid in vol_ids:
    path = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(path):
        print('MISSING', vid, file=sys.stderr); continue
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as e:
        print('PARSE', vid, e, file=sys.stderr); continue
    for div in root.iter(TEI + 'div'):
        xid = (div.get(XMLID) or '').lower()
        typ = (div.get('type') or '').lower()
        if xid in ('terms', 'abbreviations', 'listofabbreviations') or typ in ('terms', 'abbreviations', 'listofabbreviations'):
            for item in div.iter(TEI + 'item'):
                # innermost items only, as TermsParserDelegate resets at each nested <item>
                if any(True for _ in item.iter(TEI + 'item') if _ is not item):
                    continue
                e = item_entry(item)
                if e and e[1]:
                    entries.append((vid, e[0], e[1], e[2]))
            break

by_term = collections.defaultdict(list)
for vid, ref, term, d in entries:
    by_term[term].append((vid, d))

def norm(d):
    return re.sub(r'[^a-z0-9 ]', '', (d or '').lower()).strip()

STOP = set('the of and for in to on a an at by or de du la le des usually department office bureau'.split())
def content(d):
    return set(w for w in norm(d).split() if w not in STOP and len(w) > 1)

vols_with_terms = len(set(e[0] for e in entries))
multi = {t: v for t, v in by_term.items() if len(set(x[0] for x in v)) > 1}
differing = {t: v for t, v in multi.items() if len(set(norm(x[1]) for x in v)) > 1}
# clearly different meanings: two definitions sharing no content word
disjoint = {}
for t, v in differing.items():
    defs = list({norm(x[1]): x[1] for x in v if x[1]}.values())
    pairs = []
    for i in range(len(defs)):
        for j in range(i + 1, len(defs)):
            a, b = content(defs[i]), content(defs[j])
            if a and b and not (a & b):
                pairs.append((defs[i], defs[j]))
    if pairs:
        disjoint[t] = pairs

# within one subseries: a surface defined differently by two of its volumes
same_sub = collections.Counter()
same_sub_disjoint = collections.Counter()
examples_sub = []
for t, v in differing.items():
    bysub = collections.defaultdict(dict)
    for vid, d in v:
        bysub[subseries.get(vid)][vid] = d
    for sub, m in bysub.items():
        if len(m) > 1 and len(set(norm(d) for d in m.values())) > 1:
            same_sub[sub] += 1
            ds = list(m.values())
            dis = False
            for i in range(len(ds)):
                for j in range(i + 1, len(ds)):
                    a, b = content(ds[i]), content(ds[j])
                    if a and b and not (a & b):
                        dis = True
            if dis:
                same_sub_disjoint[sub] += 1
                if len(examples_sub) < 40:
                    examples_sub.append((sub, t, m))

# a volume listing one surface twice
dup_in_vol = collections.Counter()
seen = collections.Counter((e[0], e[2]) for e in entries)
for (vid, term), n in seen.items():
    if n > 1:
        dup_in_vol[vid] += 1

no_def = sum(1 for e in entries if not e[3])
res = {
    'entries': len(entries), 'volumes_with_terms': vols_with_terms,
    'distinct_surfaces': len(by_term),
    'surfaces_in_more_than_one_volume': len(multi),
    'surfaces_defined_differently': len(differing),
    'surfaces_with_disjoint_definitions': len(disjoint),
    'subseries_with_a_differing_surface': len(same_sub),
    'differing_surface_pairs_within_subseries_total': sum(same_sub.values()),
    'disjoint_within_subseries_total': sum(same_sub_disjoint.values()),
    'entries_with_no_definition': no_def,
    'volumes_listing_a_surface_twice': len(dup_in_vol),
    'surfaces_listed_twice_in_a_volume_total': sum(dup_in_vol.values()),
    'sample_disjoint': {t: disjoint[t][:3] for t in list(sorted(disjoint))[:80]},
    'examples_within_subseries': [(s, t, m) for s, t, m in examples_sub],
    'watch': {t: sorted(set((x[1] or '') for x in by_term.get(t, [])))[:12] for t in ['S/P', 'INR', 'ARA', 'EA', 'FE', 'AP', 'Dept', 'CIA', 'NEA', 'EUR', 'S/S', 'ACDA', 'MAP', 'OCB', 'PPS', 'G', 'U', 'J', 'P', 'L', 'IO', 'E', 'H', 'S']},
}
json.dump(res, open(out, 'w'), indent=1, ensure_ascii=False)
print(json.dumps({k: v for k, v in res.items() if not isinstance(v, (dict, list))}, indent=1))
