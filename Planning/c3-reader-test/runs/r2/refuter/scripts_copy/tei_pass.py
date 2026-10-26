# TEI pass over every volume that holds a scope document (out/scope.tsv).
# Counting surface: TEI, tag-stripped, whitespace-collapsed. For each scope document the text is split into
#   DOC  = the document's own text: everything inside <div type="document"> except <note> (source note and
#          footnotes) and <head> (the editors' heading);
#   APP  = the apparatus inside that div: all <note> elements plus <head>.
# Regex families are case-INSENSITIVE (Python re.I) and run on DOC and APP separately.
# Per volume it also counts, over the whole file tag-stripped, a positive control ("Department of State")
# and a negative control ("ZZZ_IMPOSSIBLE_ZZZ"). One output file per volume = checkpoint.
import csv, json, os, re, sys, time
import xml.etree.ElementTree as ET
csv.field_size_limit(10**9)
VOLDIR = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
TEI = "{http://www.tei-c.org/ns/1.0}"
FRUS = "{http://history.state.gov/frus/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
FAM = {
 "RECOG": r"\brecogni\w*|\bnon-?recogni\w*|\bunrecogni\w*",   # v2: v1 missed "recognition" (recogni[sz] required s/z)
 "FORCE": r"\brevolution\w*|\bcoups?\b|\bjuntas?\b|\bgolpes?\b|\bde[\s-]+facto\b|\boverthr\w+|\binsurrect\w*|\busurp\w*|\bunconstitutional\w*|\bprovisional\s+govern\w*",
 "BY_FORCE": r"\bby\s+force\b|\bforce\s+of\s+arms\b|\bforcibl[ey]\b",
 "SEIZED_POWER": r"\bseiz(?:ed|ure|ing|es)\s+(?:of\s+)?(?:the\s+)?(?:executive\s+|political\s+)?power\b|\b(?:took|taken|take|taking)\s+power\b|\bcame\s+(?:in)?to\s+power\b|\bcome\s+(?:in)?to\s+power\b",
 "DE_FACTO": r"\bde[\s-]+facto\b|\bdefacto\b",
 "INTL_OBLIG": r"\binternational\s+(?:obligations?|engagements?|commitments?|duties)\b",
 "FULFIL_OBLIG": r"\b(?:fulfil+|meet|discharge|honou?r|comply\s+with|respect|carry\s+out)\w*\s+(?:\w+\s+){0,3}obligations?\b",
 "ELECTIONS_ANY": r"\belections?\b",
 "ELECTIONS_FREE_HOLD": r"\b(?:free|fair|honest|popular|general|constitutional|democratic)\s+elections?\b|\bhold(?:ing|s)?\s+(?:of\s+)?(?:\w+\s+){0,2}elections?\b|\belections?\s+(?:will|would|shall|should|to|must|could)\s+be\s+held\b",
 "CONSTITUTIONAL": r"\bconstitutional(?:ly)?\b|\bconstitutions?\b",
 "CONTROL_ACQUIESCE": r"\beffective\s+control\b|\bin\s+(?:effective\s+|full\s+|complete\s+)?(?:control|possession)\s+of\s+the\s+(?:country|capital|government|machinery|territory|national)|\bcontrol\s+of\s+the\s+(?:country|machinery|capital|national\s+territory|territory|whole)|\bacquiescence\b|\bpopular\s+support\b|\bsupport\s+of\s+the\s+(?:people|nation|country)\b|\bconsent\s+of\s+the\s+(?:people|governed)\b|\bwill\s+of\s+the\s+people\b",
 "LIVES_PROPERTY": r"\b(?:american|foreign)\s+(?:lives|life|interests|property|properties|citizens|nationals)\b|\blives\s+and\s+property\b",
 "CA_TREATY": r"\btreaty\s+of\s+peace\s+and\s+amity\b|\bwashington\s+(?:treaty|treaties|conventions?)\b|\b(?:treaty|treaties|conventions?)\s+of\s+19(?:07|23)\b|\b19(?:07|23)\s+(?:treaty|treaties|conventions?)\b|\btobar\b",
 "CONSULT_ANY": r"\bconsult(?:ation|ations|ative|ed|ing|s)?\b",
 "CONSULT_FORMAL": r"\bresolution\s+(?:no\.\s+)?(?:xxii|22|xxxv|35)\b|\bpolitical\s+defen[cs]e\b|\bemergency\s+advisory\s+committee\b|\bbogot[aá]\s+resolution\b|\bmontevideo\s+committee\b",
 "AXIS_NAZI": r"\baxis\b|\bnazis?\b|\bnazism\b|\bfascis[mt]s?\b|\btotalitarian\w*\b",
 "COMMUNISM": r"\bcommunis[mt]s?\b|\bcommunistic\b|\bcastroi\w*|\bmarxis[mt]s?\b",   # v2: "soviet" moved to its own family
 "SOVIET": r"\bsoviets?\b",
 "HUMAN_RIGHTS": r"\bhuman\s+rights\b",
 "INTERVENTION": r"\bnon-?intervention\b|\bintervention\b",
 "LATIN_AMERICA": r"\blatin[\s-]+americ\w*",
 "CONTROL_POS": r"\bdepartment\s+of\s+state\b",
}
VARIANTS = {
 "recognize": r"\brecognize\b", "recognise": r"\brecognise\b", "recognized": r"\brecognized\b", "recognised": r"\brecognised\b",
 "recognizing": r"\brecognizing\b", "recognising": r"\brecognising\b", "recognition": r"(?<![-\w])recognition\b",
 "nonrecognition": r"\bnonrecognition\b", "non-recognition": r"\bnon-recognition\b", "unrecognized/-ised": r"\bunrecogni[sz]ed\b",
 "de facto": r"\bde\s+facto\b", "de-facto": r"\bde-facto\b", "defacto": r"\bdefacto\b",
 "coup d'etat (any accent/apostrophe)": r"\bcoups?\s+d[’'`]?\s*[ée]tat\b", "coup (bare)": r"\bcoups?\b(?!\s+d[’'`]?\s*[ée]tat)",
 "golpe": r"\bgolpes?\b", "junta": r"\bjunta\b", "juntas": r"\bjuntas\b", "Tobar": r"\btobar\b",
 "fulfill-": r"\bfulfill\w*", "fulfil-(single l)": r"\bfulfil(?!l)\w*",
}
CF = {k: re.compile(v, re.I) for k, v in FAM.items()}
CV = {k: re.compile(v, re.I) for k, v in VARIANTS.items()}
def text_of(el, skip):
    out = []
    def rec(e):
        tag = e.tag
        if tag in skip:
            if e.tail: out.append(e.tail)
            return
        if e.text: out.append(e.text)
        for c in e: rec(c); out.append(" ") if c.tag in BLOCK else None
        if e.tail: out.append(e.tail)
    if el.text: out.append(el.text)
    for c in el:
        rec(c)
        if c.tag in BLOCK: out.append(" ")
    return " ".join("".join(out).split())
def notes_of(el):
    parts = []
    for e in el.iter():
        if e.tag in (TEI + "note", TEI + "head"):
            parts.append(" ".join("".join(e.itertext()).split()))
    return " ".join(parts)
BLOCK = {TEI + t for t in ("p", "head", "opener", "closer", "dateline", "list", "item", "table", "row", "cell", "lb", "pb", "signed", "salute", "postscript", "quote", "div", "seg", "lg", "l")}
scope = {}
for r in csv.DictReader(open("out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE):
    scope.setdefault(r["volume_id"], set()).add(r["document_id"])
vols = sorted(scope)
prog = open("out/tei_progress.log", "a")
for v in vols:
    outp = f"out/tei/{v}.json"
    if os.path.exists(outp): continue
    t0 = time.time()
    raw = open(os.path.join(VOLDIR, v + ".xml"), encoding="utf-8").read()
    stripped = " ".join(re.sub(r"<[^>]+>", " ", raw).split())
    ctrl = {"pos_Department_of_State": len(re.findall(r"Department of State", stripped)),
            "pos_Department_of_State_ci": len(re.findall(r"department\s+of\s+state", stripped, re.I)),
            "neg_ZZZ_IMPOSSIBLE_ZZZ": len(re.findall(r"ZZZ_IMPOSSIBLE_ZZZ", stripped, re.I)),
            "chars_tagstripped": len(stripped)}
    root = ET.fromstring(raw.encode("utf-8"))
    docs = {}
    for div in root.iter(TEI + "div"):
        if div.get("type") != "document": continue
        did = div.get(XMLID)
        if did not in scope[v]: continue
        doc = text_of(div, {TEI + "note", TEI + "head"})
        app = notes_of(div)
        rec = {"dmin": div.get(FRUS + "doc-dateTime-min"), "dmax": div.get(FRUS + "doc-dateTime-max"),
               "doc_chars": len(doc), "app_chars": len(app),
               "fam_doc": {k: len(c.findall(doc)) for k, c in CF.items()},
               "fam_app": {k: len(c.findall(app)) for k, c in CF.items()},
               "var_doc": {k: len(c.findall(doc)) for k, c in CV.items()},
               "var_app": {k: len(c.findall(app)) for k, c in CV.items()}}
        docs[did] = rec
    json.dump({"volume_id": v, "controls": ctrl, "n_scope": len(scope[v]), "n_found": len(docs), "docs": docs}, open(outp, "w"))
    prog.write(f"{v}\t{len(docs)}/{len(scope[v])}\t{time.time()-t0:.1f}s\n"); prog.flush()
prog.write("DONE\n"); prog.flush()
