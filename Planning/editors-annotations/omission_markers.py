#!/usr/bin/env python3
# The editors' bracketed omission markers in the FRUS TEI, measured for the sixteenth layer of
# the Editors' Annotations axis, "Marked editorial omissions" (2026-11-08;
# Planning/Editors-Annotations-Followups-2026-11-08.md, Lane 1).
# argv: <volumes dir> <manifest.json> <out.json>   (the tables and samples go to stdout)
# Run through Scripts/heavy.sh, as inventory.py is: one ElementTree parse per manifest volume,
# about a minute on the M5 MacBook. Read-only; writes only <out.json>. Stdlib only.
#
# What it measures. For every <div type="document"> inside <body>, the brackets "[…]" in the
# document's OWN text, its <note> children left out (a footnote's bracket is the editors' remark
# on the note, not an omission from the document), with <lb/> and <pb/> read as a space so that a
# bracket broken across a printed line is one span. Each bracket is classed by the lane's three
# patterns, the redaction exclusion, and the noise the plan names:
#   P1  ^\s*Here\s+follows?\b                "[Here follows discussion of …]"
#   P2  ^\s*Omitted\s+(here|from|are|is)\b    "[Omitted here is the Table of Contents.]", or, anywhere in
#       the bracket, \bOmitted\s+here\s+(is|are)\b: "[Agnew left at 10:35 a.m. Omitted here is …]"
#   P3  \b(has|have)\s+been\s+omitted\b, \bwhich\s+(is|are)\s+omitted\b or \bhere\s+omitted\b, anywhere
#   X   not\s+declassified anywhere: the Redactions layer, never this one, whatever else matches
# P1 and P2 are case-sensitive, as the plan wrote them: a lower-case "[here follows …]" sits
# mid-sentence, and a case-blind P2 took "[omitted from?]", an editor's query on the original.
# A document carries the layer when one bracket of its own text matches P1, P2 or P3 and not X.
# The first run (2026-11-08, the plan's three patterns, case-blind) read 40 hits a pattern with no
# false positive, and found "here omitted" and the mid-bracket "Omitted here is" in its residue,
# every sample an omission; this is the rule as fixed after that reading, the generator's too.
# Also recorded, for the questions the plan asks: the raw "omitted" bracket (the cloud sweep's
# figure); the same patterns inside notes (what the exclusion drops); "not declassified" by the
# scanner's own rule (every character of the document, notes included, no space at <lb/>) against
# the spaced text; the garbled-original remarks ("[apparent omission]", "[omission?]", "[sic]");
# the publication year from the header's date[@type="publication-date"]; and samples to read by
# eye, 40 a pattern, drawn with a fixed seed.
import json, re, sys, random, collections
import xml.etree.ElementTree as ET

TEI = "{http://www.tei-c.org/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
WS = re.compile(r"\s+")

P1 = re.compile(r"^\s*Here\s+follows?\b")
P2 = re.compile(r"^\s*Omitted\s+(here|from|are|is)\b|\bOmitted\s+here\s+(is|are)\b")
P3 = re.compile(r"\b(has|have)\s+been\s+omitted\b|\bwhich\s+(is|are)\s+omitted\b|\bhere\s+omitted\b")
LOWERCASE = re.compile(r"^\s*(here\s+follows?|omitted\s+(here|from|are|is))\b")   # not counted; measured
X = re.compile(r"not\s+declassified", re.I)
RAW_OMITTED = re.compile(r"\bomitted\b", re.I)
OMISSION_WORD = re.compile(r"\bomi(ssion|tted|t)\b", re.I)
GARBLED = re.compile(r"^\s*(apparent\s+omission|omission\??|omission\s+in\s+the\s+original|sic)\s*\??\s*$", re.I)
PRINTED_ELSEWHERE = re.compile(r"\b(infra|supra|elsewhere|hereafter|printed\s+(above|below)|see\s+(above|below))\b", re.I)
NOT_PRINTED = re.compile(r"\bnot\s+printed\b", re.I)
NOT_TRANSCRIBED = re.compile(r"\bnot\s+transcribed\b", re.I)
P2_MID = re.compile(r"\bOmitted\s+here\s+(is|are)\b")   # P2's second clause, measured on its own
HERE_OMITTED = re.compile(r"\bhere\s+omitted\b")          # P3's third clause, measured on its own
SEED = 20261108
SAMPLE = 40
MAX_BRACKET = 4000

# The plan's bands, by publication year.
BANDS = [("to 1899", None, 1899), ("1900–19", 1900, 1919), ("1920–39", 1920, 1939), ("1940–49", 1940, 1949),
         ("1950–59", 1950, 1959), ("1960–69", 1960, 1969), ("1970–79", 1970, 1979), ("1980–84", 1980, 1984),
         ("1985–89", 1985, 1989), ("1990–99", 1990, 1999), ("2000 on", 2000, None)]

def band(year):
    if year is None: return "unknown"
    for name, lo, hi in BANDS:
        if (lo is None or year >= lo) and (hi is None or year <= hi): return name
    return "unknown"

def local(tag):
    return tag[len(TEI):] if tag.startswith(TEI) else tag

def publication_year(root):
    header = root.find(TEI + "teiHeader")
    if header is None: return None
    for d in header.iter(TEI + "date"):
        if d.get("type") == "publication-date":
            for candidate in ((d.text or ""), d.get("when") or ""):
                m = re.search(r"\d{4}", candidate)
                if m: return int(m.group(0))
    return None

def gather(el, own, notes, in_note, is_root):
    """Append the text of `el` to `own` or `notes`: a <note> subtree goes to `notes`, everything
    else to `own`; a nested document is left to its own scan; <lb/> and <pb/> become a space."""
    tag = local(el.tag)
    if not is_root and tag == "div" and el.get("type") == "document":
        if el.tail: (notes if in_note else own).append(el.tail)
        return
    here = in_note or tag == "note"
    sink = notes if here else own
    if tag in ("lb", "pb"): sink.append(" ")
    if el.text: sink.append(el.text)
    for ch in el:
        gather(ch, own, notes, here, False)
    if not is_root and el.tail:
        (notes if in_note else own).append(el.tail)

def brackets(text):
    """Every bracketed span of `text`, nesting followed, longest first at a position; a span that
    never closes within MAX_BRACKET characters is dropped."""
    out = []
    i, n = 0, len(text)
    while i < n:
        if text[i] != "[":
            i += 1
            continue
        depth, j = 0, i
        while j < n and j - i <= MAX_BRACKET:
            c = text[j]
            if c == "[": depth += 1
            elif c == "]":
                depth -= 1
                if depth == 0: break
            j += 1
        if j < n and j - i <= MAX_BRACKET and text[j] == "]":
            out.append(WS.sub(" ", text[i + 1:j]).strip())
            i = j + 1
        else:
            i += 1
    return out

def classify(inner):
    kinds = set()
    if P1.search(inner): kinds.add("P1")
    if P2.search(inner): kinds.add("P2")
    if P3.search(inner): kinds.add("P3")
    if X.search(inner): kinds.add("X")
    return kinds

def survey(path, volume_id, samples):
    root = ET.parse(path).getroot()
    year = publication_year(root)
    body = root.find(TEI + "text/" + TEI + "body")
    vol = dict(year=year, docs=0, P1=0, P2=0, P3=0, layer=0, layer_or_X=0, X_only_hits=0,
               raw_omitted=0, note_only=0, garbled=0, not_printed=0, not_transcribed=0, p2_mid=0, here_omitted=0, elsewhere=0,
               notdecl_scanner=0, notdecl_spaced=0, notdecl_own=0, lowercase_opener=0)
    if body is None:
        return vol
    for div in body.iter(TEI + "div"):
        if div.get("type") != "document": continue
        doc_id = div.get(XMLID) or ""
        vol["docs"] += 1
        own, notes = [], []
        gather(div, own, notes, False, True)
        own_text = "".join(own); notes_text = "".join(notes)
        whole_spaced = own_text + " " + notes_text
        # The scanner's own text: every character, notes included, nothing at <lb/>.
        glued = "".join(div.itertext())
        if X.search(glued): vol["notdecl_scanner"] += 1
        if X.search(whole_spaced): vol["notdecl_spaced"] += 1
        if X.search(own_text): vol["notdecl_own"] += 1
        hit = set(); hit_in_notes = set()
        raw = False; garbled = False; not_printed = False; elsewhere = False; x_only = False
        not_transcribed = False; p2_mid = False; here_omitted = False; lowercase = False
        for inner in brackets(own_text):
            kinds = classify(inner)
            if RAW_OMITTED.search(inner): raw = True
            if GARBLED.search(inner): garbled = True
            if NOT_PRINTED.search(inner) and not kinds - {"X"}: not_printed = True
            if NOT_TRANSCRIBED.search(inner) and not kinds - {"X"}: not_transcribed = True
            if P2_MID.search(inner) and not P2.match(inner) and "X" not in kinds:
                p2_mid = True
                samples["p2_mid"].append((volume_id, year, doc_id, inner[:300]))
            if HERE_OMITTED.search(inner) and not (kinds - {"P3", "X"}) and "X" not in kinds:
                here_omitted = True
                samples["here_omitted"].append((volume_id, year, doc_id, inner[:300]))
            if LOWERCASE.search(inner) and not kinds:
                lowercase = True
                samples["lowercase_not_counted"].append((volume_id, year, doc_id, inner[:300]))
            positive = kinds - {"X"}
            if positive and "X" in kinds:
                x_only = True
                samples["excluded_by_X"].append((volume_id, year, doc_id, inner[:300]))
            elif positive:
                hit |= positive
                for k in positive:
                    samples[k].append((volume_id, year, doc_id, inner[:300]))
                if PRINTED_ELSEWHERE.search(inner):
                    elsewhere = True
                    samples["elsewhere"].append((volume_id, year, doc_id, inner[:300]))
            elif OMISSION_WORD.search(inner) and "X" not in kinds:
                samples["residue_omission_word"].append((volume_id, year, doc_id, inner[:300]))
        # Whole-paragraph brackets that match nothing: the editors' other phrasings.
        for p in div.iter(TEI + "p"):
            t = WS.sub(" ", "".join(p.itertext())).strip()
            if t.startswith("[") and t.endswith("]") and len(t) > 12:
                inner = t[1:-1]
                if not (classify(inner) & {"P1", "P2", "P3", "X"}):
                    samples["residue_paragraph"].append((volume_id, year, doc_id, inner[:200]))
        for inner in brackets(notes_text):
            kinds = classify(inner) - {"X"}
            if kinds and "X" not in classify(inner):
                hit_in_notes |= kinds
                samples["in_notes"].append((volume_id, year, doc_id, inner[:300]))
        for k in ("P1", "P2", "P3"):
            if k in hit: vol[k] += 1
        if hit: vol["layer"] += 1
        if hit or x_only: vol["layer_or_X"] += 1
        if x_only and not hit: vol["X_only_hits"] += 1
        if hit_in_notes and not hit: vol["note_only"] += 1
        if raw: vol["raw_omitted"] += 1
        if garbled: vol["garbled"] += 1
        if not_printed: vol["not_printed"] += 1
        if not_transcribed: vol["not_transcribed"] += 1
        if p2_mid: vol["p2_mid"] += 1
        if here_omitted: vol["here_omitted"] += 1
        if lowercase: vol["lowercase_opener"] += 1
        if elsewhere: vol["elsewhere"] += 1
    return vol

def main():
    vdir, manifest, out = sys.argv[1:4]
    man = json.load(open(manifest))
    rng = random.Random(SEED)
    samples = collections.defaultdict(list)
    res = {}
    for i, v in enumerate(man):
        res[v["volumeId"]] = survey(f"{vdir}/{v['filename']}", v["volumeId"], samples)
        if i % 50 == 0: print(f"… {i} {v['volumeId']}", file=sys.stderr, flush=True)
    # The JSON keeps every distinct bracket of the smaller kinds and the first 200, in sorted order,
    # of the three largest (P1, P2 and the residue paragraphs run to thousands), with each kind's
    # full count; the 40 samples the tables print are drawn from the full pools below.
    pools = {k: sorted(set(map(tuple, s))) for k, s in samples.items()}
    kept = {k: (v[:200] if k in ("P1", "P2", "residue_paragraph") else v) for k, v in pools.items()}
    json.dump(dict(volumes=res, sampleCounts={k: len(v) for k, v in pools.items()}, samples=kept),
              open(out, "w"), ensure_ascii=False)

    vols = res
    print(f"# Bracketed omission markers over {len(vols)} manifest volumes (seed {SEED})\n")
    missing_year = [k for k, v in vols.items() if v["year"] is None]
    print(f"Volumes with no publication year read: {len(missing_year)} {missing_year[:10]}\n")

    def table(keys, title):
        print(f"## {title}\n")
        names = [b[0] for b in BANDS]
        print("| | " + " | ".join(names) + " | all |")
        print("|---|" + "---|" * (len(names) + 1))
        for label, fn in keys:
            cells = []
            total = 0
            for name in names:
                members = [v for v in vols.values() if band(v["year"]) == name]
                value = fn(members)
                cells.append(str(value)); total += value
            print(f"| {label} | " + " | ".join(cells) + f" | {total} |")
        print()

    count_vols = lambda key: (lambda ms: sum(1 for v in ms if v[key] > 0))
    sum_docs = lambda key: (lambda ms: sum(v[key] for v in ms))
    table([("Volumes", lambda ms: len(ms)),
           ("… with P1 `[Here follows …]`", count_vols("P1")),
           ("… with P2 `[Omitted here …]`", count_vols("P2")),
           ("… with P3 `… has been omitted …`", count_vols("P3")),
           ("… with the layer (P1|P2|P3, not X)", count_vols("layer")),
           ("… raw `omitted` bracket (the cloud sweep's figure)", count_vols("raw_omitted")),
           ("… redactions marked (scanner's rule)", count_vols("notdecl_scanner")),
           ], "Volumes by publication year")
    table([("Documents", sum_docs("docs")),
           ("P1", sum_docs("P1")), ("P2", sum_docs("P2")), ("P3", sum_docs("P3")),
           ("the layer", sum_docs("layer")),
           ("raw `omitted`", sum_docs("raw_omitted")),
           ("a positive pattern inside a `not declassified` bracket (excluded)", sum_docs("X_only_hits")),
           ("a positive only inside a note (not counted)", sum_docs("note_only")),
           ("garbled-original remark", sum_docs("garbled")),
           ("`not printed` bracket, no pattern", sum_docs("not_printed")),
           ("`not transcribed` bracket, no pattern", sum_docs("not_transcribed")),
           ("P2 by its mid-bracket clause alone", sum_docs("p2_mid")),
           ("P3 by `here omitted` alone", sum_docs("here_omitted")),
           ("P1–P3 saying printed infra/supra/elsewhere", sum_docs("elsewhere")),
           ("lower-case `[here follows` or `[omitted here`, not counted", sum_docs("lowercase_opener")),
           ("not declassified: scanner's text", sum_docs("notdecl_scanner")),
           ("not declassified: spaced text", sum_docs("notdecl_spaced")),
           ("not declassified: own text only", sum_docs("notdecl_own")),
           ], "Documents by publication year")

    pre = {k: v for k, v in vols.items() if v["year"] is not None and v["year"] < 1925}
    print(f"## The 1925 gate\n\nVolumes published before 1925: {len(pre)}; with the layer: "
          f"{sum(1 for v in pre.values() if v['layer'])} ({sum(v['layer'] for v in pre.values())} documents); "
          f"with P1: {sum(1 for v in pre.values() if v['P1'])}; with raw omitted: {sum(1 for v in pre.values() if v['raw_omitted'])}.")
    print("Pre-1925 volumes with the layer, by id (documents): " + ", ".join(
        f"{k} ({v['layer']})" for k, v in sorted(pre.items()) if v["layer"]) + "\n")

    diff = [(k, v["notdecl_scanner"], v["notdecl_spaced"]) for k, v in vols.items() if v["notdecl_scanner"] != v["notdecl_spaced"]]
    print(f"## Scanner text against spaced text for `not declassified`\n\nVolumes that differ: {len(diff)} {diff[:20]}")
    print(f"Volumes with a redaction marked: {sum(1 for v in vols.values() if v['notdecl_scanner'])} "
          f"(the shipped index says 210)\n")

    print("## Samples, 40 a kind, read by eye\n")
    for kind in ("P1", "P2", "P3", "elsewhere", "excluded_by_X", "in_notes", "p2_mid", "here_omitted",
                 "lowercase_not_counted", "residue_omission_word", "residue_paragraph"):
        pool = sorted(set(map(tuple, samples[kind])))
        print(f"### {kind}: {len(pool)} distinct brackets\n")
        for volume_id, year, doc_id, inner in rng.sample(pool, min(SAMPLE, len(pool))):
            print(f"- {volume_id} ({year}) {doc_id}: [{inner}]")
        print()
    print("## The residue's first two words (whole-paragraph brackets matching nothing)\n")
    heads = collections.Counter(" ".join(s[3].split()[:2]).lower() for s in samples["residue_paragraph"])
    for words, n in heads.most_common(40):
        print(f"- {n}: {words}")
    print("\ndone", len(vols))

if __name__ == "__main__":
    sys.setrecursionlimit(100000)
    main()
