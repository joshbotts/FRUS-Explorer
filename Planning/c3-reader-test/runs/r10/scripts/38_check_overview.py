# Check the overview against the verified quotations and the collection:
#  (1) every block quotation ('> "...") equals, character for character, a verified quotation (out/quotes_verified.json)
#      of the document whose URL follows it, and that quotation is an excerpt in collection.fruscollection;
#  (2) every history.state.gov URL in the overview names a document that is in the collection;
#  (3) list any other double-quoted strings for review.
import json, re
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
ov = open(R + "overview.md").read()
qv = json.load(open(R + "out/quotes_verified.json"))
coll = json.load(open(R + "collection.fruscollection"))
docs = {(e["volumeId"], e["documentId"]) for e in coll["entries"] if e["kind"] == "document"}
exc = {(e["volumeId"], e["documentId"], e["text"]) for e in coll["entries"] if e["kind"] == "excerpt"}
ok = bad = 0
for line in ov.split("\n"):
    if line.startswith('> "'):
        m = re.match(r'^> "(.*)" — .*historicaldocuments/([^/]+)/(\S+)$', line)
        text, v, d = m.group(1), m.group(2), m.group(3)
        match = [q for q in qv if q["volumeId"] == v and q["documentId"] == d and q["text"] == text and q["in_body_text"] and q["in_TEI_document_text_not_notes"]]
        inexc = (v, d, text) in exc
        if match and inexc: ok += 1
        else:
            bad += 1; print("PROBLEM", v, d, bool(match), inexc, text[:80])
urls = re.findall(r"historicaldocuments/([^/\s]+)/([^\s;,)]+)", ov)
missing = sorted({(v, d) for v, d in urls if (v, d) not in docs})
print("block quotations verified and excerpted:", ok, "problems:", bad)
print("distinct documents cited by URL:", len(set(urls)), "not in collection:", missing)
others = [s for s in re.findall(r'"([^"\n]{1,120})"', ov) if not s.startswith("the rule") ]
print("other double-quoted strings:", [o for o in others if len(o) < 120 and not ov.count('> "' + o)])
