"""Mirror FRUSDocumentParser's terms delegate (one stored id per <item>: the nested <term>'s
xml:id when it has one, else the item's; a term with empty text is dropped) and count the
document-target pairs whose target matches no stored id. Read-only over the TEI.
Usage: python3 -I parser_terms.py /path/to/volumes"""
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
tot_pairs, tot_miss, vols = 0, 0, []
for n in sorted(os.listdir(sys.argv[1])):
    if not n.endswith(".xml"): continue
    stored, pairs = set(), set()
    stack, terms_depth = [], []
    item_id, term_id, term_text = None, None, None
    in_item = False
    for ev, el in ET.iterparse(os.path.join(sys.argv[1], n), events=("start", "end")):
        tag = el.tag
        if ev == "start":
            if tag == TEI + "div":
                xid = (el.get(XMLID) or "").lower(); typ = (el.get("type") or "").lower()
                terms_depth.append(bool((terms_depth and terms_depth[-1]) or xid in LIST_IDS or typ in LIST_IDS))
                if typ == "document" and el.get(XMLID): stack.append(el.get(XMLID))
                else: stack.append(stack[-1] if stack else None)
            elif terms_depth and terms_depth[-1] and tag == TEI + "item":
                in_item, item_id, term_id = True, el.get(XMLID), None
            elif terms_depth and terms_depth[-1] and in_item and tag == TEI + "term" and el.get(XMLID):
                term_id = el.get(XMLID)
            elif tag == TEI + "gloss" and stack and stack[-1]:
                for p in (el.get("target") or el.get("ref") or "").split():
                    r = norm(p)
                    if r: pairs.add((stack[-1], r))
        else:
            if tag == TEI + "div": terms_depth.pop(); stack.pop()
            elif tag == TEI + "item" and in_item:
                rid = term_id or item_id
                text = "".join(el.itertext()).strip()
                if rid and text: stored.add(rid)
                in_item = False
            if tag != TEI + "item" or not in_item: pass
            if tag == TEI + "div" or (not (terms_depth and terms_depth[-1])): el.clear()
    miss = {(d, r) for d, r in pairs if r not in stored}
    tot_pairs += len(pairs); tot_miss += len(miss)
    if miss: vols.append((n[:-4], len(miss), len({d for d, _ in miss}), sorted({r for _, r in miss})[:4]))
print("pairs:", tot_pairs, "pairs with no stored term:", tot_miss, "volumes:", len(vols))
for v in sorted(vols, key=lambda t: -t[1])[:12]: print("  ", v)
