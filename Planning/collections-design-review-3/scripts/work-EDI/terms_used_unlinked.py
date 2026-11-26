# EDI: "the documents that use it" (A2) against the documents that LINK it.
# For each manifest volume with a terms list, for each document: the listed terms that occur in the
# document's text as a whole token outside a <gloss>, and whether the document links that term at all.
# Only distinctive surfaces are tested (>= 4 characters, containing an upper-case letter, not an
# English word in lower case anywhere in the volume's text), so common words do not count.
# Stdlib only. Usage: python3 -I terms_used_unlinked.py <volumes-dir> <manifest.json> <out.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest, out = sys.argv[1], sys.argv[2], sys.argv[3]
vols = [v['volumeId'] for v in json.load(open(manifest))]

def fold(s):
    return re.sub(r'\s+', ' ', s).strip()

def is_doc(div):
    return div.tag == TEI + 'div' and (div.get('type') == 'document' or div.get('subtype') == 'editorial-note')

pairs_linked = 0           # (doc, term) linked somewhere in the doc
pairs_used_unlinked = 0    # term occurs as a token outside a gloss, doc links it nowhere
pairs_used_linked_also_unlinked = 0
docs_with_unlinked = 0
vol_rows = []
examples = []
for vid in vols:
    path = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(path):
        continue
    root = ET.parse(path).getroot()
    terms = {}
    for div in root.iter(TEI + 'div'):
        xid = (div.get(XMLID) or '').lower()
        typ = (div.get('type') or '').lower()
        if xid in ('terms', 'abbreviations', 'listofabbreviations') or typ in ('terms', 'abbreviations', 'listofabbreviations'):
            for item in div.iter(TEI + 'item'):
                if any(True for _ in item.iter(TEI + 'item') if _ is not item):
                    continue
                for t in item.iter(TEI + 'term'):
                    i = t.get(XMLID)
                    s = fold(''.join(t.itertext()))
                    if i and s:
                        terms[i] = s
                    break
            break
    if not terms:
        continue
    surfaces = {}
    for i, s in terms.items():
        if len(s) >= 4 and re.search(r'[A-Z]', s) and re.fullmatch(r"[A-Za-z/’'.-]+", s):
            surfaces.setdefault(s, set()).add(i)
    if not surfaces:
        continue
    # exclude surfaces that also occur in lower case as a plain word (e.g. "Dept" is fine, "Paris" not a term)
    alltext = ' '.join(root.itertext())
    lower_words = set(re.findall(r"\b[a-z][a-z’'-]+\b", alltext))
    surfaces = {s: ids for s, ids in surfaces.items() if s.lower() not in lower_words or not s.istitle()}
    pat = re.compile(r"(?<![A-Za-z0-9/’'-])(" + '|'.join(re.escape(s) for s in sorted(surfaces, key=len, reverse=True)) + r")(?![A-Za-z0-9/-])")
    v_linked = v_unlinked = 0
    for div in root.iter(TEI + 'div'):
        if not is_doc(div):
            continue
        did = div.get(XMLID)
        linked = set()
        unlinked_text = []
        def walk(el, in_gloss):
            g = in_gloss or el.tag == TEI + 'gloss'
            if el.tag == TEI + 'gloss':
                t = (el.get('target') or '').split('#')[-1].strip()
                if t:
                    linked.add(t)
            if el.text and not g:
                unlinked_text.append(el.text)
            for ch in el:
                if is_doc(ch):
                    continue
                walk(ch, g)
                if ch.tail and not g:
                    unlinked_text.append(ch.tail)
        walk(div, False)
        text = ' '.join(unlinked_text)
        used = set(m.group(1) for m in pat.finditer(text))
        linked_surfaces = set(terms[t] for t in linked if t in terms)
        for s in linked_surfaces:
            if s in surfaces:
                pairs_linked += 1
                v_linked += 1
                if s in used:
                    pairs_used_linked_also_unlinked += 1
        un = [s for s in used if s not in linked_surfaces]
        if un:
            docs_with_unlinked += 1
            pairs_used_unlinked += len(un)
            v_unlinked += len(un)
            if len(examples) < 30 and vid.startswith(('frus1946', 'frus1961-63v11', 'frus1969-76v06')):
                examples.append((vid, did, sorted(un)[:6]))
    vol_rows.append((vid, v_linked, v_unlinked))

res = {'pairs_linked_distinctive': pairs_linked,
       'pairs_used_but_not_linked_in_that_document': pairs_used_unlinked,
       'pairs_linked_and_also_occurring_unlinked': pairs_used_linked_also_unlinked,
       'documents_with_an_unlinked_use': docs_with_unlinked,
       'volumes': len(vol_rows),
       'worst_volumes': sorted(vol_rows, key=lambda r: -(r[2] / max(1, r[1] + r[2])))[:15],
       'examples': examples}
json.dump(res, open(out, 'w'), indent=1, ensure_ascii=False)
print(json.dumps({k: v for k, v in res.items() if k not in ('examples', 'worst_volumes')}, indent=1))
