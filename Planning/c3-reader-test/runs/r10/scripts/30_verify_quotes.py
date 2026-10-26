# Extract each quotation exactly from its document's body_text (start phrase .. end phrase, first occurrence) and
# verify it (1) is a substring of document_cache.body_text and (2) lies in the TEI document text with footnotes and
# source note excluded (whitespace-collapsed DOC surface of 28_tei_scan.py's collect()), i.e. it is the document's
# own text, not the editors' apparatus. Writes out/quotes_verified.json.
# SQL run per quote: SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?;
import json, sqlite3, re
from lxml import etree
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
V = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes/"
TEI = "{http://www.tei-c.org/ns/1.0}"; XMLID = "{http://www.w3.org/XML/1998/namespace}id"
spec = json.load(open(R + "scripts/quotes_spec.json"))
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
def collect(el, doc, top):
    tag = el.tag if isinstance(el.tag, str) else ""
    if tag == TEI + "note": return
    if el.text: doc.append(el.text)
    for ch in el:
        ctag = ch.tag if isinstance(ch.tag, str) else ""
        if not (ctag == TEI + "head" and top):
            collect(ch, doc, False)
        if ch.tail: doc.append(ch.tail)
needed = {}
for q in spec: needed.setdefault(q[1], set()).add(q[2])
teidoc = {}
for vol, ids in needed.items():
    for ev, el in etree.iterparse(V + vol + ".xml", events=("end",), tag=TEI + "div", huge_tree=True):
        if el.get("type") == "document" and el.get(XMLID) in ids:
            d = []; collect(el, d, True)
            teidoc[(vol, el.get(XMLID))] = " ".join("".join(d).split())
out = []; bad = 0
for qid, vol, did, a, b in spec:
    body = con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?", (vol, did)).fetchone()[0]
    i = body.find(a)
    j = body.find(b, i) if i >= 0 else -1
    if i < 0 or j < 0:
        print("NOT FOUND", qid, vol, did); bad += 1; continue
    text = body[i:j + len(b)]
    in_body = text in body
    in_tei_doc = " ".join(text.split()) in teidoc.get((vol, did), "")
    if not in_tei_doc: bad += 1
    out.append({"id": qid, "volumeId": vol, "documentId": did, "text": text, "len": len(text), "in_body_text": in_body, "in_TEI_document_text_not_notes": in_tei_doc})
    print("%s %s/%s len=%d body=%s teiDOC=%s | %s" % (qid, vol, did, len(text), in_body, in_tei_doc, text[:110]))
json.dump(out, open(R + "out/quotes_verified.json", "w"), ensure_ascii=False, indent=1)
print("quotes:", len(spec), "failures:", bad)
