"""As listless_terms.py, but a term is listed only when its id is on an <item> or on a <term>
inside an <item>, as FRUSDocumentParser's terms delegate stores one. Read-only over the TEI.
Usage: python3 -I listless_items.py /path/to/volumes"""
import os, sys
import xml.etree.ElementTree as ET
TEI = "{http://www.tei-c.org/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
LIST_IDS = {"terms", "abbreviations", "listofabbreviations"}
def norm(p):
    p = p.strip()
    if not p: return None
    t = p.rsplit("#", 1)[-1].strip()
    return t or None
def scan(path):
    item_ids, any_ids, pairs = set(), set(), set()
    doc_stack, terms_depth, item_depth = [], [], 0
    for event, el in ET.iterparse(path, events=("start", "end")):
        tag = el.tag
        if event == "start":
            if tag == TEI + "div":
                xid = (el.get(XMLID) or "").lower(); typ = (el.get("type") or "").lower()
                terms_depth.append(bool((terms_depth and terms_depth[-1]) or xid in LIST_IDS or typ in LIST_IDS))
                if typ == "document" and el.get(XMLID): doc_stack.append(el.get(XMLID))
                else: doc_stack.append(doc_stack[-1] if doc_stack else None)
            elif tag == TEI + "item":
                if terms_depth and terms_depth[-1]:
                    item_depth += 1
                    if el.get(XMLID): item_ids.add(el.get(XMLID)); any_ids.add(el.get(XMLID))
            elif tag == TEI + "term":
                if terms_depth and terms_depth[-1] and el.get(XMLID):
                    any_ids.add(el.get(XMLID))
                    if item_depth > 0: item_ids.add(el.get(XMLID))
            elif tag == TEI + "gloss":
                d = doc_stack[-1] if doc_stack else None
                if d:
                    for p in (el.get("target") or el.get("ref") or "").split():
                        r = norm(p)
                        if r: pairs.add((d, r))
        else:
            if tag == TEI + "div": terms_depth.pop(); doc_stack.pop()
            elif tag == TEI + "item" and terms_depth and terms_depth[-1]: item_depth -= 1
            el.clear()
    return {(d, r) for d, r in pairs if r not in item_ids and r in any_ids}, len(any_ids - item_ids)
tot, vols = 0, []
for n in sorted(os.listdir(sys.argv[1])):
    if not n.endswith(".xml"): continue
    miss, outside = scan(os.path.join(sys.argv[1], n))
    if miss or outside:
        tot += len(miss); vols.append((n[:-4], len(miss), len({d for d, _ in miss}), outside, sorted({r for _, r in miss})[:3]))
print("pairs whose term is listed only outside an <item>:", tot, "in", len([v for v in vols if v[1]]), "volumes")
for v in sorted(vols, key=lambda t: -t[1])[:12]: print("  ", v)
