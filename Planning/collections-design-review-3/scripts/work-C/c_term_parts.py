# Skeptic C's own recount of A2: where each document links each term.
# Independent of a2_where_terms.py: an iterparse with an explicit ancestor stack,
# restricted to the manifest's volumes, with per-template "not shown" shares.
# Usage: python3 -I c_term_parts.py <volumes-dir> <manifest.json> <out.json>
import sys, os, json, collections
import xml.etree.ElementTree as ET

TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
manifest = {v['volumeId'] for v in json.load(open(manifest_path))}

TEXT, HEAD, NOTE, SOURCE, ANA = 1, 2, 4, 8, 16

def is_doc(tag, attrs):
    return tag == TEI + 'div' and (attrs.get('type') == 'document' or attrs.get('subtype') == 'editorial-note')

combo = collections.Counter()
vols_with_pairs = set()
docs_with_pairs = set()
nonmanifest_pairs = 0
for fn in sorted(os.listdir(vdir)):
    if not fn.endswith('.xml'):
        continue
    vol = fn[:-4]
    path = os.path.join(vdir, fn)
    # the volume's t_ ids, for @ana
    tids = set()
    stack = []          # list of (tag, attrs)
    docstack = []       # list of [doc_key, {ref: flags}]
    try:
        for ev, el in ET.iterparse(path, events=('start', 'end')):
            if ev == 'start':
                attrs = el.attrib
                i = attrs.get(XMLID)
                if i and i.startswith('t_'):
                    tids.add(i)
                if is_doc(el.tag, attrs):
                    docstack.append([attrs.get(XMLID), collections.defaultdict(int), attrs.get('ana'), len(stack)])
                elif el.tag == TEI + 'gloss' and docstack:
                    t = attrs.get('target')
                    if t:
                        ref = t.split('#')[-1].strip()
                        if ref:
                            # classify by ancestors inside the current document
                            base = docstack[-1][3]
                            anc = stack[base + 1:]
                            notes = [a for (tg, a) in anc if tg == TEI + 'note']
                            if any(a.get('type') == 'source' for a in notes):
                                f = SOURCE
                            elif notes:
                                f = NOTE
                            elif any(tg == TEI + 'head' for (tg, a) in anc):
                                f = HEAD
                            else:
                                f = TEXT
                            docstack[-1][1][ref] |= f
                stack.append((el.tag, dict(attrs)))
            else:
                stack.pop()
                if is_doc(el.tag, el.attrib) and docstack:
                    did, acc, ana, _ = docstack.pop()
                    if ana:
                        for p in ana.split():
                            r = p.split('#')[-1]
                            if r.startswith('t_') and r in tids:
                                acc[r] |= ANA
                    if acc:
                        if vol not in manifest:
                            nonmanifest_pairs += len(acc)
                        else:
                            vols_with_pairs.add(vol)
                            docs_with_pairs.add((vol, did))
                            for ref, f in acc.items():
                                combo[f] += 1
                el.clear()
    except ET.ParseError as e:
        print('PARSE', fn, e, file=sys.stderr)

total = sum(combo.values())
def share(pred):
    n = sum(c for f, c in combo.items() if pred(f))
    return n, round(100.0 * n / total, 2)

res = {
    'total_pairs': total,
    'docs': len(docs_with_pairs),
    'volumes': len(vols_with_pairs),
    'nonmanifest_pairs': nonmanifest_pairs,
    'only_in_notes(4|8, no 1|2|16)': share(lambda f: f & (TEXT | HEAD | ANA) == 0 and f & (NOTE | SOURCE)),
    'only_source': share(lambda f: f == SOURCE),
    'only_footnotes': share(lambda f: f == NOTE),
    'text_only': share(lambda f: f == TEXT),
    'ana_only': share(lambda f: f == ANA),
    # per template: a pair is shown if any printed part links it
    'not_shown_full_with_annotations (prints 1,2,8)': share(lambda f: f & (TEXT | HEAD | SOURCE) == 0),
    'not_shown_summaries (prints 2)': share(lambda f: f & HEAD == 0),
    'not_shown_citations_with_notes (prints 2)': share(lambda f: f & HEAD == 0),
    'not_shown_citations_with_source_notes (prints 2,8)': share(lambda f: f & (HEAD | SOURCE) == 0),
    'not_shown_full_as_printed (prints 1,2,4,8)': share(lambda f: f & (TEXT | HEAD | NOTE | SOURCE) == 0),
    'combos': {str(k): v for k, v in sorted(combo.items())},
}
json.dump(res, open(out, 'w'), indent=1)
print(json.dumps(res, indent=1))
