# Skeptic C's recount of DATA-2: term-list items that list two spellings or more,
# and the document-term pairs that name a spelling the 1.0 parser does not store.
# The parser (FRUSDocumentParser.swift TermsParserDelegate, v2) enters a terms section at a
# <div xml:id|type in {terms, abbreviations, listofabbreviations}> or a <listBibl>; within it each
# <item> is one row, under the LAST <term xml:id> it holds, with the FIRST </term>'s words.
# Usage: python3 -I c_multi_term.py <volumes-dir> <manifest.json>
import sys, os, json, collections
import xml.etree.ElementTree as ET

TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest_path = sys.argv[1], sys.argv[2]
manifest = sorted(v['volumeId'] for v in json.load(open(manifest_path)))
SECTION_NAMES = {'terms', 'abbreviations', 'listofabbreviations'}

def is_doc(el):
    return el.tag == TEI + 'div' and (el.get('type') == 'document' or el.get('subtype') == 'editorial-note')

items_multi = 0
vols_multi = set()
dropped_pairs = collections.Counter()
last_pairs = collections.Counter()
examples = []
stored_rows = 0
for vol in manifest:
    path = os.path.join(vdir, vol + '.xml')
    root = ET.parse(path).getroot()
    dropped, last = set(), set()
    stored = set()
    # terms sections, by the parser's own entry rule
    def walk(el, in_terms):
        global items_multi, stored_rows
        here = in_terms
        if el.tag == TEI + 'div':
            xid = (el.get(XMLID) or '').lower()
            typ = (el.get('type') or '').lower()
            if xid in SECTION_NAMES or typ in SECTION_NAMES:
                here = True
        elif el.tag == TEI + 'listBibl' and not in_terms:
            here = True
        if here and el.tag == TEI + 'item' and el.find('.//' + TEI + 'item') is None:
            ids = [t.get(XMLID) for t in el.iter(TEI + 'term') if t.get(XMLID)]
            if ids:
                stored.add(ids[-1])
                stored_rows += 1
            if len(ids) >= 2:
                items_multi += 1
                vols_multi.add(vol)
                dropped.update(ids[:-1])
                last.add(ids[-1])
                if len(examples) < 4:
                    examples.append((vol, ids, ''.join(el.itertext()).strip()[:80]))
        for ch in el:
            walk(ch, here)
    walk(root, False)
    dropped -= stored   # an id that another item stores is not dropped
    if not dropped and not last:
        continue
    tids = {e.get(XMLID) for e in root.iter() if (e.get(XMLID) or '').startswith('t_')}
    for div in root.iter(TEI + 'div'):
        if not is_doc(div):
            continue
        refs = set()
        stack = list(div)
        while stack:
            ch = stack.pop()
            if is_doc(ch):
                continue
            if ch.tag == TEI + 'gloss' and ch.get('target'):
                r = ch.get('target').split('#')[-1].strip()
                if r:
                    refs.add(r)
            stack.extend(list(ch))
        for p in (div.get('ana') or '').split():
            r = p.split('#')[-1]
            if r.startswith('t_') and r in tids:
                refs.add(r)
        for r in refs:
            if r in dropped:
                dropped_pairs[vol] += 1
            elif r in last:
                last_pairs[vol] += 1

print('stored rows (items with a term id):', stored_rows)
print('items with two term ids or more:', items_multi, 'in', len(vols_multi), 'volumes')
print('pairs naming a dropped spelling:', sum(dropped_pairs.values()), 'in', len(dropped_pairs), 'volumes')
print('pairs naming an item\'s last spelling:', sum(last_pairs.values()), 'in', len(last_pairs), 'volumes')
print('volumes with either:', len(set(dropped_pairs) | set(last_pairs)))
print('top dropped:', dropped_pairs.most_common(6))
print('top last:', last_pairs.most_common(6))
for e in examples:
    print(e)
