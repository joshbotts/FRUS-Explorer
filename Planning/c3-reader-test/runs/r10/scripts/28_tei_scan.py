# TEI scan (the only surface for spelling variants and the document/apparatus split).
# For every <div type="document"> in every volume file: build two tag-stripped, whitespace-collapsed texts —
#   DOC  = the document's own text: every descendant text EXCEPT <note> subtrees (source note and footnotes) and the
#          document's own <head> (the editors' title);
#   NOTE = the text of the document's <note> elements other than type="source" (the editors' footnotes).
# Count literal variant forms (Python re, CASE-SENSITIVE, word-bounded) on each surface. Controls in the same pass:
# "Department of State" (positive) and "ZZZ_IMPOSSIBLE_ZZZ" (negative), counted on DOC+NOTE+head (whole div).
# v2 (2026-10-25): text fragments are joined with no separator before whitespace-collapsing (v1 joined them with a
# space, which split a word wherever markup began or ended inside it; v1 output kept in out/tei_v1_spacejoin/).
# Output: out/tei/<volume>.tsv (one row per document: volume, id, tei_date_min, then counts DOC|NOTE per variant),
#         out/tei_progress.txt (one line per finished volume). Resumable: skips volumes already written.
import os, re, sys, time
from lxml import etree
V = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes/"
OUT = "/Users/jbotts/frus-analysis/c3/runs/r10/out/tei/"
os.makedirs(OUT, exist_ok=True)
TEI = "{http://www.tei-c.org/ns/1.0}"
FRUS = "{http://history.state.gov/frus/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
AP = "['’]"
VARIANTS = [
 ("recognize", r"\brecognize\b"), ("recognized", r"\brecognized\b"), ("recognizes", r"\brecognizes\b"), ("recognizing", r"\brecognizing\b"),
 ("Recognize_cap", r"\bRecogni[sz]\w*"),
 ("recognise", r"\brecognise\b"), ("recognised", r"\brecognised\b"), ("recognises", r"\brecognises\b"), ("recognising", r"\brecognising\b"),
 ("recognition", r"\brecognitions?\b"), ("Recognition_cap", r"\bRecognitions?\b"), ("RECOGNITION_caps", r"\bRECOGNI[SZT]\w*"),
 ("nonrecognition", r"\bnonrecognition\b"), ("non-recognition", r"\b[Nn]on-recognition\b"), ("non_recognition_space", r"\b[Nn]on recognition\b"),
 ("Nonrecognition_cap", r"\bNonrecognition\b"), ("unrecognized", r"\bunrecogni[sz]ed\b"),
 ("de_facto", r"\b[Dd]e facto\b"), ("de-facto", r"\b[Dd]e-facto\b"), ("defacto", r"\b[Dd]efacto\b"), ("de_jure", r"\b[Dd]e[ -]jure\b"),
 ("coup_detat", r"\b[Cc]oups? d" + AP + r"[ée]tat\b|\b[Cc]oups? d" + AP + r"[EÉ]tat\b"), ("coup_detat_noapos", r"\b[Cc]oups? d[ée]tat\b"),
 ("coup_bare", r"\b[Cc]oups?\b(?! d" + AP + r"?[ée]tat)"), ("golpe", r"\b[Gg]olpes?\b"), ("cuartelazo", r"\b[Cc]uartelazo\b"),
 ("junta", r"\bjuntas?\b"), ("Junta_cap", r"\bJuntas?\b"), ("JUNTA_caps", r"\bJUNTAS?\b"),
 ("by_force", r"\bby force\b"), ("force_of_arms", r"\bforce of arms\b"),
 ("international_obligations", r"\binternational obligations?\b"), ("free_elections", r"\bfree elections?\b"),
 ("CTRL_DeptOfState", r"\bDepartment of State\b"), ("CTRL_impossible", r"ZZZ_IMPOSSIBLE_ZZZ"),
]
RX = [(n, re.compile(p)) for n, p in VARIANTS]
def collect(el, doc, note, top):
    # text of el itself
    tag = el.tag if isinstance(el.tag, str) else ""
    if tag == TEI + "note":
        if el.get("type") != "source":
            note.append("".join(el.itertext()))
        return
    if tag == TEI + "head" and not top:
        pass
    if el.text: doc.append(el.text)
    for ch in el:
        ctag = ch.tag if isinstance(ch.tag, str) else ""
        if ctag == TEI + "head" and top:
            pass  # document's own head: skipped from DOC
        else:
            collect(ch, doc, note, False)
        if ch.tail: doc.append(ch.tail)
files = sorted(f for f in os.listdir(V) if f.endswith(".xml"))
start = time.time()
for fn in files:
    vol = fn[:-4]
    outp = OUT + vol + ".tsv"
    if os.path.exists(outp): continue
    rows = []
    ndoc = 0
    for ev, el in etree.iterparse(V + fn, events=("end",), tag=TEI + "div", huge_tree=True):
        if el.get("type") != "document": continue
        did = el.get(XMLID)
        doc, note = [], []
        collect(el, doc, note, True)
        D = " ".join("".join(doc).split()); N = " ".join(" ".join(note).split())
        W = " ".join("".join(el.itertext()).split())
        counts = []
        for n, rx in RX:
            if n.startswith("CTRL"):
                counts.append("%d|0" % len(rx.findall(W)))
            else:
                counts.append("%d|%d" % (len(rx.findall(D)), len(rx.findall(N))))
        rows.append("\t".join([vol, did or "", (el.get(FRUS + "doc-dateTime-min") or "")[:10], str(len(D)), str(len(N))] + counts))
        ndoc += 1
        el.clear()
    with open(outp + ".tmp", "w") as f:
        f.write("\n".join(rows) + ("\n" if rows else ""))
    os.rename(outp + ".tmp", outp)
    with open(OUT + "../tei_progress.txt", "a") as f:
        f.write("%s\t%d\t%.0fs\n" % (vol, ndoc, time.time() - start))
print("done", len(files), "files", "%.0fs" % (time.time() - start), flush=True)
