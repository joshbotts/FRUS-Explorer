#!/usr/bin/env python3
# Per-volume inventory of the editorial annotation layers in the FRUS TEI (2026-11-06).
# argv: <volumes dir> <manifest.json> <out.json>
# Run through Scripts/heavy.sh: it parses all 3.34 GB of the manifest's TEI (about a minute on
# the M5 MacBook). Read-only; writes only <out.json>. The design it measures for is
# Planning/Editors-Annotations-Design-2026-11-06.md, and tables.py turns its output into every
# figure that document cites.
# One ElementTree parse per manifest volume. Every element is attributed to its innermost
# <div type="document">; for each document we record WHICH annotation features it carries
# (presence, not counts), so a volume's figure for a feature is "documents carrying it".
# Also recorded: a generic presence inventory (tag, tag@type=value, tag@attr) for discovery,
# the front/back-matter sections, the persons and terms lists, page breaks and page scans.
import json, re, sys, collections
import xml.etree.ElementTree as ET

TEI = "{http://www.tei-c.org/ns/1.0}"
FRUS = "{http://history.state.gov/frus/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
CLASSIF = re.compile(r"\b(top secret|secret|confidential|limited official use|unclassified|"
                     r"eyes only|nodis|exdis|limdis|strictly confidential)\b", re.I)
NOTDECL = re.compile(r"not declassified", re.I)
WS = re.compile(r"\s+")

def local(tag):
    if tag.startswith(TEI): return tag[len(TEI):]
    if tag.startswith("{"):
        ns, _, l = tag[1:].partition("}")
        return ("frus:" if "frus" in ns else "x:") + l
    return tag

def text_of(el):
    return WS.sub(" ", "".join(el.itertext()))

def xref_kind(t):
    t = t.strip()
    if t.startswith("http") or t.startswith("mailto"): return "url"
    if t.startswith("#pg_") or "#pg_" in t: return "page"
    if re.search(r"#d\d+fn\d+|#.*fn\d+$", t): return "footnote"
    if t.startswith("#d") or t.startswith("#"):
        return "doc" if re.match(r"#d\d", t) else "internal-other"
    if t.startswith("frus"): return "other-volume"
    return "other"

def survey(path):
    root = ET.parse(path).getroot()
    vol = dict(docs=0, docs_body=0, docs_front=0, docs_back=0, edn=0, hist=0,
               pb=0, pb_facs=0, surfaces=0, figures=0,
               persons_entries=0, terms_entries=0)
    feat = collections.Counter()      # documents (body) carrying a feature
    disc = collections.Counter()      # generic discovery keys, documents carrying them
    sections = []                     # (region, subtype, xml:id, head) of front/back sections
    ana_prefix = collections.Counter()

    def scan_doc(div, region):
        f = set(); g = set()
        st = div.get("subtype") or ""
        if st == "editorial-note": f.add("editorial_note")
        if div.get(FRUS + "doc-dateTime-min"): f.add("doc_dated")
        if (div.get("n") or "").strip(): f.add("doc_numbered")
        ana = div.get("ana") or ""
        if "#p_" in ana: f.add("ana_persons")
        for tok in ana.split():
            ana_prefix[tok.split("_")[0][:12]] += 1
        stack = [(div, False, False, False)]
        while stack:
            el, in_src, in_opener, in_head = stack.pop()
            tag = local(el.tag)
            if el is not div and tag == "div" and el.get("type") == "document":
                continue                                  # nested document scanned on its own
            if el is not div:
                g.add(tag)
                if el.get("type"): g.add(f"{tag}@type={el.get('type')}")
                for a in el.attrib:
                    g.add(f"{tag}@{local(a) if a.startswith('{') else a}")
            typ = el.get("type") or ""
            if tag == "persName":
                if el.get("corresp") or el.get("ref"): f.add("pers_linked")
                else: f.add("pers_unlinked")
                if typ in ("from", "to"):
                    f.add("from_to")
                    if el.get("corresp") or el.get("ref"): f.add("from_to_linked")
            elif typ in ("from", "to"):
                f.add("from_to")
            if tag == "gloss" and (el.get("target") or el.get("ref")): f.add("terms_linked")
            if tag == "note":
                if typ == "source":
                    f.add("source_note")
                    f.add("source_note_inline" if el.get("rend") == "inline" else "source_note_footnote")
                    if CLASSIF.search(text_of(el)): f.add("classification")
                    in_src = True
                elif not in_src:
                    f.add("footnote")
            if tag == "opener": in_opener = True
            if tag == "head": in_head = True
            if tag in ("seg", "hi") and in_opener and CLASSIF.search(text_of(el)): f.add("classification")
            if tag == "ref" and el.get("target"):
                f.add("xref"); f.add("xref_" + xref_kind(el.get("target")))
            if tag == "date" and (el.get("when") or el.get("from") or el.get("notBefore")):
                f.add("date_when")
            if tag == "placeName": f.add("place")
            if tag == "pb": f.add("pb")
            if tag == "figure": f.add("figure")
            if tag == "table": f.add("table")
            if tag in ("orgName", "geogName", "rs", "term", "name"): f.add("tag_" + tag)
            if el.text and NOTDECL.search(el.text): f.add("not_declassified")
            if el.tail and el is not div and NOTDECL.search(el.tail): f.add("not_declassified")
            for ch in el:
                stack.append((ch, in_src, in_opener, in_head))
        return f, g

    def walk(el, region, in_doc):
        nonlocal vol
        tag = local(el.tag)
        if tag in ("front", "body", "back"): region = tag
        if tag == "pb":
            vol["pb"] += 1
            if el.get("facs"): vol["pb_facs"] += 1
        if tag == "surface": vol["surfaces"] += 1
        if tag == "figure": vol["figures"] += 1
        if tag == "div":
            t, st, xid = el.get("type") or "", el.get("subtype") or "", el.get(XMLID) or ""
            if t == "document":
                vol["docs"] += 1
                vol["docs_" + (region or "body")] = vol.get("docs_" + (region or "body"), 0) + 1
                if (el.get("subtype") or "") == "editorial-note": vol["edn"] += 1
                else: vol["hist"] += 1
                if region == "body":
                    f, g = scan_doc(el, region)
                    feat.update(f); disc.update(g)
            elif region in ("front", "back") and not in_doc and t in ("section", "toc", "chapter", "compilation"):
                head = el.find(TEI + "head")
                sections.append((region, t, st, xid, (text_of(head).strip()[:60] if head is not None else "")))
            low = xid.lower()
            if low in ("persons", "persname", "listofpersons"):
                vol["persons_entries"] += sum(1 for p in el.iter(TEI + "persName") if p.get(XMLID))
            if low in ("terms", "abbreviations", "listofabbreviations"):
                vol["terms_entries"] += sum(1 for p in el.iter() if p.get(XMLID) and local(p.tag) in ("term", "gloss", "label", "item"))
            in_doc = in_doc or t == "document"
        for ch in el:
            walk(ch, region, in_doc)

    walk(root, None, False)
    return dict(vol=vol, feat=dict(feat), disc=dict(disc), sections=sections, ana=dict(ana_prefix))

def main():
    vdir, manifest, out = sys.argv[1:4]
    man = json.load(open(manifest))
    res = {}
    for i, v in enumerate(man):
        res[v["volumeId"]] = survey(f"{vdir}/{v['filename']}")
        if i % 50 == 0: print(i, v["volumeId"], flush=True)
    json.dump(res, open(out, "w"))
    print("done", len(res))

if __name__ == "__main__":
    sys.setrecursionlimit(100000)
    main()
