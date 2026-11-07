#!/usr/bin/env python3
# Items 1 and 5 of Planning/OH-Note-2026-11-06.md, the draft note to the Office of the Historian, swept over
# the 553 volumes FRUS Explorer lists (2026-11-06). The note found both in frus1870 alone, by check.py's
# section 4; this run looks for them in every volume, and reproduces frus1870's as its control.
# argv: <frus checkout> <inventory.json> <volume-annotations-index.json> <dates.csv> <out dir> [--context]
#   <frus checkout>  a clone of HistoryAtState/frus; the run prints its commit, which every line number is
#                    relative to.
#   inventory.json   Planning/editors-annotations/inventory.json: its keys are the 553 volumes.
#   volume-annotations-index.json   FRUSExplorer/Resources/: each volume's era band.
#   dates.csv        Planning/OH-Report-2026-10-01/dates.csv, #469's date rows: says which rows are new.
#   <out dir>        receives papers-filed-inside.csv and receipt-month-dates.csv.
#   --context        prints, instead of the report, what each reading below was made from.
# Run through Scripts/heavy.sh with python3 -I: it parses the TEI of all 553 volumes (about a minute on the
# M5 MacBook). Read-only; stdlib only. Lines come from expat: a division's is the line of its xml:id, a
# date's the line of its @when, a row's the line of its first cell, anything else its start tag's.
#
# ITEM 1: a paper the List of Papers prints that the file holds only inside an earlier paper.
#  1. A List of Papers is a division outside the documents whose head reads "List of papers", "Papers
#     relating to foreign affairs", "Contents" or "Table of contents" (not "Index"), whose own tables hold
#     five or more rows that end in a page number. It is encoded in several ways; the run counts them.
#  2. Each such row is a paper. Its date is the cell under the table's "Date" header, or else the first cell
#     that reads like "Feb. 19"; "do" repeats the date above. A row with no number, writer or date continues
#     the row above. A row whose cell opens "[Enclosure]" or "Inclosure" names an enclosure, not a paper.
#  3. A document begins on the page of its head (the last pb before it). Each row is matched to a document
#     that begins on its page and gives its day (printed, in @when, or in frus:doc-dateTime-min): first a
#     numbered row to the one whose opener prints its number ("No. 7.]"), then a row to the one whose head
#     shares the most names with its writer cell, then any row to the first; then a row to a document on its
#     page where either side gives no day; then to one on the page before or after with its day.
#  4. A row left unmatched whose day is that of a frus:attachment beginning on its page (else on the page
#     before or after) is a candidate when the attachment is dated after the document it sits in: the date
#     its own opener prints (the year from @when where the text gives none), else its @when; the document's
#     likewise, else doc-dateTime-min. An inclosure cannot be later than the paper that encloses it. Of
#     several such attachments the row takes the one whose head best names its writer, and none that an
#     earlier row took. An attachment's date inferred from outside the paper (@ana) is set aside. A row that
#     meets an attachment of the same day or earlier names an inclosure, which the lists of the 1860s, of
#     1898 and of 1914–1918 often do: counted, not reported.
#  5. A row whose page lies outside the file is matched in a volume of the same year with no list of its own.
#
# ITEM 5: a date whose month is the receipt's.
#  1. Every <date when> in a document whose own text writes out a month and a day (margin notes and footnotes
#     set aside). A day the editors correct in brackets, "August 10 [11]", is read both ways: @when follows
#     either, so neither reading contradicts it.
#  2. Where the printed date contradicts @when, the receipt is read from the dateline the date stands in, or
#     else from its opener: "(Received August 3, 1870.)", "[Received July 24]", "Rec'd …".
#  3. The class: @when is the printed day in the month of the receipt. Two siblings are counted with it:
#     @when is the receipt's own date, and @when is the printed month and day in the receipt's year.
#  4. The List of Papers row of the paper, where the list names it, says which of the two dates the volume
#     prints for it: when its date is the printed one, the file settles the row.
#
# READINGS below hold the verdict on each candidate after reading it in the file. The run stops when a
# candidate has no reading or a reading has no candidate, so the readings and the rule cannot drift apart.
import bisect, collections, csv, json, os, re, subprocess, sys, xml.parsers.expat
import xml.etree.ElementTree as ET

FRUS, INVENTORY, ANNOTATIONS, OCTOBER_DATES, OUT = sys.argv[1:6]
CONTEXT = "--context" in sys.argv[6:]
VOL = FRUS + "/volumes"
TEI = "{http://www.tei-c.org/ns/1.0}"
XML_ID = "{http://www.w3.org/XML/1998/namespace}id"
FRUS_NS = "{http://history.state.gov/frus/ns/1.0}"
ATTACHMENT = FRUS_NS + "attachment"
ERA = "1861-1898"


# ---------------------------------------------------------------------------------------------- reading files

class Volume:
    """One TEI file, parsed by expat so that every element keeps the byte offset of its start tag."""

    def __init__(self, vid):
        self.vid = vid
        with open("{}/{}.xml".format(VOL, vid), "rb") as f:
            self.raw = f.read()
        self.newlines = [m.start() for m in re.finditer(b"\n", self.raw)]
        builder, self.at = ET.TreeBuilder(), {}
        parser = xml.parsers.expat.ParserCreate(namespace_separator="}")
        parser.buffer_text = True

        def name(n):
            return "{" + n if "}" in n else n

        def start(tag, attrs):
            e = builder.start(name(tag), {name(k): v for k, v in attrs.items()})
            self.at[e] = parser.CurrentByteIndex

        parser.StartElementHandler = start
        parser.EndElementHandler = lambda tag: builder.end(name(tag))
        parser.CharacterDataHandler = builder.data
        parser.Parse(self.raw, True)
        self.root = builder.close()
        self.parent = {c: e for e in self.root.iter() for c in e}
        self.documents = [d for d in self.root.iter(TEI + "div") if d.get("type") == "document"]

    def line_of(self, e, attr=None):
        offset = self.at[e]
        if attr:
            m = re.compile(re.escape(attr.encode()) + b'="').search(self.raw, offset)
            offset = m.start() if m else offset
        return bisect.bisect_left(self.newlines, offset) + 1

    def ancestors(self, e, stop=None):
        out, p = [], self.parent.get(e)
        while p is not None and p is not stop:
            out.append(p)
            p = self.parent.get(p)
        return out


def raw_text(e):
    """The element's text without margin notes and nested notes (a footnote is not the line)."""
    parts = [e.text or ""]
    for c in e:
        if not (c.tag == TEI + "note" or (c.tag == TEI + "seg" and c.get("type") == "margin")):
            parts.append(raw_text(c))
        parts.append(c.tail or "")
    return "".join(parts)


def text(e):
    return " ".join(raw_text(e).split()) if e is not None else ""


def own(container, tag):
    """The container's own descendants with this tag, in document order: none inside a nested attachment,
    a note or a division."""
    out, stack = [], list(reversed(list(container)))
    while stack:
        c = stack.pop()
        if c.tag in (ATTACHMENT, TEI + "note", TEI + "div"):
            continue
        if c.tag == tag:
            out.append(c)
        stack.extend(reversed(list(c)))
    return out


# ---------------------------------------------------------------------------------------------- dates

MONTH = (r"(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|June?|July?|Aug(?:ust)?|"
         r"Sept?(?:ember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)")
MONTH_DAY = re.compile(r"\b" + MONTH + r"\.?\s*(\d{1,2})(?:st|nd|rd|th|d)?\b(?:\s*\[(\d{1,2})\])?"
                       r"(?:,?\s*(1[789]\d\d|20\d\d))?")
DAY_MONTH = re.compile(r"\b(\d{1,2})(?:st|nd|rd|th|d)?\s+(?:of\s+)?" + MONTH + r"\.?,?\s*(1[789]\d\d|20\d\d)?\b")
YEAR = re.compile(r"\b(1[789]\d\d|20\d\d)\b")
MONTHS = {m: i + 1 for i, m in enumerate("jan feb mar apr may jun jul aug sep oct nov dec".split())}


def month_number(token):
    return MONTHS.get(token.lower()[:3])


def printed_dates(s):
    """The first date written out in s as (year or None, month, day), with a second reading where the editors
    correct the day in brackets ("August 10 [11]"): a list of one or two, or [] when s writes out none."""
    found = []
    m = MONTH_DAY.search(s)
    if m:
        year, month = int(m.group(4)) if m.group(4) else None, month_number(m.group(1))
        readings = [(year, month, int(m.group(2)))] + ([(year, month, int(m.group(3)))] if m.group(3) else [])
        found.append((m.start(), readings))
    m = DAY_MONTH.search(s)
    if m:
        found.append((m.start(), [(int(m.group(3)) if m.group(3) else None, month_number(m.group(2)), int(m.group(1)))]))
    found = [f for f in found if all(1 <= r[2] <= 31 for r in f[1])]
    return min(found)[1] if found else []


def printed_date(s):
    """(year or None, month, day) of the first date written out in s, as printed, or None."""
    readings = printed_dates(s)
    return readings[0] if readings else None


def iso(s):
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})", s or "")
    return (int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else None


def own_dates(container):
    """The <date> elements of the container's own openers and datelines, else of its own closers. An
    attachment's date inferred from anything but the paper itself (@ana "…inferred-from-sibling-dates", "…and-
    sibling-dates", "…chapter-heading" and the like) is not its own: a blank form, "_ _ _", inferred from its
    covering note's receipt would otherwise look later than the note."""
    seen, out = set(), []
    for holder in own(container, TEI + "opener") + own(container, TEI + "dateline"):
        for x in holder.iter(TEI + "date"):
            if id(x) not in seen:
                seen.add(id(x))
                out.append(x)
    if not out:
        out = [x for c in own(container, TEI + "closer") for x in c.iter(TEI + "date")]
    if container.tag == ATTACHMENT:
        out = [x for x in out if "inferred" not in (x.get("ana") or "")
               or re.search(r"inferred-from-document-(content|head)$", x.get("ana"))]
    return out


def days(container, document=False):
    """Every (month, day) the container's own dates give, printed or encoded."""
    found = set()
    for x in own_dates(container):
        for attr in ("when", "from", "notBefore"):
            d = iso(x.get(attr))
            if d:
                found.add(d[1:])
        for p in printed_dates(text(x)):
            found.add(p[1:])
    if document:
        for attr in ("doc-dateTime-min", "doc-dateTime-max"):
            d = iso(container.get(FRUS_NS + attr))
            if d:
                found.add(d[1:])
    return found


def own_date(container, document=False):
    """The container's own date, (year, month, day): printed first, the year from @when where the text
    gives none; else @when; else, for a document, frus:doc-dateTime-min."""
    for x in own_dates(container):
        p = printed_date(text(x))
        w = iso(x.get("when")) or iso(x.get("from")) or iso(x.get("notBefore"))
        if p and (p[0] or w):
            return (p[0] or w[0], p[1], p[2])
        if w:
            return w
    if document:
        return iso(container.get(FRUS_NS + "doc-dateTime-min"))
    return None


def show(d):
    return "{:04d}-{:02d}-{:02d}".format(*d) if d else "none"


# ---------------------------------------------------------------------------------------------- pages

def page_index(v):
    """The page each element is on: the last pb before it in document order (an id's bracketed true page,
    "254 [524]", stands for the misprinted folio)."""
    page, pages = None, {}
    for e in v.root.iter():
        if e.tag == TEI + "pb":
            n = e.get("n") or ""
            m = re.fullmatch(r"\d+", n) or re.search(r"\[(\d+)\]", n)
            if m:
                page = int(m.group(m.lastindex or 0))
        pages[e] = page
    return pages


def start_page(container, pages):
    head = container.find(TEI + "head")
    if head is not None:
        return pages[head]
    for c in container.iter():
        if c is not container and c.tag != TEI + "pb":
            return pages[c]
    return pages[container]


# ---------------------------------------------------------------------------------------------- lists of papers

LIST_HEAD = re.compile(r"(?i)\b(list of (the )?papers|papers relating to foreign affairs|table of contents|contents)\b")
PAGE_CELL = re.compile(r"(\d{1,4})\.?")
DATE_HEADER = re.compile(r"(?i)date\.?|date and number\.?")
DITTO = re.compile(r"(?i)^[.\s]*(do|ditto)\b[.\s]*$|^same date\.?$|^same day\.?$")
ENCLOSURE = re.compile(r"(?i)^\[?\s*(in|en)closures?\b")
NOT_A_NAME = set("Mr Mrs Baron Count Sir General Lord Same The Secretary State Minister Ambassador Telegram "
                 "Circular Extract Inclosure From To United States Legation Department Prince Marquis Señor "
                 "Senor Don Dr Admiral Captain Consul Chargé President Acting Memorandum Translation Esq "
                 "Hon Excellency Emperor King Queen Duke Earl".split())


def own_tables(division):
    out, stack = [], list(reversed(list(division)))
    while stack:
        c = stack.pop()
        if c.tag == TEI + "div":
            continue
        if c.tag == TEI + "table":
            out.append(c)
            continue
        stack.extend(reversed(list(c)))
    return out


def list_divisions(v):
    out = []
    for d in v.root.iter(TEI + "div"):
        if d.get("type") == "document":
            continue
        head = d.find(TEI + "head")
        if head is None or not LIST_HEAD.search(text(head)) or re.match(r"(?i)\s*(alphabetical )?index", text(head)):
            continue
        paged = [r for t in own_tables(d) for r in t.iter(TEI + "row")
                 if r.findall(TEI + "cell") and PAGE_CELL.fullmatch(text(r.findall(TEI + "cell")[-1]))]
        if len(paged) >= 5:
            out.append(d)
    return out


Row = collections.namedtuple("Row", "number writer date_text day year subject page line enclosure continuation cells")


def list_rows(v, division):
    rows, year, last_day, last_writer = [], None, None, ""
    for table in own_tables(division):
        date_col = None
        for r in table.iter(TEI + "row"):
            cells = r.findall(TEI + "cell")
            texts = [text(c) for c in cells]
            if not texts:
                continue
            if any(DATE_HEADER.fullmatch(t) for t in texts):
                date_col = next(i for i, t in enumerate(texts) if DATE_HEADER.fullmatch(t))
                continue
            page, body = PAGE_CELL.fullmatch(texts[-1]), texts[:-1]
            if not page:
                for t in body:
                    y = YEAR.fullmatch(t.rstrip(".")) if t else None
                    year = int(y.group(1)) if y else year
                continue
            if date_col is not None and date_col < len(body):
                date_text = body[date_col]
            else:
                date_text = next((t for t in body if MONTH_DAY.search(t) or DITTO.match(t)), "")
            y = YEAR.search(date_text)
            year = int(y.group(1)) if y else year
            m = MONTH_DAY.search(date_text)
            day = (month_number(m.group(1)), int(m.group(2))) if m else (last_day if DITTO.match(date_text) else None)
            number = texts[0] if len(texts) > 2 and re.fullmatch(r"\d{1,5}[a-z]?\.?", texts[0]) else ""
            writer_col = 1 if len(texts) == 5 and date_col in (2, None) else (2 if date_col == 1 else None)
            writer = texts[writer_col] if writer_col is not None and writer_col < len(texts) - 1 else ""
            if DITTO.match(writer) or re.match(r"(?i)^same to same", writer):
                writer = last_writer
            elif re.match(r"(?i)^same to ", writer) and " to " in last_writer:
                writer = last_writer.split(" to ")[0] + writer[4:]
            rows.append(Row(number, writer, date_text, day, year, texts[-2] if len(texts) >= 2 else "",
                            int(page.group(1)), v.line_of(cells[0]), any(ENCLOSURE.match(t) for t in body),
                            not number and not writer and not date_text and len(texts) >= 4, texts))
            last_day = day or last_day
            last_writer = writer or last_writer
    return rows


def surnames(s):
    return {w for w in re.findall(r"\b([A-Z][a-zé]+(?:-[A-Z][a-z]+)?)\b", s) if w not in NOT_A_NAME}


def file_pages(pages):
    numbered = [p for p in pages.values() if p is not None]
    return (min(numbered), max(numbered)) if numbered else (None, None)


class Holdings:
    """A file's documents and attachments, keyed by the page each begins on."""

    def __init__(self, v):
        self.v, self.pages = v, page_index(v)
        self.span = file_pages(self.pages)
        self.docs = [{"doc": d, "page": start_page(d, self.pages), "days": days(d, document=True),
                      "serials": {int(m) for o in own(d, TEI + "opener") + own(d, TEI + "seg")
                                  for m in re.findall(r"\bNo\.? ?(\d+)", text(o))},
                      "names": surnames(text(d.find(TEI + "head")))}
                     for d in v.documents]
        self.by_page = collections.defaultdict(list)
        for x in self.docs:
            self.by_page[x["page"]].append(x)
        self.att_by_page = collections.defaultdict(list)
        for x in self.docs:
            for a in x["doc"].iter(ATTACHMENT):
                self.att_by_page[start_page(a, self.pages)].append({"att": a, "host": x["doc"], "days": days(a)})

    def covers(self, page):
        return self.span[0] is not None and self.span[0] <= page <= self.span[1]


def match_rows(rows, h):
    """Rows (all on pages h covers) matched to h's documents, and the candidates among the rest."""
    used, match = set(), {}

    def take(i, x, how):
        used.add(id(x))
        match[i] = (x, how)

    # A numbered row first claims the document of its page and day whose opener prints its number ("No. 7.]").
    for i, r in enumerate(rows):
        number = int(re.sub(r"\D", "", r.number)) if r.number else None
        x = number is not None and r.day and next((x for x in h.by_page.get(r.page, []) if id(x) not in used
                                                   and r.day in x["days"] and number in x["serials"]), None)
        if x:
            take(i, x, "page and day")
    # Then a row claims the document of its page and day whose head shares the most names with its writer cell,
    # before a row of the same page and day that names someone else, or no one ("Memorandum"), can take it. Both
    # parties count: a head of 1914 names the Secretary of State by title and the consul by name.
    for i, r in enumerate(rows):
        names = surnames(r.writer)
        if i in match or not r.day or not names:
            continue
        shared = [(len(names & x["names"]), -k, x) for k, x in enumerate(h.by_page.get(r.page, []))
                  if id(x) not in used and r.day in x["days"] and names & x["names"]]
        if shared:
            take(i, max(shared, key=lambda s: s[:2])[2], "page and day")
    for i, r in enumerate(rows):
        if i in match:
            continue
        x = r.day and next((x for x in h.by_page.get(r.page, []) if id(x) not in used and r.day in x["days"]), None)
        if x:
            take(i, x, "page and day")
    for i, r in enumerate(rows):
        if i not in match:
            x = next((x for x in h.by_page.get(r.page, []) if id(x) not in used and (r.day is None or not x["days"])), None)
            if x:
                take(i, x, "page")
    for i, r in enumerate(rows):
        if i not in match and r.day:
            x = next((x for p in (r.page - 1, r.page + 1) for x in h.by_page.get(p, [])
                      if id(x) not in used and r.day in x["days"]), None)
            if x:
                take(i, x, "next page and day")
    numbers = [int(re.sub(r"\D", "", r.number)) for r in rows if r.number]
    sequential = len(numbers) > 20 and sum(1 for a, b in zip(numbers, numbers[1:]) if b == a + 1) >= 0.9 * (len(numbers) - 1)
    candidates, inclosures, same_day_numbered, claimed = [], [], [], set()

    def score(r, a):
        """How well an attachment's head names the row's writer: its first name counts double."""
        names, head = surnames(r.writer), surnames(text(a["att"].find(TEI + "head")))
        first = surnames(r.writer.split(" to ")[0])
        return 2 * len(first & head) + len(names & head)

    for i, r in enumerate(rows):
        if i in match or r.day is None or r.enclosure:
            continue
        hits = [a for a in h.att_by_page.get(r.page, []) if r.day in a["days"] and id(a["att"]) not in claimed]
        if not hits:
            hits = [a for p in (r.page - 1, r.page + 1) for a in h.att_by_page.get(p, [])
                    if r.day in a["days"] and id(a["att"]) not in claimed]
        if not hits:
            continue
        hits.sort(key=lambda a: -score(r, a))
        a = hits[0]
        claimed.add(id(a["att"]))
        host_date, att_date = own_date(a["host"], document=True), own_date(a["att"])
        before = next((match[j][0]["doc"] for j in range(i - 1, -1, -1) if j in match), None)
        record = {"i": i, "row": r, "att": a["att"], "host": a["host"], "host_date": host_date,
                  "att_date": att_date, "hits": len(hits), "paper_before": before,
                  "numbered": sequential and bool(r.number)}
        if host_date and att_date and att_date > host_date:
            candidates.append(record)
        elif record["numbered"]:
            same_day_numbered.append(record)
        else:
            inclosures.append(record)
    attached = {c["i"] for c in candidates + inclosures + same_day_numbered}
    for i, r in enumerate(rows):
        if i not in match and i not in attached:
            x = next((x for x in h.by_page.get(r.page, []) if id(x) not in used), None)
            if x:
                take(i, x, "page; the days differ")
    return {"match": match, "candidates": candidates, "inclosures": inclosures, "sequential": sequential,
            "same_day_numbered": same_day_numbered,
            "unmatched": [i for i in range(len(rows)) if i not in match and i not in attached],
            "docs_without_row": len(h.docs) - len(used)}


# ---------------------------------------------------------------------------------------------- receipts

RECEIVED = re.compile(r"\bRec(?:eive|['’])?d\.?(?:\s+(?:at|in|by)\s+[^,;:\]\)]{1,40}?)?,?\s*" + MONTH +
                      r"\.?\s*(\d{1,2})(?:st|nd|rd|th|d)?\b(?:,?\s*(1[789]\d\d|20\d\d))?")


def receipt_rows(v):
    out = []
    for d in v.documents:
        for x in d.iter(TEI + "date"):
            when, readings = iso(x.get("when")), printed_dates(text(x))
            if not when or not readings or any((p[0] or when[0], p[1], p[2]) == when for p in readings):
                continue
            p = readings[0]
            up = v.ancestors(x, d)
            holders = [a for a in up if a.tag == TEI + "dateline"][:1] + [a for a in up if a.tag == TEI + "opener"][:1]
            received, receipt_text = None, ""
            for holder in holders:
                m = RECEIVED.search(text(holder))
                if m:
                    received = (int(m.group(3)) if m.group(3) else None, month_number(m.group(1)), int(m.group(2)))
                    receipt_text = m.group(0)
                    break
            kind = "other"
            if received:
                year = p[0] or when[0]
                if when[1:] == (received[1], p[2]) and received[1] != p[1]:
                    kind = "receipt month"
                elif when[1:] == received[1:] and when[1:] != p[1:]:
                    kind = "receipt date"
                elif received[0] and when == (received[0], p[1], p[2]) and received[0] != year:
                    kind = "receipt year"
            container = next((a for a in up if a.tag == ATTACHMENT), d)
            out.append({"doc": d, "date": x, "container": container, "when": x.get("when"), "printed": text(x),
                        "p": p, "received": received, "receipt_text": receipt_text, "kind": kind,
                        "line": v.line_of(x, "when"), "dateline": text(holders[0]) if holders else ""})
    return out


# ---------------------------------------------------------------------------------------------- readings
# Item 1: (volume, line of the attachment's head, or of the attachment where it has none) -> (mark, note).
# Item 5: (volume, line of the @when) -> (mark, note). Filled in after reading each candidate in the file.
READINGS_1 = {
    ('frus1862', 32322): ('confirmed', "A memorandum of conversation of May 30, 1862 (complaints from New Orleans) inside Mr. Seward's note to Lord Lyons of April 5."),
    ('frus1862', 43597): ('confirmed', "Mr. Thouvenel's despatch of March 20, 1862, in extract, inside his despatch of March 13 to Mr. Mercier."),
    ('frus1862', 44015): ('confirmed', "Count Mejan's letter of May 30, 1862, from New Orleans, nested inside Mr. Chase's two letters of May 26, which are inside Mr. Seward's note of May 26 to Mr. Mercier."),
    ('frus1862', 45896): ('confirmed', "Mr. Cameron's despatch No. 2 of June 26, 1862, from St. Petersburg, inside Mr. Seward's instruction No. 30 of February 4 to Mr. Clay."),
    ('frus1863p1', 16845): ('confirmed', "Mr. Moran's letter of January 9, 1863, from the legation in London, inside Mr. Adams's despatch No. 293 of January 8."),
    ('frus1863p1', 17378): ('confirmed', "Mr. Moran's letter of January 17, 1863 inside Mr. Adams's despatch No. 299 of January 16."),
    ('frus1863p1', 58927): ('confirmed', "Mr. Seward's reply of May 19, 1863 inside the note of May 18 from Lord Lyons that it answers."),
    ('frus1863p2', 25314): ('confirmed', "Mr. Seward's circular of June 16, 1863 to the ministers in Europe inside Mr. Pike's despatch of June 10."),
    ('frus1864p1', 22640): ('confirmed', "Mr. Moran's letter of February 20, 1864 inside Mr. Adams's despatch No. 602 of February 19."),
    ('frus1864p3', 51747): ('confirmed', "Mr. Pruyn's telegram of August 26, 1864 (the vendor's head '[Untitled]') inside his despatch No. 54 of August 13; a second telegram follows it, dated August 2, and the list's row for October 14 on the same page matches nothing."),
    ('frus1865p2', 33906): ('confirmed', "Mr. Bigelow's despatch of April 17, 1865, with its two enclosures, inside Mr. Seward's instruction No. 108 of April 8."),
    ('frus1865p2', 42824): ('confirmed', "Mr. Drouyn de Lhuys's despatch No. 1 of January 5, 1865, from Paris, communicated by the French legation, inside Mr. de Geofroy's note of January 3; the list calls it a memorandum on the Japanese indemnity."),
    ('frus1865p2', 55938): ('confirmed', "Mr. Perry's letter of February 19, 1865 (the vendor's head '[Untitled]') after the labelled enclosures A and B of his despatch No. 167 of February 15."),
    ('frus1865p3', 50304): ('confirmed', "The French legation's memorandum received February 4, 1865 inside Mr. Seward's memorandum of January 21 to Mr. de Geofroy."),
    ('frus1865p3', 55071): ('confirmed', "Mr. Bigelow's despatch of January 16, 1866, with three enclosures, inside Mr. Seward's instruction No. 329 of December 14, 1865."),
    ('frus1866p1', 14257): ('confirmed', "Mr. Hunter's memorandum of December 31, 1865 to Mr. Adams inside his instruction No. 1644 of December 30."),
    ('frus1866p1', 23336): ('confirmed', "Mr. Seward's circular of June 18, 1866 (honors to Lewis Cass) inside his instruction No. 1789 of June 16 to Mr. Adams."),
    ('frus1866p1', 31369): ('confirmed', "Mr. Hunter's instruction No. 1868 of October 30, 1866 to Mr. Adams inside Mr. Moran's despatch No. 17 of October 27."),
    ('frus1866p1', 32166): ('confirmed', "Lord Clarendon's despatch of January 19, 1866, communicated by Sir F. Bruce on February 8, inside Sir F. Bruce's note of January 5."),
    ('frus1866p1', 47154): ('confirmed', "Mr. de Moustier's despatch of October 16, 1866 from Paris, communicated by the French legation, inside the Marquis de Montholon's note of October 15."),
    ('frus1866p1', 49790): ('confirmed', "The Emperor Alexander's reply of August 17, 1866 to the joint resolution of Congress inside Mr. Clay's despatch No. 116 of July 14."),
    ('frus1866p1', 66225): ('confirmed', "Mr. de Castro's despatch of January 27, 1866 from Madrid inside Mr. Tassara's note of January 25 from Washington."),
    ('frus1866p2', 14894): ('confirmed', "Mr. Hunter's instruction No. 49 of October 29, 1866 inside Mr. Wright's despatch No. 56 of October 22."),
    ('frus1866p2', 69082): ('confirmed', "Mr. Pruyn's letter of March 15, 1865 to Mr. Weed and Mr. Lansing inside his despatch No. 11 of March 9."),
    ('frus1866p3', 6666): ('confirmed', "Mr. Seward's instruction No. 1 of May 25, 1866, in extract, inside Mr. Campbell's letter of May 23."),
    ('frus1866p3', 47411): ('confirmed', "General Sheridan's telegram of November 30, 1866 to General Grant, filed with the War Department's other telegrams at the end of the Mexican legation's index of documents, inside Mr. Romero's note of November 27."),
    ('frus1866p3', 47447): ('confirmed', "Mr. Stanton's telegram of November 30, 1866 to General Sheridan, at the end of the same index, inside Mr. Romero's note of November 27."),
    ('frus1866p3', 47472): ('confirmed', "General Sheridan's telegram of December 1, 1866 to General Grant, at the end of the same index, inside Mr. Romero's note of November 27."),
    ('frus1866p3', 60240): ('confirmed', "Mr. Hunter's instruction No. 154 of August 31, 1866 inside Mr. Burton's despatch No. 260 of August 26."),
    ('frus1867p1', 22408): ('confirmed', "Mr. Seward's circular of September 5, 1867 (the President's proclamation) inside Mr. Adams's despatch No. 1438 of September 3."),
    ('frus1867p1', 52191): ('confirmed', "Mr. Seward's circular of January 17, 1867 on the coolie trade inside Mr. Burlingame's despatch No. 126, whose dateline prints January 3, 1861 for 1867."),
    ('frus1867p2', 41440): ('confirmed', "Mr. Campbell's telegram of December 24, 1866 (its row reads 'Tel.') inside his despatch No. 6 of December 13; his despatch No. 7 of the same day is d222."),
    ('frus1867p2', 51665): ('confirmed', "Mr. Hunter's instruction No. 8 of July 30, 1867 inside Mr. Otterbourg's despatch of July 29."),
    ('frus1867p2', 62693): ('confirmed', "Mr. Diaz's letter of April 30, 1867 from New Orleans inside Mr. Romero's note of April 13, after its six enclosures."),
    ('frus1867p2', 62714): ('confirmed', "The Mexican legation's memorandum of May 20, 1867 inside Mr. Romero's note of April 13."),
    ('frus1867p2', 63473): ('confirmed', "A memorandum of June 8, 1867 (Mr. Campbell's route to his post) inside Mr. Romero's note of June 4."),
    ('frus1867p2', 63501): ('confirmed', "A memorandum of June 10, 1867 (Mrs. Juarez's return), from Mr. Romero's despatch No. 238, inside his note of June 4."),
    ('frus1867p2', 63787): ('confirmed', "Mrs. Juarez's letter of June 17, 1867 inside Mr. Romero's note of June 15."),
    ('frus1867p2', 67343): ('confirmed', "A memorandum of July 8, 1867 on General Santa Anna inside Mr. Romero's note of July 7."),
    ('frus1867p2', 70334): ('confirmed', "A memorandum of July 15, 1867 (the Mexican government's intentions) inside Mr. Romero's note of July 13."),
    ('frus1868p1', 40906): ('confirmed', "Mr. Johnson's cable of October 27, 1868 from London inside Mr. Seward's instruction No. 31 of October 26."),
    ('frus1868p2', 15755): ('confirmed', "Mr. Hale's despatch No. 147 of September 27, 1868, in extract, inside Mr. Seward's instruction No. 127 of September 19."),
    ('frus1868p2', 15896): ('confirmed', "Mr. Seward's cable of October 5, 1868 to Mr. Hale, three attachments deep: inside the Spanish bulletin that encloses Mr. Hale's No. 147, itself filed inside Mr. Seward's No. 127 of September 19."),
    ('frus1868p2', 16320): ('confirmed', "Mr. Seward's cable of October 13, 1868 inside Mr. Hale's despatch No. 148 of October 9."),
    ('frus1868p2', 18330): ('confirmed', "Mr. Bancroft's despatch No. 52 of April 21, 1868, in extract, inside his No. 51 of April 3."),
    ('frus1868p2', 37064): ('confirmed', "Mr. Webb's despatch of August 7, 1868, in extract, inside his of July 22."),
    ('frus1868p2', 37758): ('confirmed', "Mr. Webb's despatch No. 75 of October 24, 1868, in extract, inside his of October 8."),
    ('frus1868p2', 39237): ('confirmed', "Mr. Seward's instruction of March 27, 1868 inside Mr. Kilpatrick's despatch No. 104 of March 26 from Santiago."),
    ('frus1868p2', 39564): ('confirmed', "Mr. Seward's reply of April 27, 1868 inside Señor Fontecilla's note of March 30."),
    ('frus1868p2', 62855): ('confirmed', "Mr. Seward's instruction No. 2 of August 28, 1868 to Mr. Rosecrans inside Mr. Plumb's despatch No. 180 of August 24."),
    ('frus1870', 30237): ('confirmed', "No. 216, Baron Gerolt's note of February 19, 1870, inside No. 215, Mr. Fish's instruction of December 3, 1869 (the note's item 1)."),
    ('frus1870', 40555): ('confirmed', "No. 284, Mr. De Long's despatch No. 13 of January 22, 1870, inside No. 283, his No. 10 of January 17 (the note's item 1)."),
    ('frus1870', 45645): ('confirmed', "No. 303, Mr. Schuyler's despatch No. 66 of August 31, 1870, inside No. 302, his No. 54 of July 17 (the note's item 1)."),
    ('frus1871', 43416): ('confirmed', "No. 154, Mr. Bancroft's despatch No. 177 of January 7, 1871, inside d172, a circular of October 19, 1870: d168 to d172 are No. 153's five inclosures encoded as documents."),
    ('frus1872p2v5', 13065): ('confirmed', "Mr. Bancroft's despatch of March 29, 1847 from London, with its chart, inside Mr. Buchanan's instruction of December 28, 1846."),
    ('frus1879', 83708): ('not a defect', "The list's No. 386 is the document itself (its head reads 'No. 386. Mr. Gibbs to Mr. Evarts'); the row describes its inclosure, labelled 'Inclosure 1 in No. 328'."),
    ('frus1889', 19761): ('confirmed', "The Chinese minister's receipt of January 11, 1889 for the indemnity inside his note of January 7, which accepts the appointment of the 11th."),
    ('frus1889', 40141): ('confirmed', "Mr. Blaine's report of January 7, 1890 to the President on the Berlin general act inside his instructions of April 11, 1889 to the commissioners, after their labelled inclosures."),
    ('frus1889', 55479): ('confirmed', "The Japanese minister's receipt of March 28, 1889 for the indemnity inside his note of March 27."),
    ('frus1889', 60289): ('confirmed', "Mr. Whitehouse's despatch No. 148 of October 20, 1889 inside his despatch of October 9."),
    ('frus1893', 41583): ('confirmed', "Mr. Quincy's instruction No. 119 of May 1, 1893, in extract, inside the despatch No. 194 of April 12 from Mr. Durham that it answers."),
    ('frus1895p2', 35755): ('confirmed', "Admiral Stephenson's ultimatum to Nicaragua, from the Pall Mall Gazette of April 25, 1895, inside Mr. Baker's despatch No. 506 of April 24 from San José."),
    ('frus1895p2', 42824): ('confirmed', 'The memorandum Mr. Somow handed Mr. Olney on November 21, 1895 inside his note of November 18.'),
    ('frus1895p2', 46857): ('confirmed', "The memorandum on the Mora claim signed at Boston on August 10, 1895 inside Mr. Adee's telegram of July 20."),
    ('frus1895p2', 47179): ('confirmed', "The agreement of September 10, 1895 on the Mora claim inside Mr. Armstrong's telegram of September 9."),
    ('frus1895p2', 47297): ('confirmed', "The acknowledgment of September 14, 1895 that the claim was settled inside Mr. Dupuy de Lôme's note of September 13."),
    ('frus1895p2', 49737): ('confirmed', "The paper Dr. Gaytan handed Mr. Adee on October 8, 1895 inside Mr. Dupuy de Lôme's telegram of October 7."),
    ('frus1896', 34194): ('confirmed', "The President's message of January 11, 1897 transmitting the arbitration treaty, with the treaty's text, inside Mr. Olney's note No. 425 of June 22, 1896; the list runs by date, not by page."),
    ('frus1896', 35377): ('confirmed', "The heads of a Venezuela boundary treaty agreed on November 12, 1896 inside Mr. Olney's note No. 438 of July 13; this list runs by date and the volume by subject, so its row is not the one after the note's."),
    ('frus1898', 82702): ('confirmed', "Mr. Woodford's telegram of April 10, 1898 to the President inside his despatch No. 217 of April 9."),
    ('frus1898', 84425): ('confirmed', "The President's message of April 25, 1898 to Congress, with no head of its own, inside the proclamation of April 23 calling for volunteers."),
    ('frus1898', 85538): ('confirmed', "General Orders No. 101 of July 18, 1898 on the occupation of Santiago inside the Navy Department's instructions of June 20 to blockading vessels."),
    ('frus1898', 85951): ('confirmed', "The French ambassador's note of April 26, 1898 inside the note No. 12 of April 25 that it answers."),
    ('frus1898', 86000): ('confirmed', "The Austro-Hungarian minister's note of April 26, 1898 inside the Secretary of State's note No. 12 of April 25 to the French ambassador."),
    ('frus1898', 87761): ('confirmed', "The Secretary of State's note of September 1, 1898, with no head, inside Mr. Moore's note of August 30 to Mr. Cambon."),
    ('frus1898', 87989): ('confirmed', "The French embassy's memorandum of September 19, 1898 (the Spanish peace commissioners), with no head, inside Mr. Moore's note of September 10."),
    ('frus1898', 88007): ('confirmed', "The French embassy's memorandum of September 11, 1898, with no head, inside Mr. Moore's note of September 10."),
    ('frus1898', 88094): ('confirmed', "The Department's memorandum of September 16, 1898, with no head, inside Mr. Moore's note of September 10."),
    ('frus1898', 88954): ('confirmed', "Mr. Cambon's note of August 30, 1898 enclosing Spain's authority for the protocol, with no head, inside Mr. Day's note No. 94 of August 15."),
    ('frus1898', 115452): ('confirmed', "Mr. Loomis's telegram of May 5, 1898, with no head, inside his despatch No. 128 of May 2."),
    ('frus1898', 115472): ('confirmed', "Mr. Loomis's telegram of May 14, 1898, with no head, inside his despatch No. 128 of May 2."),
    ('frus1898', 115896): ('confirmed', "Mr. Loomis's telegram of July 5, 1898 (the Santiago fleet destroyed), with no head, inside Mr. Day's instruction No. 140 of June 20."),
    ('frus1898', 115941): ('confirmed', "Mr. Loomis's telegram of July 15, 1898 (the surrender of Santiago), with no head, inside Mr. Day's instruction No. 153 of July 7."),
    ('frus1898', 118466): ('confirmed', "The Department's circular of April 18, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 118509): ('confirmed', "The Department's circular of April 25, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 118541): ('confirmed', "The Department's circular of April 25 (blockade of the north coast), 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 118585): ('confirmed', "The Department's circular of April 28, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 118635): ('confirmed', "The Department's circular of May 5, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 118762): ('confirmed', "The Department's circular of May 5 (the Solace), 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 118811): ('confirmed', "The Department's circular of May 12, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 118842): ('confirmed', "The Department's circular of May 17, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 118866): ('confirmed', "The Department's circular of May 31, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 118887): ('confirmed', "The Department's circular of June 16, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 118977): ('confirmed', "The Department's circular of June 30, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 119019): ('confirmed', "The Department's circular of July 1, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 119048): ('confirmed', "The Department's circular of August 18, 1898, with no head, inside d1190a, the circular of April 15: d1190a holds 13 later circulars, each with its own row."),
    ('frus1898', 119141): ('confirmed', "The Department's circular of July 15, 1898, with no head, inside d1190b, the circular of April 21: d1190b holds 6 later circulars, each with its own row."),
    ('frus1898', 119226): ('confirmed', "The Department's circular of September 29, 1898, with no head, inside d1190b, the circular of April 21: d1190b holds 6 later circulars, each with its own row."),
    ('frus1898', 119251): ('confirmed', "The Department's circular of October 1, 1898, with no head, inside d1190b, the circular of April 21: d1190b holds 6 later circulars, each with its own row."),
    ('frus1898', 119321): ('confirmed', "The Department's circular of December 17, 1898, with no head, inside d1190b, the circular of April 21: d1190b holds 6 later circulars, each with its own row."),
    ('frus1898', 119356): ('confirmed', "The Department's circular of December 22, 1898, with no head, inside d1190b, the circular of April 21: d1190b holds 6 later circulars, each with its own row."),
    ('frus1898', 119406): ('confirmed', "The Department's circular of December 30, 1898, with no head, inside d1190b, the circular of April 21: d1190b holds 6 later circulars, each with its own row."),
    ('frus1899', 58895): ('confirmed', "Lord Salisbury's telegram of March 4, 1899 to Sir Julian Pauncefote inside Mr. Hay's note No. 1307 of January 10; the list runs by date, not by page."),
    ('frus1899', 62596): ('confirmed', "The Samoan convention's text, its ratifications exchanged February 16, 1900, inside Lord Pauncefote's note of November 27, 1899; the list runs by date, not by page."),
    ('frus1900', 24399): ('confirmed', "Mr. Conger's telegram of January 5, 1900 inside his despatch No. 304 of January 2."),
    ('frus1900', 39546): ('confirmed', "The Chinese minister's memorandum of July 21, 1900 inside his memorandum of July 20; the list runs by date, not by page."),
    ('frus1900', 45616): ('confirmed', "The Italian embassy's memorandum of October 19, 1900, communicating the Marquis Visconti Venosta's telegram, inside Mr. Adee's telegram of August 13 to Baron Fava."),
    ('frus1900', 77763): ('confirmed', "The Department's memorandum of October 13, 1900 answering the Japanese minister's memorandum of October 4, inside it."),
    ('frus1901', 38725): ('confirmed', "The Japanese legation's memorandum of November 14, 1901 inside Mr. Takahira's note No. 14 of June 13; the list runs by date, not by page."),
    ('frus1902', 84860): ('confirmed', "The protocol of December 19, 1901 between the United States and Salvador inside Señor Zaldivar's note of October 30."),
    ('frus1902', 84992): ('confirmed', "The award of May 8, 1902 in the Salvador Commercial Company's claim inside Señor Zaldivar's note of October 30, 1901."),
    ('frus1902', 86065): ('confirmed', "The arbitrators' award of May 2, 1902 inside Mr. Merry's despatch No. 698 of March 15."),
    ('frus1902', 86112): ('confirmed', "The arbitrators' opinion of April 26, 1902 in the United States v. Salvador inside Mr. Merry's despatch No. 698 of March 15."),
    ('frus1902', 90323): ('confirmed', "The Department's memorandum of March 22, 1902 to the Russian embassy inside Mr. Tower's despatch No. 541 of March 4."),
    ('frus1902', 93779): ('confirmed', "The Department's memorandum of June 10, 1902 to the Swiss legation inside the Swiss legation's note of May 29."),
    ('frus1903', 48183): ('not a defect', "Not this class: d351 is despatch No. 614 itself, whose dateline prints 'October 1903' with no day where the list gives Oct. 22; the attachment is its 'Inclosure 4'."),
    ('frus1904', 69549): ('confirmed', "The Department's circular of June 10, 1904 on conditional contraband inside Mr. McCormick's despatch No. 144 of May 25; the list runs by date, not by page."),
    ('frus1905', 59067): ('confirmed', "Extracts of the International Waterways Commission's report of December 1, 1905 inside the British ambassador's note of November 13."),
    ('frus1905', 66263): ('confirmed', "The note verbale the Japanese minister handed in on January 28, 1905 inside the Secretary of State's note of January 18 to him."),
    ('frus1906p1', 20578): ('confirmed', "The Department's circular of August 11, 1906 inside Minister Wilson's despatch No. 66 of February 25; the list runs by date, not by page."),
    ('frus1906p1', 34942): ('confirmed', "The German embassy's aide-mémoire of November 2, 1906 inside the Secretary of State's note No. 342 of October 15 to the French chargé; the list runs by date, not by page."),
    ('frus1906p1', 52842): ('confirmed', "President Roosevelt's executive order of October 23, 1906 for Cuba inside Minister Morgan's despatch No. 217 of October 13."),
    ('frus1906p1', 64167): ('confirmed', 'An executive order of March 1, 1906 amending paragraph 678 of the Consular Regulations inside the proclamation of February 27.'),
    ('frus1906p1', 64198): ('confirmed', 'A second executive order of March 1, 1906 (paragraph 680) inside the proclamation of February 27.'),
    ('frus1906p2', 66799): ('confirmed', "Mr. Root's instructions of June 18, 1906 to the delegates to the Rio conference inside the note No. 18 of May 23 to the Brazilian ambassador."),
    ('frus1906p2', 67542): ('confirmed', "The delegates' report of January 10, 1907 on the Rio conference inside the note No. 18 of May 23, 1906 to the Brazilian ambassador."),
    ('frus1906p2', 70539): ('confirmed', "The Pan-American Railway Committee's report of June 15, 1906 inside the Acting Secretary's note No. 18 of May 23 to the Brazilian ambassador."),
    ('frus1907p1', 49236): ('question', "Mr. Root's note of May 2, 1907, which the book heads 'Appendix I' and follows with Appendices II to IV of June 1, inside his note of April 22 to the German ambassador; the list gives it a row of its own."),
    ('frus1910', 65243): ('confirmed', "The Secretary of State's memorandum of December 9, 1910 on Porter Charlton's extradition, with no file number, inside the Acting Secretary's note of August 5."),
    ('frus1911', 17133): ('confirmed', "The chargé's despatch No. 249 of June 24, 1911 from Vienna inside the instruction No. 127 of May 6."),
    ('frus1911', 29776): ('confirmed', "The minister's despatch No. 8 of August 22, 1911 (the vendor's head '[Untitled]') inside his despatch of August 21."),
    ('frus1911', 38260): ('confirmed', "President Taft's message of January 25, 1910 to Congress inside the Acting Secretary's letter of February 26, 1908 to the Secretary of Commerce and Labor."),
    ('frus1911', 44751): ('question', "One head, '[Telegrams.]', prints the telegrams of February 14 and 18, 1911 to the Governor of California; the list gives the second a row of its own."),
    ('frus1911', 62854): ('confirmed', "The minister's despatch No. 41 of May 5, 1911 from Managua, in extract, inside his despatch of April 25."),
    ('frus1912', 31801): ('confirmed', "The Secretary of State's note No. 21 of February 7, 1912 inside the Argentine minister's note of January 29 that it answers."),
    ('frus1912', 37673): ('confirmed', "The ambassador's telegram of March 13, 1912 (the vendor's head '[Untitled]') inside his telegram of March 12."),
    ('frus1912', 47348): ('confirmed', "The Acting Secretary's instruction of March 30, 1912 inside the minister's despatch No. 416 of February 5 from Peking; the list runs by date, not by page."),
    ('frus1912', 61235): ('question', "One head, '[Telegrams.—Paraphrases.]', prints the minister's telegrams of March 9 and 11, 1912 from Haiti; the list gives the second a row of its own."),
    ('frus1913', 133104): ('confirmed', "The President's message of February 7, 1913 to the House on slavery in Peru inside the House resolution of August 1, 1912; the list runs by date, not by page."),
    ('frus1914', 44353): ('confirmed', "The President's message of June 16, 1914 sending the treaty to the Senate inside the Secretary of State's telegram of June 10 to Minister Thomson."),
    ('frus1914', 58187): ('confirmed', "The act of June 15, 1914 repealing the Panama Canal tolls exemption inside Ambassador Page's telegram of March 6; the list runs by date, not by page."),
    ('frus1914', 86979): ('question', "One head prints the Secretary of State's circular telegram to the consuls in Mexico with its variants ('Sent to Puerto Mexico …'); the list gives the one of April 25 a row of its own."),
    ('frus1914', 90141): ('confirmed', "The Act of Congress approved April 24, 1914, for the relief of Americans in Mexico, inside Consul Hamm's telegram of April 23; the list runs by date, not by page."),
    ('frus1914Supp', 66498): ('confirmed', "The Secretary of State's reply of August 7, 1914 inside the Insurance Company of North America's letter of August 3. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 66616): ('confirmed', "The Secretary of State's reply of August 8, 1914 inside Representative Stephens's letter of August 6. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 104842): ('confirmed', "The Secretary of State's telegram of August 12, 1914 to Ambassador Herrick inside the ambassador's telegram received August 11. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 104969): ('confirmed', "The Secretary of State's telegram No. 338 of October 6, 1914 to Ambassador Gerard inside the ambassador's telegram of September 25. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 105290): ('confirmed', "The Secretary of State's telegram No. 327 of December 3, 1914 to Ambassador Penfield inside the ambassador's telegram of November 24. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 105877): ('confirmed', "The Secretary of State's telegram of August 5, 1914 to Minister Whitlock inside the minister's telegram of August 4. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 106145): ('confirmed', "The Secretary of State's telegram of August 15, 1914 to the chargé in Russia inside the chargé's telegram of August 13. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 106204): ('confirmed', "The Secretary of State's telegram of August 19, 1914 to Ambassador Page inside the ambassador's telegram of August 18. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 106232): ('confirmed', "The Secretary of State's telegram of August 20, 1914 to Ambassador Gerard inside Ambassador Page's telegram of August 18. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 106658): ('confirmed', "The Acting Secretary's telegram No. 284 of October 9, 1914 to Ambassador Page inside the ambassador's telegram of October 8. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 106726): ('confirmed', "The Acting Secretary's telegram of November 5, 1914 to Minister Caldwell inside the minister's telegram received November 3. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 106794): ('confirmed', "The Secretary of State's telegram No. 624 of November 12, 1914 to Ambassador Gerard inside the ambassador's telegram of November 9. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 106991): ('confirmed', "The Secretary of State's telegram No. 110 of December 5, 1914 to Ambassador Morgenthau inside the ambassador's telegram of December 3. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 107068): ('confirmed', "The Secretary of State's telegram of December 16, 1914 to Ambassador Morgenthau inside the ambassador's telegram of December 13. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 107396): ('confirmed', "The Acting Secretary's telegram No. 572 of November 5, 1914 to Ambassador Gerard inside the ambassador's telegram of November 3. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 107480): ('confirmed', "The Acting Secretary's telegram No. 577 of November 20, 1914 to Ambassador Page inside the ambassador's telegram of November 16. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 107599): ('confirmed', "The Secretary of State's telegram No. 851 of December 29, 1914 to Ambassador Page inside Ambassador Gerard's telegram of December 19. The reply has no file number of its own: the shape #25 describes."),
    ('frus1914Supp', 107738): ('confirmed', "The Secretary of State's telegram of August 8, 1914 to Ambassador Morgenthau inside the ambassador's telegram of August 5. The reply has no file number of its own: the shape #25 describes."),
    ('frus1915Supp', 122755): ('confirmed', "The Department's circular of November 1, 1915 on enlistment in foreign armies runs on inside the text of the British ambassador's Enclosure 2 (its title at line 122783), in his note No. 400 of October 31. #25 named this volume among those it corrected."),
    ('frus1915Supp', 135241): ('confirmed', "The departmental order of June 1, 1915 on passports for declarants, with no head, inside the Secretary of State's telegram of April 9 to Ambassador Gerard; neither has a file number. #25 named this volume among those it corrected."),
    ('frus1915Supp', 149705): ('not a defect', "Not this class: d1516 is the British ambassador's note of December 24 itself, whose dateline prints 'December 1915' with no day; the attachment is its '[Enclosure]'."),
    ('frus1916', 26171): ('question', "The Chinese minister's note of May 19, 1916 inside the Secretary of State's note of May 11: an exchange of notes printed under one source note, Treaty Series No. 619–A; the list gives the reply a row of its own."),
    ('frus1916', 46137): ('confirmed', "The President's message of April 12, 1916 to the Senate inside the Secretary of War's letter of May 18, 1914; the list runs by date, not by page."),
    ('frus1916', 46684): ('confirmed', "The Senate's resolution of August 29, 1916 inside the Secretary of State's letter of April 10 to the President; the list runs by date, not by page."),
    ('frus1916', 50594): ('confirmed', "The protocol of December 22, 1916 perfecting the French text of the Haitian gendarmerie protocol inside the Secretary of State's letter of August 25 to the President."),
    ('frus1916Supp', 104838): ('confirmed', "The Department's reply of September 11, 1916 to the Greek legation inside the legation's note of August 29. The reply has no file number of its own: the shape #25 describes. #25 named this volume among those it corrected."),
    ('frus1918', 18992): ('confirmed', "The Secretary of State's telegram of January 21, 1914 to Minister Jefferson inside his instruction No. 8 of December 2, 1913. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 34875): ('confirmed', "The Secretary of State's note No. 2069 of February 15, 1918 to the French ambassador inside the ambassador's note of February 5. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 36195): ('confirmed', "The Secretary of State's telegram of November 30, 1918 to Minister Reinsch inside the minister's telegram of November 25. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 39291): ('confirmed', "The Acting Secretary's telegram of March 4, 1918 to Minister Price inside the minister's telegram of March 2. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 40258): ('confirmed', "The Secretary of State's telegram of April 25, 1918 to Minister Price inside his telegram of April 23 to the chargé in Costa Rica. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 42368): ('confirmed', "The Acting Secretary's telegram of November 16, 1917 to Minister Gonzales inside the Cuban minister's note of October 11. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 43012): ('confirmed', "The Acting Secretary's telegram of July 19, 1917 to Minister Gonzales inside the minister's telegram of July 13. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 44308): ('confirmed', "The Secretary of State's letter of August 23, 1917 to Mr. McAdoo inside Mr. McAdoo's letter of August 22. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 45343): ('confirmed', "The Secretary of State's letter of October 12, 1917 to Mr. McAdoo inside Mr. Crosby's letter of October 5. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 45504): ('confirmed', "The Secretary of State's letter of December 1, 1917 to Mr. McAdoo inside Mr. McAdoo's letter of November 20. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 46518): ('confirmed', "The Secretary of State's telegram of April 5, 1918 to Minister Gonzales inside the Cuban minister's note No. 63 of March 29. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 47592): ('confirmed', "The Secretary of State's letter of September 9, 1918 to Mr. McAdoo inside Mr. McAdoo's letter of August 26. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 47898): ('confirmed', "The Secretary of State's letter of October 29, 1918 to Mr. McAdoo inside Mr. Rathbone's letter of October 17. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 50800): ('confirmed', "The Secretary of State's letter of March 25, 1918 to Mr. Daniels inside Minister Russell's despatch No. 306 of March 4. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 50929): ('confirmed', "The Secretary of State's letter of May 25, 1918 to Mr. Daniels inside Mr. Daniels's letter received May 8. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 63094): ('confirmed', "The Acting Secretary's letter of August 5, 1918 to Mr. McAdoo inside his letter of July 25. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 63256): ('confirmed', "The Secretary of State's letter of September 9, 1918 to Mr. McAdoo inside Mr. Leffingwell's letter of August 27. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 73063): ('confirmed', "The Secretary of State's telegram No. 925 of March 28, 1918 to Ambassador Fletcher inside the French ambassador's note of March 16. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 80024): ('confirmed', "The Secretary of State's telegram No. 985 of April 17, 1918 to Ambassador Fletcher inside the Tampico consul's telegram of April 15. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 87358): ('confirmed', "The Acting Secretary's telegram No. 1740 of December 21, 1918 to Ambassador Fletcher inside the ambassador's telegram of December 16. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 88392): ('confirmed', "The Acting Secretary's note No. 2090 of March 5, 1918 to the French ambassador inside the ambassador's note of February 8. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 88785): ('confirmed', "The Secretary of State's note No. 30 of March 19, 1918 to the British ambassador inside the ambassador's note No. 264 of March 12. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 88931): ('confirmed', "The Secretary of State's note of April 9, 1918 to the Belgian minister inside the minister's note of April 6. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 89512): ('confirmed', "The Secretary of State's telegram No. 1656 of November 22, 1918 to Ambassador Fletcher inside the ambassador's telegram of November 15. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 89577): ('confirmed', "The Secretary of State's telegram No. 1668 of November 29, 1918 to Ambassador Fletcher inside the ambassador's telegram of November 25. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 90540): ('confirmed', "The Secretary of State's telegram of January 14, 1918 to Minister Jefferson inside the minister's telegram of January 8. The reply has no file number of its own: the shape #25 describes."),
    ('frus1918', 92573): ('confirmed', "The Secretary of State's telegram of April 19, 1918 to Minister Jefferson inside the minister's telegram of April 5. The reply has no file number of its own: the shape #25 describes."),
    ('frus1919Parisv02', 17653): ('question', "The convention of February 16, 1919 prolonging the armistice inside the armistice of November 11, 1918, after the prolongations of December 13 and January 16: the armistice's head carries one source note for all three, and the list gives each a row of its own."),
    ('frus1919Parisv02', 28157): ('question', "The military convention signed at Belgrade on November 13, 1918 inside the armistice with Austria-Hungary of November 3, whose head's source note covers 'the convention infra'; the list gives it a row of its own."),
    ('frus1919Parisv11', 33213): ('confirmed', "Mr. Lansing's memorandum of January 16, 1919 inside Dr. Young's letter of January 15. Its source is a footnote to its head, not a note of its own: the second shape #25 describes."),
    ('frus1919Parisv11', 38044): ('confirmed', "Mr. Lansing's memorandum of March 30, 1919 inside the memorandum of March 27 on the commission's organization. Its source is a footnote to its head, not a note of its own: the second shape #25 describes."),
    ('frus1919Parisv11', 39179): ('question', "Mr. Lansing's memorandum of May 8, 1919 on the treaty's terms inside the memorandum on the commission's personnel, which is dated 'Paris, May 1919' with no day, so that it cannot be shown to be the earlier."),
    ('frus1919Parisv11', 42474): ('confirmed', "President Wilson's letter of August 8, 1919 to Senator Lodge inside the American correspondents' letter of August 5."),
    ('frus1919Parisv11', 43353): ('confirmed', "Mr. Lansing's letter of September 16, 1919 to the President, in extract, inside the commission's telegram of September 15."),
    ('frus1919Russia', 40894): ('confirmed', "President Wilson's message of July 22, 1919 to the President of the Senate inside Minister Reinsch's telegram received July 15."),
    ('frus1919v01', 61136): ('confirmed', "Proclamation No. 1512 of February 25, 1919 inside the Acting Secretary's telegram of February 12 to Minister Philip."),
    ('frus1919v01', 61219): ('confirmed', "Proclamation No. 1522–A of June 5, 1919 inside Minister Philip's telegram of May 16."),
    ('frus1920v03', 42451): ('not a defect', "Not this class: the note to the Japanese ambassador says it transmits the memorandum 'herewith', and the attachment is labelled its enclosure; the note is dated January 5, its enclosure January 9, and the list gives January 9."),
    ('frus1932v02', 17813): ('confirmed', "The waterway treaty signed with Canada on July 18, 1932 inside the Joint Board of Engineers' report of April 9."),
}
READINGS_5 = {
    ('frus1870', 9710): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 10103): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 10566): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 10642): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 12281): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 12378): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 12443): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 13532): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 13614): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 14329): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 14363): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 15545): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 19823): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 20620): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 21137): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1870', 45620): ('confirmed', "The note's item 5: the List of Papers gives the printed date."),
    ('frus1871', 20250): ('confirmed', 'The despatch of June 10, 1871 from Rio de Janeiro, received July 14, is encoded July 10; the List of Papers gives June 10.'),
    ('frus1871', 64633): ('confirmed', "The despatch of April 29, 1871 from Mexico, received May 12, is encoded May 29; the List of Papers' cell reads 'April 29 May 22', the first its printed date."),
    ('frus1871', 72337): ('confirmed', "General Sickles's despatch No. 195 of November 19, 1870 from Madrid, received December 12, is encoded December 19; the List of Papers gives Nov. 19."),
    ('frus1881', 25829): ('confirmed', "Already #469's (dates.csv, year-contradicts-text): the year encoded is the receipt's, and the volume's too."),
    ('frus1881', 26162): ('confirmed', "Already #469's (dates.csv, year-contradicts-text): the year encoded is the receipt's, and the volume's too."),
    ('frus1881', 33443): ('confirmed', "Already #469's (dates.csv, year-contradicts-text): the year encoded is the receipt's, and the volume's too."),
    ('frus1881', 50075): ('confirmed', "Already #469's (dates.csv, year-contradicts-text): the year encoded is the receipt's, and the volume's too."),
    ('frus1891', 47934): ('confirmed', "Already #469's (dates.csv, year-contradicts-text): the year encoded is the receipt's, and the volume's too."),
    ('frus1919v01', 27972): ('not a defect', "Not this class: the dateline prints May 23, 1918, but the List of Papers gives July 23 and the telegram was received July 24, 3.59 a.m., so @when is the right date and the dateline's 'May' is the slip, the book's or the transcription's."),
    ('frus1949v08', 84570): ('question', "@when is the receipt's date, August 19, not the printed August 12; sent at 5 p.m. in Nanking and received at 9.54 a.m. in Washington fits the same day, so the printed '12' may be the slip. The volume has no List of Papers."),
}


# ---------------------------------------------------------------------------------------------- run

def git(*args):
    return subprocess.run(["git", "-C", FRUS] + list(args), capture_output=True, text=True)


inventory = json.load(open(INVENTORY))
bands = {vid: row[0] for vid, row in json.load(open(ANNOTATIONS))["volumes"].items()}
october = collections.defaultdict(list)
for row in csv.DictReader(open(OCTOBER_DATES, encoding="utf-8")):
    october[(row["volume"], row["element"])].append(row["class"])
vids = sorted(inventory, key=lambda vid: (bands[vid] != ERA, vid))
assert set(vids) == set(bands), "the inventory and the annotations index name different volumes"

if not CONTEXT:
    print("corpus:", git("log", "-1", "--format=%H %cs").stdout.strip())
    same = git("diff", "--quiet", "6170e4b32", "216cdb764", "--", "volumes", "schema").returncode
    print("upstream: git diff --quiet 6170e4b32 216cdb764 -- volumes schema exits {} ({})".format(
        same, "unchanged to master at 216cdb764" if same == 0 else "CHANGED"))
    print("volumes (the inventory's, the app's manifest): {}; by band: {}".format(
        len(vids), dict(sorted(collections.Counter(bands.values()).items()))))
    print()

def brief(v, e):
    op = e.find(TEI + "opener")
    op = op if op is not None else e.find(TEI + "dateline")
    sn = next((n for n in e.findall(TEI + "note") if n.get("type") == "source"), None)
    return "«{}»{} «{}»".format(text(e.find(TEI + "head"))[:80], " source «%s»" % text(sn)[:50] if sn is not None else "",
                               text(op)[:140])


def examine(v, h, entries):
    """Each list's rows matched against one file, reduced to plain values: the list's tallies, its candidates
    (one per attachment), and the row each document or candidate attachment is matched to."""
    stats, found, rowmap, seen = [], [], {}, {}
    docs = v.documents
    for label, shape, rows, outside in entries:
        inside = [r for r in rows if h.covers(r.page) and not r.continuation]
        res = match_rows(inside, h)
        for i, (x, how) in res["match"].items():
            rowmap.setdefault(id(x["doc"]), inside[i])
        points, shift = [], None
        for i in sorted(res["match"]) if res["sequential"] else []:
            r, (x, how) = inside[i], res["match"][i]
            n = x["doc"].get("n") or ""
            if r.number and n.isdigit() and how == "page and day":
                delta = int(re.sub(r"\D", "", r.number)) - int(n)
                if delta != shift:
                    shift = delta
                    points.append("{} No. {} ({:+d})".format(x["doc"].get(XML_ID), re.sub(r"\D", "", r.number), delta))
        stats.append({"target": v.vid, "list": label, "shape": shape, "inside": len(inside), "matched": len(res["match"]),
                      "candidates": len(res["candidates"]), "inclosures": len(res["inclosures"]),
                      "unmatched": len(res["unmatched"]), "docs_without_row": res["docs_without_row"],
                      "sequential": res["sequential"], "outside": outside, "shifts": points,
                      "same_day_numbered": ["row line {}: No. {} | {} | {} | p. {}; attachment \"{}\" ({}) inside {} ({})".format(
                          c["row"].line, c["row"].number, c["row"].writer, c["row"].date_text, c["row"].page,
                          text(c["att"].find(TEI + "head"))[:50], show(c["att_date"]), c["host"].get(XML_ID),
                          show(c["host_date"])) for c in res["same_day_numbered"]]})
        for c in res["candidates"]:
            if id(c["att"]) in seen:
                seen[id(c["att"])]["lists"].append(label)
                continue
            head = c["att"].find(TEI + "head")
            k = docs.index(c["host"])
            nxt = docs[k + 1] if k + 1 < len(docs) else None
            plain = {"vid": v.vid, "lists": [label], "row": c["row"],
                     "key": (v.vid, v.line_of(head) if head is not None else v.line_of(c["att"])),
                     "host": c["host"].get(XML_ID), "host_line": v.line_of(c["host"], "xml:id"),
                     "host_date": c["host_date"], "head": text(head), "opener": text(c["att"].find(TEI + "opener")),
                     "att_date": c["att_date"], "hits": c["hits"], "paper_before": c["paper_before"] is c["host"],
                     "depth": sum(1 for a in v.ancestors(c["att"], c["host"]) if a.tag == ATTACHMENT),
                     "next": nxt.get(XML_ID) if nxt is not None else "", "documents_after": len(docs) - k - 1,
                     "host_brief": brief(v, c["host"]), "att_brief": brief(v, c["att"]),
                     "next_brief": "{} L{}: {}".format(nxt.get(XML_ID), v.line_of(nxt, "xml:id"), brief(v, nxt)[:200])
                     if nxt is not None else ""}
            seen[id(c["att"])] = plain
            found.append(plain)
            rowmap[id(c["att"])] = c["row"]
    return stats, found, rowmap


def plain_receipts(v, rowmap):
    out = []
    for row in receipt_rows(v):
        listed = rowmap.get(id(row["container"]))
        out.append({"document": row["doc"].get(XML_ID), "in_attachment": row["container"] is not row["doc"],
                    "line": row["line"], "printed": row["printed"], "when": row["when"], "received": row["received"],
                    "receipt_text": row["receipt_text"], "kind": row["kind"], "dateline": row["dateline"],
                    "listed": (listed.line, listed.date_text) if listed else None})
    return out


lists_by_vid, spans, stats, candidates, receipts = {}, {}, [], [], {}
shapes, no_list = collections.Counter(), []
for vid in vids:
    v = Volume(vid)
    h = Holdings(v)
    lists_by_vid[vid] = [(d.get(XML_ID) or "(no id)", (d.get("type"), d.get("subtype") or ""), list_rows(v, d))
                         for d in list_divisions(v)]
    if not lists_by_vid[vid]:
        no_list.append(vid)
    for label, (t, st), _ in lists_by_vid[vid]:
        shapes[(bands[vid] if bands[vid] == ERA else "after 1898", "type={} subtype={} id={}".format(
            t, st or "-", label if label in ("contents", "papers", "papers1", "toc", "toc-papers") else "other"))] += 1
    spans[vid] = h.span
    s, c, rowmap = examine(v, h, [(label, shape, rows, sum(1 for r in rows if not h.covers(r.page) and not r.continuation))
                                  for label, shape, rows in lists_by_vid[vid]])
    stats += s
    candidates += c
    receipts[vid] = plain_receipts(v, rowmap)
    del v, h

# Rows outside their own file, matched in a volume of the same year that has no list of its own.
for vid in vids:
    for label, shape, rows in lists_by_vid[vid]:
        lo, hi = spans[vid]
        outside = [r for r in rows if not (lo is not None and lo <= r.page <= hi) and not r.continuation]
        for sibling in vids:
            if sibling == vid or sibling[:8] != vid[:8] or lists_by_vid[sibling] or spans[sibling][0] is None:
                continue
            routed = [r for r in outside if spans[sibling][0] <= r.page <= spans[sibling][1]]
            if routed:
                v = Volume(sibling)
                h = Holdings(v)
                s, c, rowmap = examine(v, h, [(label + " (" + vid + ")", shape, routed, 0)])
                stats += s
                candidates += c
                receipts[sibling] = plain_receipts(v, rowmap)
                del v, h
order = {vid: n for n, vid in enumerate(vids)}
candidates.sort(key=lambda c: (order[c["vid"]], c["row"].line))
receipt_list = [(vid, row) for vid in vids for row in receipts[vid]]

if CONTEXT:
    for n, c in enumerate(candidates, 1):
        r = c["row"]
        print("#{} {} {}  [depth {}, attachments on the page with its day {}, host is the paper before: {}]".format(
            n, c["key"], c["lists"], c["depth"], c["hits"], c["paper_before"]))
        print("   row L{}: {}".format(r.line, " | ".join(r.cells)[:260]))
        print("   host {} L{} {}: {}".format(c["host"], c["host_line"], show(c["host_date"]), c["host_brief"]))
        print("   attachment {}: {}".format(show(c["att_date"]), c["att_brief"]))
        if c["next_brief"]:
            print("   next " + c["next_brief"])
    for vid, row in receipt_list:
        if row["kind"] != "other":
            print("DATE {} {} L{} «{}» when {} [{}] {} | list: {} | dateline «{}»".format(
                vid, row["document"], row["line"], row["printed"][:50], row["when"], row["receipt_text"], row["kind"],
                "L%d %s" % row["listed"] if row["listed"] else "none", row["dateline"][:160]))
    sys.exit(0)

# ---------------------------------------------------------------------------------------------- item 1 report

print("== 1. Papers the List of Papers prints that the file holds only inside an earlier paper")
listed = [vid for vid in vids if lists_by_vid[vid]]
print("  lists: {} divisions in {} volumes; with no list, {} volumes ({} of them {}: {})".format(
    sum(len(lists_by_vid[vid]) for vid in vids), len(listed), len(no_list),
    sum(1 for vid in no_list if bands[vid] == ERA), ERA, ", ".join(vid for vid in no_list if bands[vid] == ERA)))
print("  with a list, by band: {}".format(dict(sorted(collections.Counter(bands[vid] for vid in listed).items()))))
print("  how the lists are encoded:")
for (band, shape), n in sorted(shapes.items()):
    print("    {:<10} {:>4}  {}".format(band, n, shape))
print("  each list: rows on the file's pages / matched to a document / to an attachment dated after it (candidates) /")
print("  to an earlier or same-day attachment (inclosures the list names) / neither; then documents with no row")
totals = collections.Counter()
for st in stats:
    era = bands[st["target"]] == ERA
    for k in ("inside", "matched", "candidates", "inclosures", "unmatched"):
        totals[(era, k)] += st[k]
    print("    {:<18} {:<26} {:>5} {:>5} {:>3} {:>3} {:>4}; {:>4}{}{}".format(
        st["target"], st["list"][:26], st["inside"], st["matched"], st["candidates"], st["inclosures"],
        st["unmatched"], st["docs_without_row"], "  numbered 1, 2, 3 …" if st["sequential"] else "",
        "  ({} rows on pages outside the file)".format(st["outside"]) if st["outside"] else ""))
for era in (True, False):
    print("  {}: {} rows, {} matched to a document, {} to an attachment dated after it, {} to an inclosure the list "
          "names, {} to neither".format(ERA if era else "after 1898", *(totals[(era, k)] for k in (
              "inside", "matched", "candidates", "inclosures", "unmatched"))))
print()

missing = [c["key"] for c in candidates if c["key"] not in READINGS_1]
stale = [k for k in READINGS_1 if k not in {c["key"] for c in candidates}]
marks = collections.Counter()
rows_1 = []
print("  candidates: {} attachments in {} volumes ({} of them, in {} volumes, {})".format(
    len(candidates), len({c["vid"] for c in candidates}), sum(1 for c in candidates if bands[c["vid"]] == ERA),
    len({c["vid"] for c in candidates if bands[c["vid"]] == ERA}), ERA))
for c in candidates:
    r = c["row"]
    mark, note = READINGS_1.get(c["key"], ("UNREAD", ""))
    marks[(bands[c["vid"]] == ERA, mark)] += 1
    print("  {} [{}] row line {}: {} | {} | {} | p. {}".format(
        c["vid"], mark, r.line, r.number or "-", r.writer or r.subject[:40], r.date_text, r.page))
    print("      inside {} (line {}, dated {}); its head at line {}: \"{}\", dated {}{}{}".format(
        c["host"], c["host_line"], show(c["host_date"]), c["key"][1], c["head"][:70], show(c["att_date"]),
        "; depth {}".format(c["depth"]) if c["depth"] else "",
        "" if c["paper_before"] else "; not the paper before it in the list"))
    if note:
        print("      reading: " + note)
    rows_1.append({"volume": c["vid"], "band": bands[c["vid"]], "list": " ".join(c["lists"]), "row_line": r.line,
                   "row_number": r.number, "row_writer": r.writer, "row_date": r.date_text, "row_subject": r.subject,
                   "row_page": r.page, "filed_inside": c["host"], "filed_inside_line": c["host_line"],
                   "filed_inside_date": show(c["host_date"]), "head_line": c["key"][1], "head": c["head"],
                   "opener": c["opener"][:200], "date": show(c["att_date"]), "depth": c["depth"],
                   "next_document": c["next"], "documents_after": c["documents_after"], "mark": mark, "note": note})
for era in (True, False):
    print("  {}: {}".format(ERA if era else "after 1898", dict(sorted((m, n) for (e, m), n in marks.items() if e == era))))
by_volume = collections.OrderedDict()
for row in rows_1:
    if row["mark"] == "confirmed":
        by_volume.setdefault(row["volume"], []).append(row)
print("  confirmed, by volume: how many, the earliest document in the file that one is filed inside, and the")
print("  documents after it, which a division of its own for that paper renumbers:")
for vid, rows in by_volume.items():
    first = max(rows, key=lambda row: row["documents_after"])
    print("    {:<16} {:>3}  earliest inside {} (line {}); {} documents after it".format(
        vid, len(rows), first["filed_inside"], first["filed_inside_line"], first["documents_after"]))
print("  confirmed: {} papers in {} volumes ({} in {} volumes of {})".format(
    sum(len(r) for r in by_volume.values()), len(by_volume),
    sum(len(r) for vid, r in by_volume.items() if bands[vid] == ERA),
    sum(1 for vid in by_volume if bands[vid] == ERA), ERA))
print()
print("  numbered rows whose attachment is not dated after the paper it sits in (checked, not reported):")
for st in stats:
    for line in st["same_day_numbered"]:
        print("    {} {}".format(st["target"], line))
print()
print("  numbered lists: where a document's @n leaves the number the list gives its paper (number - @n):")
for st in stats:
    if any(not p.endswith("(+0)") for p in st["shifts"]):
        print("    {:<14} {}".format(st["target"], ", ".join(st["shifts"][:12]) + (" …" if len(st["shifts"]) > 12 else "")))
print()

# ---------------------------------------------------------------------------------------------- item 5 report

print("== 5. Dates whose month is the receipt's")
kinds = collections.Counter((bands[vid] == ERA, row["kind"]) for vid, row in receipt_list)
print("  <date when> whose printed month and day contradict @when (either reading, where the editors correct the day):")
print("  {} in the 553 volumes ({} in {})".format(len(receipt_list), sum(n for (e, k), n in kinds.items() if e), ERA))
for era in (True, False):
    print("    {}: {}".format(ERA if era else "after 1898", dict(sorted((k, n) for (e, k), n in kinds.items() if e == era))))
with_receipt = [row for vid, row in receipt_list if row["received"]]
print("  of them, with a receipt in the dateline or opener: {}; among the others of those, @when's month is the "
      "receipt's (its day not the printed one) in {}".format(len(with_receipt), sum(
          1 for row in with_receipt if row["kind"] == "other" and iso(row["when"])[1] == row["received"][1])))
near = [(vid, row) for vid, row in receipt_list if row["kind"] == "other" and row["received"]
        and iso(row["when"])[1] == row["received"][1] != printed_date(row["printed"])[1]]
print("  of those, the receipt's month is not the printed one, so that @when has the receipt's month and neither "
      "its day nor the printed day: {}".format(len(near)))
for vid, row in near:
    print("    {} {} line {}: \"{}\" encoded {}; {}".format(vid, row["document"], row["line"], row["printed"][:50],
                                                       row["when"], row["receipt_text"]))
shifted = [(vid, row) for vid, row in receipt_list if row["kind"] == "other" and not row["received"]]
print("  with no receipt: {}".format(len(shifted)))
reported = [(vid, row) for vid, row in receipt_list if row["kind"] != "other"]
missing += [(vid, row["line"]) for vid, row in reported if (vid, row["line"]) not in READINGS_5]
stale += [k for k in READINGS_5 if k not in {(vid, row["line"]) for vid, row in reported}]
rows_5 = []
for vid, row in reported:
    mark, note = READINGS_5.get((vid, row["line"]), ("UNREAD", ""))
    in_october = october.get((vid, row["document"]), [])
    print("  {} {} [{}] line {}: \"{}\" encoded {}; {}; {}; List of Papers: {}{}".format(
        vid, row["document"], mark, row["line"], row["printed"][:60], row["when"], row["receipt_text"], row["kind"],
        "line {} \"{}\"".format(*row["listed"]) if row["listed"] else "no row",
        "; in #469's dates.csv: " + ", ".join(in_october) if in_october else ""))
    if note:
        print("      reading: " + note)
    rows_5.append({"volume": vid, "band": bands[vid], "document": row["document"],
                   "in_attachment": row["in_attachment"], "line": row["line"], "printed": row["printed"],
                   "when": row["when"], "receipt": row["receipt_text"], "class": row["kind"],
                   "list_row_line": row["listed"][0] if row["listed"] else "",
                   "list_row_date": row["listed"][1] if row["listed"] else "",
                   "in_oct_report": ", ".join(in_october), "dateline": row["dateline"], "mark": mark, "note": note})
print("  by class and mark: {}".format(dict(sorted(collections.Counter((r["class"], r["mark"]) for r in rows_5).items()))))
print()

# ---------------------------------------------------------------------------------------------- controls

print("== Controls")
expected_1870 = {("frus1870", 30237), ("frus1870", 40555), ("frus1870", 45645)}
found_1870 = {c["key"] for c in candidates if c["vid"] == "frus1870"}
print("  item 1, frus1870: Nos. 216, 284 and 303 at heads 30237, 40555 and 45645, and nothing else: {}".format(
    found_1870 == expected_1870))
receipt_1870 = sorted(row["line"] for row in receipts["frus1870"] if row["kind"] == "receipt month")
note_1870 = [9710, 10103, 10566, 10642, 12281, 12378, 12443, 13532, 13614, 14329, 14363, 15545, 19823, 20620,
             21137, 45620]
print("  item 5, frus1870: the note's 16 dates of receipt, at its lines: {}".format(receipt_1870 == note_1870))
print("  readings: every candidate has one: {}; every reading names a candidate: {}".format(not missing, not stale))
for k in missing:
    print("    UNREAD", k)
for k in stale:
    print("    STALE", k)

os.makedirs(OUT, exist_ok=True)
for name, rows in (("papers-filed-inside.csv", rows_1), ("receipt-month-dates.csv", rows_5)):
    with open(os.path.join(OUT, name), "w", newline="", encoding="utf-8") as f:
        if rows:
            w = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator="\n")
            w.writeheader()
            w.writerows(rows)
    print("  wrote {} ({} rows)".format(name, len(rows)))
if missing or stale or found_1870 != expected_1870 or receipt_1870 != note_1870:
    sys.exit("the run does not agree with its readings or its controls")
