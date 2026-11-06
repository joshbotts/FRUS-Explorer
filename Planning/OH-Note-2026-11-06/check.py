#!/usr/bin/env python3
# Every figure in Planning/OH-Note-2026-11-06.md, the draft note to the Office of the Historian
# for decision 6 of Planning/Editors-Annotations-Design-2026-11-06.md, from one run (2026-11-06).
# argv: <frus checkout> <inventory.json> <volume-annotations-index.json>   (stdout → check.out)
#   <frus checkout>  a clone of HistoryAtState/frus; the run prints its commit, which the note's
#                    line numbers are relative to.
#   inventory.json   Planning/editors-annotations/inventory.json, the design's TEI pass over the
#                    553 volumes the app lists, at the same corpus commit: the counts over every
#                    volume's lists of persons and terms come from it.
#   volume-annotations-index.json   FRUSExplorer/Resources/, for each volume's era band.
# Run through Scripts/heavy.sh: it parses the TEI of all 553 volumes (about a minute on the M5
# MacBook). Read-only; stdlib only. ElementTree gives no line numbers, so each line cited is found
# in the raw text by the pattern printed beside it.
import json, re, subprocess, sys, xml.etree.ElementTree as ET
from collections import Counter

FRUS, INVENTORY, ANNOTATIONS = sys.argv[1:4]
VOL = FRUS + "/volumes"
TEI = "{http://www.tei-c.org/ns/1.0}"
XML_ID = "{http://www.w3.org/XML/1998/namespace}id"
FRUS_NS = "{http://history.state.gov/frus/ns/1.0}"
# A despatch number standing alone: "No. 3.", "No 314.]", "*No. 9." (frus1872p2v5 stars some).
SERIAL = re.compile(r"\*?No\.? ?\d+[a-zA-Z]?\.?\]?")
# Elements a printed despatch number is encoded as, read in the volumes of 1861–1898.
CARRIERS = {"note", "seg", "p", "head", "hi", "label", "dateline"}


def raw_text(e):
    """The element's text without margin notes and nested notes (a footnote is not the line)."""
    parts = [e.text or ""]
    for c in e:
        if not (c.tag == TEI + "note" or (c.tag == TEI + "seg" and c.get("type") == "margin")):
            parts.append(raw_text(c))
        parts.append(c.tail or "")
    return "".join(parts)


def text(e):
    return " ".join(raw_text(e).split())


def line_of(raw, pattern, start=0):
    m = re.compile(pattern).search(raw, start)
    return (raw.count("\n", 0, m.start()) + 1) if m else None


def documents(root):
    return [d for d in root.iter(TEI + "div") if d.get("type") == "document"]


def load(name):
    path = "{}/{}.xml".format(VOL, name)
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    return raw, ET.parse(path).getroot()


def lists_and_links(name):
    raw, root = load(name)
    docs = documents(root)
    print("{}: {} documents".format(name, len(docs)))
    ids = {}
    for sec, tag in (("persons", "persName"), ("terms", "term")):
        div = next((d for d in root.iter(TEI + "div") if d.get(XML_ID) == sec), None)
        if div is None:
            ids[sec] = set()
            print("  {}: no such division".format(sec))
            continue
        head = div.find(TEI + "head")
        entry_ids = {e.get(XML_ID) for e in div.iter(TEI + tag) if e.get(XML_ID)}
        entries = [i for l in div.findall(TEI + "list") for i in l.findall(TEI + "item")]
        ids[sec] = entry_ids
        pattern = 'xml:id="{}"'.format(sec)
        print('  {}: "{}", subtype "{}", {} at line {}; {} entries, {} {} ids'.format(
            sec, text(head) if head is not None else "", div.get("subtype") or "", pattern,
            line_of(raw, pattern), len(entries), len(entry_ids), tag))
    named = [(d, e) for d in docs for e in d.iter(TEI + "persName") if e.get("corresp")]
    own = [e for _, e in named if e.get("corresp").lstrip("#") in ids["persons"]]
    glossed = [(d, e) for d in docs for e in d.iter(TEI + "gloss") if e.get("target")]
    print("  documents linking a name (persName/@corresp): {} ({} links, {} to this volume's list)".format(
        len({id(d) for d, _ in named}), len(named), len(own)))
    print("  documents linking a term (gloss/@target): {} ({} links)".format(
        len({id(d) for d, _ in glossed}), len(glossed)))
    # Names tagged with no link, and where they stand.
    bare_docs, where = set(), Counter()
    for d in docs:
        parent = {c: p for p in d.iter() for c in p}
        for e in d.iter(TEI + "persName"):
            if e.get("corresp"):
                continue
            bare_docs.add(id(d))
            chain, p = [], parent.get(e)
            while p is not None and p is not d:
                chain.append(p.tag.replace(TEI, ""))
                p = parent.get(p)
            where["signed" if "signed" in chain else ("head" if "head" in chain else "elsewhere")] += 1
    print("  names tagged with no @corresp: {} in {} documents; {}".format(
        sum(where.values()), len(bare_docs), dict(where)))
    anas = [(d.get(XML_ID), d.get("ana")) for d in docs if d.get("ana")]
    tokens = [t for _, a in anas for t in a.split()]
    resolved = [t for t in tokens if t.lstrip("#") in ids["persons"] | ids["terms"]]
    by_list = Counter("persons" if t.lstrip("#") in ids["persons"] else "terms" for t in resolved)
    print("  documents with a document-level @ana: {}; {} pointers, {} resolving to the lists {}".format(
        len(anas), len(tokens), len(resolved), dict(by_list)))
    if anas:
        print('  first: {} at line {} (pattern ana="#p_): ana="{}"'.format(
            anas[0][0], line_of(raw, 'ana="#p_'), anas[0][1]))


def git(*args):
    return subprocess.run(["git", "-C", FRUS] + list(args), capture_output=True, text=True).stdout.strip()


inventory = json.load(open(INVENTORY))
print("corpus:", git("log", "-1", "--format=%H %cs"))
print("volumes (the inventory's, the app's manifest):", len(inventory))
print()

print("== 0. The commits and checks the note cites")
for commit in ("e008aee30", "5b6aa8608"):
    print("  " + git("show", "-s", "--format=%h %cs %s", commit))
patch = git("show", "5b6aa8608", "--", "volumes/frus1981-88v16.xml").split("\n")
print('  5b6aa8608 in frus1981-88v16.xml: added lines with ana="#p_ {}, with corresp="#p_ {}, '
      'with gloss target="#t_ {}'.format(
          *(sum(1 for l in patch if l.startswith("+") and s in l)
            for s in ('ana="#p_', 'corresp="#p_', 'gloss target="#t_'))))
print("  frus1977-80v27's persons list first appears in:", git(
    "log", "--reverse", "--format=%h %cs %s", "-S", 'xml:id="persons"', "--",
    "volumes/frus1977-80v27.xml").split("\n")[0])
for needle in ('corresp="#p_', 'gloss target="#t_'):
    print("  commits to frus1977-80v27.xml adding or removing {}: {}".format(needle, git(
        "log", "--format=%h", "-S", needle, "--", "volumes/frus1977-80v27.xml") or "none"))
for path, pattern in (("schema/add-front-matter-section-subtype.xsl", r"\[Pp\]ersons\|"),
                      ("schema/frus-ids.sch", r"tei:persName\[starts-with\(@corresp, '#'\)\]")):
    with open(FRUS + "/" + path, encoding="utf-8") as f:
        print("  {}: line {} ({})".format(path, line_of(f.read(), pattern), pattern))
print()
print("== 1. Lists of persons and terms, and the links to them")
for name in ["frus1977-80v27", "frus1981-88v16", "frus1977-80v26", "frus1969-76v17",
             "frus1969-76ve09p2", "frus1941-43"]:
    lists_and_links(name)
print()

print("== 2. Every volume's lists (inventory.json): volumes whose list has entries, by the")
print("   division's subtype and whether any document links an entry inline")
for sec, entries_key, linked_key in (("persons", "persons_entries", "pers_linked"),
                                     ("terms", "terms_entries", "terms_linked")):
    cells = Counter()
    for vid, v in inventory.items():
        division = next((s for s in v["sections"] if s[3] == sec), None)
        if division is None or v["vol"].get(entries_key, 0) == 0:
            continue
        cells[(division[2] or "(none)", v["feat"].get(linked_key, 0) > 0)] += 1
        if division[2] != "index" or v["feat"].get(linked_key, 0) == 0:
            print("  {} {}: subtype {}, {} entries, {} documents link inline".format(
                sec, vid, division[2] or "(none)", v["vol"].get(entries_key, 0),
                v["feat"].get(linked_key, 0)))
    print("  {}: {} volumes; {}".format(sec, sum(cells.values()), sorted(cells.items())))
    print("  {}: other than frus1977-80v27, {} volumes, of which {} link inline".format(
        sec, sum(cells.values()) - 1, sum(n for (sub, linked), n in cells.items() if linked)))
print("  volumes whose documents point at their persons by a document-level @ana:",
      sorted(vid for vid, v in inventory.items() if v["feat"].get("ana_persons")))
print()

print("== 3. Numbers in the form 'No. 7.': elements whose whole text is one (margin notes and")
print("   footnotes set aside), and the source notes that hold one, at a document's head or in an inclosure")
bands = {vid: row[0] for vid, row in json.load(open(ANNOTATIONS))["volumes"].items()}
era = sorted(vid for vid in inventory if bands.get(vid) == "1861-1898")
totals, labels, carriers_by_volume = Counter(), Counter(), {}
heads_outside_1870 = []
for vid in sorted(inventory):
    in_era = vid in era
    raw, root = load(vid)
    docs = documents(root)
    sources = [n for d in docs for n in d.iter(TEI + "note") if n.get("type") == "source"]
    serial_sources = [n for n in sources if SERIAL.fullmatch(text(n))]
    if serial_sources:
        place = Counter()
        for d in docs:
            parent = {c: p for p in d.iter() for c in p}
            for n in d.iter(TEI + "note"):
                if n.get("type") != "source" or not SERIAL.fullmatch(text(n)):
                    continue
                p, inside = parent[n], False
                while p is not d:
                    inside = inside or p.tag == FRUS_NS + "attachment"
                    p = parent[p]
                place["in an inclosure" if inside else "at the document's head"] += 1
                if not inside and vid != "frus1870":
                    in_opener = any(SERIAL.fullmatch(text(s)) for o in d.findall(TEI + "opener")
                                    for s in o.iter(TEI + "seg"))
                    heads_outside_1870.append((vid, d.get(XML_ID), d.get("n"), text(n),
                                               line_of(raw, 'xml:id="{}"'.format(d.get(XML_ID))),
                                               in_opener))
        print("  {}: {} source notes hold only a number: {}{}".format(
            vid, len(serial_sources), dict(place), "" if in_era else "  (OUTSIDE 1861-1898)"))
    if not in_era:
        continue
    for n in sources:
        t = text(n)
        if not SERIAL.fullmatch(t):
            labels[t] += 1
    found = Counter()
    for d in docs:
        parent = {c: p for p in d.iter() for c in p}
        hits = [e for e in d.iter() if e.tag.replace(TEI, "") in CARRIERS and SERIAL.fullmatch(text(e))]
        hit_set = set(hits)
        for e in hits:
            if any(x in hit_set for x in e.iter() if x is not e):
                continue  # the innermost element carries it
            tag = e.tag.replace(TEI, "")
            if tag == "note":
                found["note[@type={}]".format(e.get("type"))] += 1
            else:
                found["{}/{}".format(parent[e].tag.replace(TEI, ""), tag)] += 1
    carriers_by_volume[vid] = found
    for k, n in found.items():
        totals[k] += n
    print("  {}: {} documents, {} source notes, {} reading only a despatch number; carriers {}".format(
        vid, len(docs), len(sources), len(serial_sources), dict(found.most_common())))
print("  the era: {} volumes; despatch numbers by carrier, all volumes: {}".format(
    len(era), dict(totals.most_common())))
print("  volumes holding any in each carrier: {}".format(dict(Counter(
    k for found in carriers_by_volume.values() for k in found).most_common())))
print("  the era's source notes that are not a number, commonest: {}".format(labels.most_common(8)))
print("  number-only source notes at a document's head, outside frus1870 ({} in {} volumes):".format(
    len(heads_outside_1870), len({v for v, *_ in heads_outside_1870})))
for vid, did, n, t, line, in_opener in heads_outside_1870:
    if vid != "frus1872p2v5":
        print("    {} {} (@n {}, line {}): {}; a number in its opener: {}".format(
            vid, did, n, line, t, in_opener))
v5 = [row for row in heads_outside_1870 if row[0] == "frus1872p2v5"]
print("    frus1872p2v5: {} documents, {} to {}; @n equal to the note's number in {}; "
      "a number in the opener too in {}".format(
          len(v5), v5[0][1], v5[-1][1], sum(1 for row in v5 if re.sub(r"\D", "", row[3]) == row[2]),
          sum(1 for row in v5 if row[5])))
print()

print("== 4. frus1870's List of Papers against its documents")
raw, root = load("frus1870")
contents = next(d for d in root.iter(TEI + "div") if d.get(XML_ID) == "contents")
papers = {}
for row in contents.iter(TEI + "row"):
    cells = [text(c) for c in row.findall(TEI + "cell")]
    if cells and cells[0].rstrip(".").isdigit():
        papers[int(cells[0].rstrip("."))] = cells
print('  "{}" at line {}: {} numbered rows, 1 to {}, none twice'.format(
    text(contents.find(TEI + "head")), line_of(raw, 'xml:id="contents"'), len(papers), max(papers)))
docs = documents(root)
print("  documents: {}, d1 to d{}".format(len(docs), docs[-1].get("n")))
shift, first_of_shift = None, []
for d in docs:
    first = next((text(n) for n in d.findall(TEI + "note") if n.get("type") == "source"), None)
    m = SERIAL.fullmatch(first) if first else None
    number = int(re.sub(r"\D", "", first)) if m else None
    if number is not None and d.get("n", "").isdigit() and abs(number - int(d.get("n"))) < 5:
        if number - int(d.get("n")) != shift:
            shift = number - int(d.get("n"))
            first_of_shift.append((d.get(XML_ID), first, shift))
print("  the paper number a document's first source note prints, against @n (from, note, shift):",
      first_of_shift)


def printed_number(n):
    """The List of Papers number of the document with this @n, given the three papers the file
    encodes inside the paper before them (Nos. 216, 284 and 303)."""
    return n + (0 if n <= 215 else 1 if n <= 282 else 2)


agree, others, both, example = 0, [], 0, None
for d in docs:
    numbers = [text(x) for x in d.findall(TEI + "note")
               if x.get("type") == "source" and SERIAL.fullmatch(text(x))]
    if not numbers:
        continue
    expected = printed_number(int(d.get("n")))
    if int(re.sub(r"\D", "", numbers[0])) == expected:
        agree += 1
    else:
        others.append((d.get(XML_ID), numbers[0], expected))
    despatch = [text(s) for o in d.findall(TEI + "opener") for s in o.iter(TEI + "seg")
                if SERIAL.fullmatch(text(s))]
    if despatch:
        both += 1
        example = example or (d.get(XML_ID), numbers[0], despatch[0])
print("  documents opening with a number-only source note: {}; it is the List of Papers number in {} "
      "(@n to d215, @n + 1 to d282, @n + 2 after); the others (document, note, paper): {}".format(
          agree + len(others), agree, others))
print("  of those, {} also print a despatch number in the opener; the first: {}".format(both, example))
print("  documents after d215, which a paper of its own for No. 216 renumbers: {}".format(
    sum(1 for d in docs if int(d.get("n")) > 215)))
# The List of Papers' date ("Feb. 19") against the document's own (its frus:doc-dateTime-min, whose
# first ten characters are the day at -05:00), for every document whose number note the shift explains.
MONTHS = {"Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "June": 6, "Jun": 6, "July": 7, "Jul": 7,
          "Aug": 8, "Sept": 9, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12}
dates_agree, dates_differ, undated = 0, [], 0
for d in docs:
    numbers = [text(x) for x in d.findall(TEI + "note")
               if x.get("type") == "source" and SERIAL.fullmatch(text(x))]
    if not numbers or int(re.sub(r"\D", "", numbers[0])) != printed_number(int(d.get("n"))):
        continue
    cells = papers[printed_number(int(d.get("n")))]
    listed = re.match(r"([A-Z][a-z]+)\.? (\d{1,2})\b", cells[2]) if len(cells) > 2 else None
    when = (d.get(FRUS_NS + "doc-dateTime-min") or "")[:10]
    if not listed or listed.group(1) not in MONTHS or len(when) < 10:
        undated += 1
        continue
    if (MONTHS[listed.group(1)], int(listed.group(2))) == (int(when[5:7]), int(when[8:10])):
        dates_agree += 1
    else:
        dates_differ.append((d.get(XML_ID), cells[2], when))
print("  of those {} the shift explains, the List of Papers' date is the document's own in {}; "
      "differs in {} {}; no date to compare in {}".format(
          dates_agree + len(dates_differ) + undated, dates_agree, len(dates_differ), dates_differ, undated))
# Every <date when> in a document whose own text prints a whole date ("July 18, 1870") that
# contradicts it. The rule is this note's, for frus1870 alone; #469's date rows hold none here.
NAMES = {name: i + 1 for i, name in enumerate(
    "January February March April May June July August September October November December".split())}
contradictions = []
for d in docs:
    start = raw.index('xml:id="{}"'.format(d.get(XML_ID)))
    for x in d.iter(TEI + "date"):
        when = (x.get("when") or "")[:10]
        printed = re.search(r"\b({}) (\d{{1,2}}), (\d{{4}})".format("|".join(NAMES)), text(x))
        if not printed or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", when):
            continue
        p = (int(printed.group(3)), NAMES[printed.group(1)], int(printed.group(2)))
        if p != (int(when[:4]), int(when[5:7]), int(when[8:10])):
            # A dateline that goes on "(Received August 3 …)": is @when that month with the printed day?
            dateline = next((dl for dl in d.iter(TEI + "dateline") if x in list(dl.iter(TEI + "date"))), None)
            received = re.search(r"Received ({})".format("|".join(NAMES)), text(dateline)) if dateline is not None else None
            from_receipt = bool(received) and (int(when[5:7]), int(when[8:10])) == (NAMES[received.group(1)], p[2])
            contradictions.append((d.get(XML_ID), line_of(raw, re.escape('when="{}"'.format(when)), start),
                                   text(x), when, from_receipt))
print("  <date> elements whose printed date contradicts @when: {}; of them, @when is the printed day in the "
      "month of the dateline's \"Received\" in {}".format(len(contradictions), sum(1 for r in contradictions if r[4])))
for row in contradictions:
    print("    {} line {}: \"{}\" encoded {}; the month of receipt: {}".format(*row))
print("  documents with no number-only source note: {}".format(
    [d.get(XML_ID) for d in docs if not any(x.get("type") == "source" and SERIAL.fullmatch(text(x))
                                            for x in d.findall(TEI + "note"))]))
for number, carrier, pattern in ((216, "d215", r"Baron Gerolt</persName> to"),
                                 (284, "d282", r"Mr\. Be Long</persName>"),
                                 (303, "d300", r"<head>")):
    start = raw.index('xml:id="{}"'.format(carrier))
    if number == 303:  # d300's own head names Mr. Schuyler too: start at its inclosure
        start = raw.index("<frus:attachment>", start)
    row_line = line_of(raw, r"<cell>{}\.?</cell>".format(number))
    print("  No. {} (List of Papers line {}): {}".format(
        number, row_line, " | ".join(papers[number][1:])))
    head_line = line_of(raw, pattern, start)
    writer = {216: "Baron Gerolt", 284: "Mr. Be Long", 303: "Mr. Schuyler"}[number]
    carrier_doc = next(d for d in docs if d.get(XML_ID) == carrier)
    attachment = next(a for a in carrier_doc.iter(FRUS_NS + "attachment")
                      if a.find(TEI + "head") is not None
                      and text(a.find(TEI + "head")).startswith(writer))
    opener = attachment.find(TEI + "opener")
    carrier_opener = carrier_doc.find(TEI + "opener")
    print('    inside {} (line {}), which the List of Papers gives as No. {}: {}; its opener: "{}"'.format(
        carrier, line_of(raw, 'xml:id="{}"'.format(carrier)), number - 1,
        " | ".join(x for i, x in enumerate(papers[number - 1][1:]) if i != 2),
        text(carrier_opener)[:90] if carrier_opener is not None else ""))
    print('    its head at line {}: "{}"; its opener: "{}"'.format(
        head_line, text(attachment.find(TEI + "head")), text(opener)[:90] if opener is not None else ""))
for did, number in (("d131", 131), ("d230", 231)):
    d = next(x for x in docs if x.get(XML_ID) == did)
    note = next(n for n in d.findall(TEI + "note") if n.get("type") == "source")
    opener = d.find(TEI + "opener")
    printed = re.search(r"\bNo\.? ?{}\b".format(number), text(d)) is not None
    print('  {} (line {}): source note "{}" at line {}; opener "{}"; List of Papers No. {}: {}; '
          '"No. {}" printed in the document: {}'.format(
              did, line_of(raw, 'xml:id="{}"'.format(did)), text(note),
              line_of(raw, r'type="source">(<hi rend="smallcaps">)?' + re.escape(text(note)) + "(</hi>)?</note>",
                      raw.index('xml:id="{}"'.format(did))),
              text(opener)[:60] if opener is not None else "", number, " | ".join(papers[number][1:3]),
              number, printed))
print()

print("== 5. The examples the note quotes")
for vid, pattern in (("frus1870", r'type="source">No\. 3\.</note>'),
                     ("frus1870", r'type="source">No\. 4\.</note>'),
                     ("frus1872p2v5", r'type="source">No\. 7\.</note>'),
                     ("frus1872p2v5", r'type="source">\*No\. 9\.'),
                     ("frus1871", r'<seg rendition="#left">No\. 74\.\]</seg>')):
    raw, _ = load(vid)
    n = line_of(raw, pattern)
    if n is None:
        print("  {}: NOT FOUND ({})".format(vid, pattern))
        continue
    lines = raw.split("\n")
    print("  {} line {} ({}):".format(vid, n, pattern))
    for k in range(n - 1, min(n + 3, len(lines))):
        print("    {}: {}".format(k + 1, lines[k].strip()))
raw, root = load("frus1870")
docs = documents(root)
sources = [(d.get(XML_ID), text(n)) for d in docs for n in d.iter(TEI + "note") if n.get("type") == "source"]
print("  frus1870: {} documents, {} with a source note, {} source notes; not a despatch number: {}".format(
    len(docs), len({d for d, _ in sources}), len(sources),
    [(d, t) for d, t in sources if not SERIAL.fullmatch(t)]))
