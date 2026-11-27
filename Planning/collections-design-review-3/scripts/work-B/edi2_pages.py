# Skeptic B, EDI-2: same-volume references to a printed page (#pg_N, or <vol>#pg_N inside <vol>)
# made inside a document division, classed by how many divisions BEGIN on that page.
# Independent replica: a division's start page is the page of the first <pb> met inside it before
# any non-blank text, else the page in effect when it opens. Documents = div[@type=document]
# (editorial notes included, they are div type=document with a subtype). Notes and all.
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest = sys.argv[1], sys.argv[2]
only = set(sys.argv[3].split(',')) if len(sys.argv) > 3 else None
vols = [v['volumeId'] for v in json.load(open(manifest))]
tot = collections.Counter(); samples = []
for vid in vols:
    if only and vid not in only: continue
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p): continue
    root = ET.parse(p).getroot()
    text_el = root.find(TEI + 'text')
    if text_el is None: continue
    starts = collections.defaultdict(list)
    state = {'page': None}
    refs = []
    pat = re.compile(r'(?:' + re.escape(vid) + r')?#pg_(\d+)$')
    def walk(el, doc, pending):
        # pending: [docid] while the current doc has not yet seen text (start page undecided)
        for ch in el:
            tag = ch.tag
            if tag == TEI + 'pb':
                n = ch.get('n')
                if n is not None:
                    state['page'] = n
                    if pending is not None and not pending[1]:
                        pending[1] = True; starts[n].append(pending[0])
            elif tag == TEI + 'div' and ch.get('type') == 'document':
                did = ch.get(XMLID)
                pend = [did, False]
                if ch.text and ch.text.strip() and state['page'] is not None:
                    pend[1] = True; starts[state['page']].append(did)
                walk(ch, did, pend)
                if not pend[1] and state['page'] is not None:
                    starts[state['page']].append(did)  # never saw text: place at page in effect
                if ch.tail and ch.tail.strip() and pending is not None and not pending[1] and state['page'] is not None:
                    pending[1] = True; starts[state['page']].append(pending[0])
                continue
            else:
                if tag == TEI + 'ref' and doc is not None:
                    m = pat.match(ch.get('target') or '')
                    if m: refs.append((doc, m.group(1)))
                if pending is not None and not pending[1] and ch.text and ch.text.strip() and state['page'] is not None:
                    # first words of the doc: start page is the page in effect now
                    pending[1] = True; starts[state['page']].append(pending[0])
                walk(ch, doc, pending)
            if pending is not None and not pending[1] and ch.tail and ch.tail.strip() and state['page'] is not None:
                pending[1] = True; starts[state['page']].append(pending[0])
    walk(text_el, None, None)
    for doc, page in refs:
        n = len(starts.get(page, []))
        k = 'several' if n > 1 else ('one' if n == 1 else 'none')
        tot[k] += 1; tot['refs'] += 1
        if only: samples.append((vid, doc, page, starts.get(page, [])))
print(dict(tot))
for s in [x for x in samples if x[1] in ("d470","d486")] or samples[:5]:
    print(s)
