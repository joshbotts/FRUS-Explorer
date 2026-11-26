"""Count document-term pairs whose <gloss> target names no term of the volume's own list.

Read-only over the public TEI. For each volume: the term ids are the xml:id of each <term>
(or <item>) inside a div whose xml:id or type is terms / abbreviations / listofabbreviations.
A document is a <div type="document"> with an xml:id (editorial notes are documents too).
A pair is (document, normalised target), the target being the part after the last '#'.
Also counts, for each volume, documents whose @ana names a listed term.
Usage: python3 -I listless_terms.py /path/to/volumes
"""
import os
import sys
import xml.etree.ElementTree as ET

TEI = "{http://www.tei-c.org/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
LIST_IDS = {"terms", "abbreviations", "listofabbreviations"}


def norm(pointer):
    pointer = pointer.strip()
    if not pointer:
        return None
    tail = pointer.rsplit("#", 1)[-1].strip()
    return tail or None


def scan(path):
    term_ids = set()
    pairs = set()          # (doc, ref) from gloss
    ana_pairs = set()      # (doc, ref) from @ana, unfiltered
    doc_stack = []         # current document id or None per div
    terms_depth = []       # True per div when inside the terms list
    for event, el in ET.iterparse(path, events=("start", "end")):
        tag = el.tag
        if event == "start":
            if tag == TEI + "div":
                xid = (el.get(XMLID) or "").lower()
                typ = (el.get("type") or "").lower()
                in_terms = (terms_depth and terms_depth[-1]) or xid in LIST_IDS or typ in LIST_IDS
                terms_depth.append(bool(in_terms))
                if typ == "document" and el.get(XMLID):
                    doc_stack.append(el.get(XMLID))
                    for p in (el.get("ana") or "").split():
                        r = norm(p)
                        if r:
                            ana_pairs.add((el.get(XMLID), r))
                else:
                    doc_stack.append(doc_stack[-1] if doc_stack else None)
            elif tag in (TEI + "term", TEI + "item"):
                if terms_depth and terms_depth[-1] and el.get(XMLID):
                    term_ids.add(el.get(XMLID))
            elif tag == TEI + "gloss":
                doc = doc_stack[-1] if doc_stack else None
                if doc:
                    for p in (el.get("target") or el.get("ref") or "").split():
                        r = norm(p)
                        if r:
                            pairs.add((doc, r))
        else:
            if tag == TEI + "div":
                terms_depth.pop()
                doc_stack.pop()
            el.clear()
    listless = {(d, r) for (d, r) in pairs if r not in term_ids}
    ana_listed = {(d, r) for (d, r) in ana_pairs if r in term_ids}
    return len(term_ids), len(pairs), listless, ana_listed


def main(root):
    total_pairs = 0
    total_listless = 0
    by_volume = []
    ana_total = 0
    ana_volumes = []
    for name in sorted(os.listdir(root)):
        if not name.endswith(".xml"):
            continue
        n_terms, n_pairs, listless, ana_listed = scan(os.path.join(root, name))
        total_pairs += n_pairs
        total_listless += len(listless)
        if listless:
            refs = sorted({r for _, r in listless})
            docs = {d for d, _ in listless}
            by_volume.append((name[:-4], len(listless), len(docs), n_terms, refs[:4]))
        if ana_listed:
            ana_total += len(ana_listed)
            ana_volumes.append((name[:-4], len(ana_listed)))
    print("gloss pairs:", total_pairs)
    print("pairs whose target is not in the volume's list:", total_listless,
          "in", len(by_volume), "volumes")
    for vol, n, docs, n_terms, refs in sorted(by_volume, key=lambda t: -t[1])[:15]:
        print(f"  {vol}: {n} pairs in {docs} documents (list holds {n_terms}); e.g. {refs}")
    print("@ana pairs naming a listed term:", ana_total, ana_volumes[:5])


if __name__ == "__main__":
    main(sys.argv[1])
