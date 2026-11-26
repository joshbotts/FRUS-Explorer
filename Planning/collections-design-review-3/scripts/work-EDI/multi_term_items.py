# EDI: <item>s of a volume's terms list that hold more than one <term>. TermsParserDelegate
# (FRUSDocumentParser.swift:2720-2792) keeps the FIRST </term>'s text as the term, overwrites the id
# with each later <term>'s xml:id, and keeps the rest of the item's text as the definition.
# So such an item is stored under its LAST term's id, with its FIRST term's words, and a definition
# that runs on through the later terms. This counts them, and the gloss links that point at an id
# the stored rows then lack (every id but the last of such an item).
# Stdlib only. Usage: python3 -I multi_term_items.py <volumes-dir> <manifest.json> <out.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest, out = sys.argv[1], sys.argv[2], sys.argv[3]
vols = [v['volumeId'] for v in json.load(open(manifest))]

def fold(s):
    return re.sub(r'\s+', ' ', s).strip()

items_total = 0
multi_items = 0
multi_terms_hidden = 0     # ids of non-last terms in a multi-term item
vol_multi = collections.Counter()
examples = []
links_to_hidden = 0
docs_linking_hidden = set()
for vid in vols:
    path = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(path):
        continue
    root = ET.parse(path).getroot()
    hidden_ids = set()
    for div in root.iter(TEI + 'div'):
        xid = (div.get(XMLID) or '').lower()
        typ = (div.get('type') or '').lower()
        if xid in ('terms', 'abbreviations', 'listofabbreviations') or typ in ('terms', 'abbreviations', 'listofabbreviations'):
            for item in div.iter(TEI + 'item'):
                # innermost items only: the parser resets at each nested <item> start
                if any(True for _ in item.iter(TEI + 'item') if _ is not item):
                    continue
                terms = list(item.iter(TEI + 'term'))
                if not terms:
                    continue
                items_total += 1
                if len(terms) > 1:
                    multi_items += 1
                    vol_multi[vid] += 1
                    ids = [t.get(XMLID) for t in terms]
                    for i in ids[:-1]:
                        if i:
                            hidden_ids.add(i)
                    multi_terms_hidden += len(terms) - 1
                    if len(examples) < 12:
                        examples.append((vid, ids, fold(''.join(item.itertext()))[:240]))
            break
    if hidden_ids:
        for g in root.iter(TEI + 'gloss'):
            t = (g.get('target') or '').split('#')[-1].strip()
            if t in hidden_ids:
                links_to_hidden += 1
        # documents linking a hidden id
        for div in root.iter(TEI + 'div'):
            if div.get('type') == 'document':
                did = div.get(XMLID)
                for g in div.iter(TEI + 'gloss'):
                    t = (g.get('target') or '').split('#')[-1].strip()
                    if t in hidden_ids:
                        docs_linking_hidden.add((vid, did))
                        break

res = {'items_with_a_term': items_total, 'items_with_more_than_one_term': multi_items,
       'terms_after_the_first_in_such_items': multi_terms_hidden,
       'volumes_with_such_items': len(vol_multi), 'top_volumes': vol_multi.most_common(15),
       'gloss_links_to_an_id_not_kept': links_to_hidden,
       'documents_linking_an_id_not_kept': len(docs_linking_hidden),
       'examples': examples}
json.dump(res, open(out, 'w'), indent=1, ensure_ascii=False)
print(json.dumps({k: v for k, v in res.items() if k != 'examples'}, indent=1))
for e in examples[:8]:
    print(e)
