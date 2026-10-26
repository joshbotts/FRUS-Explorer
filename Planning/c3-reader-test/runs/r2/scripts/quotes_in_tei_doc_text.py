# For each verified quotation, confirm it sits in the DOCUMENT text of the TEI (notes and head removed), not in an editorial
# footnote. Counting surface: TEI tag-stripped, whitespace-collapsed (same extraction as tei_pass.py).
import json, re, sys
import xml.etree.ElementTree as ET
sys.path.insert(0, "scripts")
VOLDIR = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
TEI = "{http://www.tei-c.org/ns/1.0}"; XMLID = "{http://www.w3.org/XML/1998/namespace}id"
BLOCK = {TEI + t for t in ("p", "head", "opener", "closer", "dateline", "list", "item", "table", "row", "cell", "lb", "pb", "signed", "salute", "postscript", "quote", "div", "seg", "lg", "l")}
def text_of(el, skip):
    out = []
    def rec(e):
        if e.tag in skip:
            if e.tail: out.append(e.tail)
            return
        if e.text: out.append(e.text)
        for c in e:
            rec(c)
            if c.tag in BLOCK: out.append(" ")
        if e.tail: out.append(e.tail)
    if el.text: out.append(el.text)
    for c in el:
        rec(c)
        if c.tag in BLOCK: out.append(" ")
    return " ".join("".join(out).split())
qs = json.load(open("quotes/quotes_verified.json")); cache = {}; res = []
for q in qs:
    v, d = q["pair"].split("/")
    if v not in cache: cache[v] = ET.parse(f"{VOLDIR}/{v}.xml").getroot()
    div = next(x for x in cache[v].iter(TEI + "div") if x.get(XMLID) == d)
    doc = text_of(div, {TEI + "note", TEI + "head"}); notes = " ".join(" ".join("".join(n.itertext()).split()) for n in div.iter(TEI + "note"))
    t = " ".join(q["text"].split())
    in_doc, in_note = t in doc, t in notes
    nows = lambda s: "".join(s.split())
    in_doc_nows = nows(t) in nows(doc)   # v2: whitespace-insensitive, for extractor spacing such as "( a)"
    res.append({"id": q["id"], "pair": q["pair"], "in_doc_text": in_doc, "in_doc_text_ignoring_whitespace": in_doc_nows, "in_notes": in_note})
    print(q["id"], q["pair"], "DOC" if in_doc else ("DOC(ws)" if in_doc_nows else "-"), "NOTE" if in_note else "-")
json.dump(res, open("quotes/quotes_tei_location.json", "w"), indent=1)
print("all in document text (whitespace-insensitive):", all(r["in_doc_text_ignoring_whitespace"] for r in res), "| exact:", sum(r["in_doc_text"] for r in res), "of", len(res))
