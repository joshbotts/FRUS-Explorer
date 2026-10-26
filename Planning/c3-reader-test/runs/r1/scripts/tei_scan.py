# TEI variant scan. Counting surface: for each <div type="document" subtype="historical-document">, the text with inline markup removed and
# block-level elements separated by a space, whitespace collapsed, case-insensitive. Two parts per document: BODY (everything except <note> descendants)
# and NOTES (all <note> descendants: footnotes and the source note). Editorial-note documents, front matter, chapter/compilation containers are not scanned.
# usage: tei_scan.py OUTDIR VOLUME_ID [VOLUME_ID ...]   (or: tei_scan.py OUTDIR --all)
import sys, re, os, glob, sqlite3, time
import xml.etree.ElementTree as ET
RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"
V = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
TEI = "{http://www.tei-c.org/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
FRUSNS = "{http://history.state.gov/ns/xslt/tei-ns}"
BLOCK = {"p", "head", "note", "lb", "pb", "opener", "closer", "dateline", "salute", "signed", "table", "row", "cell", "list", "item", "div", "postscript", "trailer", "label", "byline", "docDate", "bibl", "quote", "cit"}
I = re.I
# variant families (name, regex). Letters are matched case-insensitively; apostrophes: straight or curly.
APOS = "['’ʼ]"
VARIANTS = [
    ("recognition_noun", r"\brecognitions?\b"),
    ("recognize_verb_z", r"\brecogni[z](?:e|es|ed|ing)\b"),
    ("recognise_verb_s", r"\brecogni[s](?:e|es|ed|ing)\b"),
    ("unrecognized_z", r"\bunrecogni[z]ed\b"),
    ("unrecognised_s", r"\bunrecogni[s]ed\b"),
    ("nonrecognition_hyphen", r"\bnon-recogni"),
    ("nonrecognition_closed", r"\bnonrecogni"),
    ("nonrecognition_spaced", r"\bnon recogni"),
    ("non_recognition_emdash_or_other", r"\bnon[‐‑‒–—]recogni"),
    ("de_facto_space", r"\bde facto\b"),
    ("de_facto_hyphen", r"\bde-facto\b"),
    ("defacto_closed", r"\bdefacto\b"),
    ("de_jure_space", r"\bde jure\b"),
    ("de_jure_hyphen", r"\bde-jure\b"),
    ("coup_detat_acute_straight", r"\bcoups? d" + APOS + r"[é]tat\b"),
    ("coup_detat_plain_e", r"\bcoups? d" + APOS + r"etat\b"),
    ("coup_alone", r"\bcoups?\b"),
    ("golpe", r"\bgolpe\b"),
    ("junta", r"\bjuntas?\b"),
    ("revolution_family", r"\brevolut(?:ion|ions|ionary|ionaries|ionist|ionists)\b"),
    ("reconocimiento_spanish", r"\breconoc\w*"),
    ("CTRL_pos_department_of_state", r"\bdepartment of state\b"),
    ("CTRL_neg_zzz", r"zzz_impossible_zzz"),
    # the argued phrase families
    ("PH_recog_gov_6", r"recogni(?:tion\w*|[sz]\w*)(?:\W+\w+){0,6}?\W+(?:government|governments|regime|regimes|junta|administration)\b"),
    ("PH_gov_recog_6", r"\b(?:government|governments|regime|regimes|junta|administration)\W+(?:\w+\W+){0,6}?recogni(?:tion\w*|[sz]\w*)"),
    ("PH_withhold_recog", r"\b(?:withh[eo]ld\w*|refus\w+|declin\w+|den(?:y|ied|ying|ies)|postpon\w+|defer\w*)\W+(?:\w+\W+){0,4}?recogni(?:tion\w*|[sz]\w*)"),
]
RX = [(n, re.compile(p, I)) for n, p in VARIANTS]

def text_of(el, skip_notes, out):
    tag = el.tag.replace(TEI, "") if isinstance(el.tag, str) else ""
    if skip_notes and tag == "note":
        if el.tail:
            out.append(el.tail)
        return
    blk = tag in BLOCK
    if blk: out.append(" ")
    if el.text: out.append(el.text)
    for ch in el:
        text_of(ch, skip_notes, out)
    if blk: out.append(" ")
    if el.tail: out.append(el.tail)

def notes_text(doc):
    out = []
    for n in doc.iter(TEI + "note"):
        t = []
        text_of(n, False, t)
        # text_of appended n.tail at the end; drop it by recomputing without tail
        s = "".join(t)
        if n.tail and s.endswith(n.tail):
            s = s[:-len(n.tail)]
        out.append(s)
    return " ".join(out)

def body_text(doc):
    out = []
    # do not include the tail of the doc element itself
    if doc.text: out.append(doc.text)
    for ch in doc:
        text_of(ch, True, out)
    return "".join(out)

def collapse(s):
    return re.sub(r"\s+", " ", s).strip()

def scan_volume(vid, scope, fdoc, fvol):
    t0 = time.time()
    path = os.path.join(V, vid + ".xml")
    tot = {n: 0 for n, _ in RX}; tot_n = {n: 0 for n, _ in RX}
    ndocs = 0
    for ev, el in ET.iterparse(path, events=("end",)):
        if el.tag != TEI + "div":
            continue
        if el.get("type") != "document" or el.get("subtype") != "historical-document":
            continue
        did = el.get(XMLID)
        ndocs += 1
        b = collapse(body_text(el)); n = collapse(notes_text(el))
        dmin = el.get(FRUSNS + "doc-dateTime-min") or ""
        if dmin == "":
            for k, v in el.attrib.items():
                if k.endswith("doc-dateTime-min"): dmin = v
        row_b = []; row_n = []; any_hit = False
        for name, rx in RX:
            cb = len(rx.findall(b)); cn = len(rx.findall(n))
            tot[name] += cb + cn
            if cb + cn: tot_n[name] += 1
            row_b.append(cb); row_n.append(cn)
            if (cb or cn) and not name.startswith("CTRL_pos"): any_hit = True
        if (vid, did) in scope and (any_hit or True):
            fdoc.write("\t".join([vid, did, dmin[:25], str(len(b)), str(len(n))] + ["%d/%d" % (x, y) for x, y in zip(row_b, row_n)]) + "\n")
        el.clear()
    fvol.write("\t".join([vid, str(ndocs)] + ["%d/%d" % (tot[n], tot_n[n]) for n, _ in RX]) + "\n")
    fvol.flush(); fdoc.flush()
    return ndocs, time.time() - t0

if __name__ == "__main__":
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
    if sys.argv[2] == "--all":
        vols = sorted(os.path.basename(p)[:-4] for p in glob.glob(V + "/*.xml"))
    else:
        vols = sys.argv[2:]
    s = sqlite3.connect("file:%s/work/scope.db?mode=ro" % RUN, uri=True)
    scope = set(s.execute("SELECT volume_id, document_id FROM scope_docs WHERE latam=1 AND numbered=1 AND apparatus=0 AND ed2_dup=0"))
    hdr_vol = "volume_id\tn_historical_documents\t" + "\t".join(n + "(hits/docs)" for n, _ in RX) + "\n"
    hdr_doc = "volume_id\tdocument_id\tdoc_dateTime_min\tbody_chars\tnotes_chars\t" + "\t".join(n + "(body/notes)" for n, _ in RX) + "\n"
    fv = open(os.path.join(outdir, "variants_by_volume.tsv"), "a"); fd = open(os.path.join(outdir, "variants_latam_docs.tsv"), "a")
    if os.path.getsize(os.path.join(outdir, "variants_by_volume.tsv")) == 0: fv.write(hdr_vol)
    if os.path.getsize(os.path.join(outdir, "variants_latam_docs.tsv")) == 0: fd.write(hdr_doc)
    for v in vols:
        nd, dt = scan_volume(v, scope, fd, fv)
        print("%s docs=%d %.1fs" % (v, nd, dt), flush=True)
