"""Items of a volume's terms list that hold more than one <term xml:id>, and the document-target
pairs that name (a) a term the parser drops (not the item's last) and (b) the last term, whose
stored row carries the FIRST term's words (FRUSDocumentParser: currentId is overwritten by each
<term>, currentTerm is set at the first </term>). Prints a sample of the row the parser makes.
Read-only over the TEI. Usage: python3 -I multi_term_items.py /path/to/volumes [manifest.json]"""
import json, os, sys
import xml.etree.ElementTree as ET
TEI = "{http://www.tei-c.org/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
LIST_IDS = {"terms", "abbreviations", "listofabbreviations"}
def norm(p):
    p = p.strip()
    if not p: return None
    t = p.rsplit("#", 1)[-1].strip()
    return t or None
catalogue = None
if len(sys.argv) > 2:
    with open(sys.argv[2]) as f:
        m = json.load(f)
    vols = m.get("volumes", m) if isinstance(m, dict) else m
    catalogue = {v.get("id") or v.get("volumeId") for v in vols if isinstance(v, dict)}
items_multi, dropped_pairs, wrong_word_pairs, vol_count, samples = 0, 0, 0, 0, []
for n in sorted(os.listdir(sys.argv[1])):
    if not n.endswith(".xml"): continue
    vid = n[:-4]
    if catalogue is not None and vid not in catalogue: continue
    dropped, last_of_multi = set(), {}
    pairs = set()
    stack, terms_depth = [], []
    item_terms = None
    for ev, el in ET.iterparse(os.path.join(sys.argv[1], n), events=("start", "end")):
        tag = el.tag
        if ev == "start":
            if tag == TEI + "div":
                xid = (el.get(XMLID) or "").lower(); typ = (el.get("type") or "").lower()
                terms_depth.append(bool((terms_depth and terms_depth[-1]) or xid in LIST_IDS or typ in LIST_IDS))
                if typ == "document" and el.get(XMLID): stack.append(el.get(XMLID))
                else: stack.append(stack[-1] if stack else None)
            elif terms_depth and terms_depth[-1] and tag == TEI + "item":
                item_terms = []
            elif tag == TEI + "gloss" and stack and stack[-1]:
                for p in (el.get("target") or el.get("ref") or "").split():
                    r = norm(p)
                    if r: pairs.add((stack[-1], r))
        else:
            if tag == TEI + "term" and item_terms is not None and el.get(XMLID):
                item_terms.append((el.get(XMLID), "".join(el.itertext()).strip()))
            elif tag == TEI + "item" and item_terms is not None:
                if len(item_terms) > 1:
                    items_multi += 1
                    for tid, _ in item_terms[:-1]: dropped.add(tid)
                    last_of_multi[item_terms[-1][0]] = item_terms[0][1]
                    if len(samples) < 3:
                        samples.append((vid, item_terms, " ".join("".join(el.itertext()).split())[:90]))
                item_terms = None
            if tag == TEI + "div": terms_depth.pop(); stack.pop()
            if not (terms_depth and terms_depth[-1]): el.clear()
    d = sum(1 for _, r in pairs if r in dropped)
    w = sum(1 for _, r in pairs if r in last_of_multi)
    if d or w: vol_count += 1
    dropped_pairs += d; wrong_word_pairs += w
print("items listing more than one term:", items_multi)
print("linked pairs naming a dropped term (no row):", dropped_pairs)
print("linked pairs naming the last term (row carries the first term's words):", wrong_word_pairs)
print("volumes with either:", vol_count)
for s in samples: print("  sample:", s)
