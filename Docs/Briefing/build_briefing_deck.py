# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Builds the FRUS Explorer app briefing deck from the launch kit's copy and the store captures.

Every sentence is lifted or condensed from Planning/Launch-Marketing-Kit-2026-10-13.md,
Planning/Store-Listing-Draft.md, tools/marketing/shots.json, Docs/Support.md and README.md.
Every figure is one of the store draft's §5 figures or the kit's §1a figures.
"""
import os, sys
from pathlib import Path
from PIL import Image
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.oxml.ns import qn

REPO = Path(sys.argv[1])
OUT = Path(sys.argv[2])
CACHE = Path(sys.argv[3]); CACHE.mkdir(parents=True, exist_ok=True)

# Palette: the store frames' (tools/marketing/compose.py) light and dark themes, and the icon's red.
INK = RGBColor(0x1C, 0x1C, 0x1E)
SUB = RGBColor(0x5C, 0x5C, 0x61)
ACCENT = RGBColor(0xA6, 0x1C, 0x2A)
BG = RGBColor(0xF2, 0xF2, 0xF4)
PANEL = RGBColor(0xFF, 0xFF, 0xFF)
FRAME = RGBColor(0xD6, 0xD6, 0xDA)
DARK_BG = RGBColor(0x0F, 0x12, 0x17)
DARK_PANEL = RGBColor(0x1A, 0x1E, 0x26)
DARK_INK = RGBColor(0xF5, 0xF5, 0xF7)
DARK_SUB = RGBColor(0xA8, 0xA8, 0xB0)
DARK_ACCENT = RGBColor(0xE8, 0x79, 0x8A)
TINT = RGBColor(0xFB, 0xEE, 0xEF)   # a wash of the accent, for one card per slide

HEAD = "Georgia"
BODY = "Arial"

DISCLAIMER = ("FRUS Explorer is an independent research tool. It is not an official product of the "
              "Office of the Historian or the U.S. Department of State. The FRUS series itself is in the public domain.")
NARA = ("Not affiliated with, endorsed by, or sponsored by the National Archives and Records Administration. "
        "Catalog data is subject to NARA's terms of use.")

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)
BLANK = prs.slide_layouts[6]
W, H = 13.333, 7.5
MARGIN = 0.6


# ---------- helpers ----------
def prep_image(rel, max_w=1700, jpeg=True):
    src = REPO / rel
    name = rel.replace("/", "__")
    out = CACHE / (Path(name).stem + (".jpg" if jpeg else ".png"))
    if not out.exists():
        im = Image.open(src)
        if im.width > max_w:
            im = im.resize((max_w, round(im.height * max_w / im.width)), Image.LANCZOS)
        if jpeg:
            im.convert("RGB").save(out, "JPEG", quality=90, optimize=True)
        else:
            im.save(out, "PNG", optimize=True)
    im = Image.open(out)
    return out, im.width / im.height


def set_fill(shape, color):
    shape.fill.solid()
    shape.fill.fore_color.rgb = color


def no_shadow(shape):
    shape.shadow.inherit = False


def rect(slide, x, y, w, h, color, line=None, rounded=False, radius=0.06):
    shp = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if rounded else MSO_SHAPE.RECTANGLE,
                                 Inches(x), Inches(y), Inches(w), Inches(h))
    set_fill(shp, color)
    if rounded:
        shp.adjustments[0] = radius
    if line is None:
        shp.line.fill.background()
    else:
        shp.line.color.rgb = line
        shp.line.width = Pt(0.75)
    no_shadow(shp)
    return shp


def _apply_run(run, size, bold, italic, color, font, spacing=None):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.name = font
    run.font.color.rgb = color
    if spacing is not None:
        run._r.get_or_add_rPr().set("spc", str(int(spacing * 100)))


def text(slide, x, y, w, h, content, size=14, bold=False, italic=False, color=INK, font=BODY,
         align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, spacing=None, line_spacing=None, para_after=None,
         margin=0, bullets=False, wrap=True):
    """content: str, or a list of paragraphs; a paragraph is a str or a list of (text, opts) runs."""
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame
    tf.word_wrap = wrap
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = Inches(margin)
    paras = content if isinstance(content, list) else [content]
    for i, p in enumerate(paras):
        para = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        para.alignment = align
        if line_spacing:
            para.line_spacing = line_spacing
        if para_after is not None:
            para.space_after = Pt(para_after)
        runs = p if isinstance(p, list) else [(p, {})]
        if bullets:
            pPr = para._p.get_or_add_pPr()
            pPr.set("marL", str(Emu(Inches(0.22))))
            pPr.set("indent", str(-Emu(Inches(0.22))))
            bu = pPr.makeelement(qn("a:buChar"), {"char": "•"})
            pPr.append(bu)
        for t, o in runs:
            r = para.add_run()
            r.text = t
            _apply_run(r, o.get("size", size), o.get("bold", bold), o.get("italic", italic),
                       o.get("color", color), o.get("font", font), o.get("spacing", spacing))
    return tb


def picture(slide, rel, x, y, w=None, h=None, border=FRAME, max_w=1700):
    path, ratio = prep_image(rel, max_w=max_w)
    if w is None:
        w = h * ratio
    elif h is None:
        h = w / ratio
    else:
        # fit inside the box
        if w / h > ratio:
            w = h * ratio
        else:
            h = w / ratio
    pic = slide.shapes.add_picture(str(path), Inches(x), Inches(y), Inches(w), Inches(h))
    if border is not None:
        pic.line.color.rgb = border
        pic.line.width = Pt(0.75)
    return pic, w, h


def footer(slide, n, dark=False, extra=None):
    col = DARK_SUB if dark else SUB
    line = DISCLAIMER if extra is None else DISCLAIMER + " " + extra
    text(slide, MARGIN, H - 0.55, W - 2 * MARGIN - 0.6, 0.4, line, size=9, color=col, anchor=MSO_ANCHOR.BOTTOM)
    text(slide, W - MARGIN - 0.5, H - 0.55, 0.5, 0.4, str(n), size=10, color=col, align=PP_ALIGN.RIGHT,
         anchor=MSO_ANCHOR.BOTTOM)


def notes(slide, body):
    slide.notes_slide.notes_text_frame.text = body


def base(dark=False):
    s = prs.slides.add_slide(BLANK)
    bg = s.background.fill
    bg.solid()
    bg.fore_color.rgb = DARK_BG if dark else BG
    return s


def header(slide, eyebrow, title, dark=False, title_size=32, title_w=W - 2 * MARGIN):
    acc = DARK_ACCENT if dark else ACCENT
    ink = DARK_INK if dark else INK
    text(slide, MARGIN, 0.45, 8, 0.3, eyebrow.upper(), size=11, bold=True, color=acc, spacing=1.6)
    text(slide, MARGIN, 0.78, title_w, 1.2, title, size=title_size, bold=True, color=ink, font=HEAD,
         line_spacing=1.05, anchor=MSO_ANCHOR.TOP)


def card(slide, x, y, w, h, title, body, dark=False, tint=False, title_size=16, body_size=14, title_color=None,
         body_top=0.75):
    fill = DARK_PANEL if dark else (TINT if tint else PANEL)
    rect(slide, x, y, w, h, fill, line=None if dark else FRAME, rounded=True, radius=0.05)
    tcol = title_color or (DARK_INK if dark else INK)
    bcol = DARK_SUB if dark else SUB
    text(slide, x + 0.28, y + 0.25, w - 0.56, body_top - 0.3, title, size=title_size, bold=True, color=tcol, font=HEAD,
         line_spacing=1.0)
    text(slide, x + 0.28, y + body_top, w - 0.56, h - body_top - 0.15, body, size=body_size, color=bcol,
         line_spacing=1.12, para_after=5)


def stat(slide, x, y, w, h, number, label, dark=False, size=32):
    fill = DARK_PANEL if dark else PANEL
    rect(slide, x, y, w, h, fill, line=None if dark else FRAME, rounded=True, radius=0.05)
    text(slide, x + 0.25, y + 0.22, w - 0.5, 0.85, number, size=size, bold=True, color=ACCENT if not dark else DARK_ACCENT,
         font=HEAD, anchor=MSO_ANCHOR.BOTTOM)
    text(slide, x + 0.25, y + 1.1, w - 0.5, h - 1.2, label, size=13, color=DARK_SUB if dark else SUB, line_spacing=1.1)


def pill(slide, x, y, label, dark=False, right=False):
    """A small capsule label such as COMING SOON. With right=True, x is the capsule's right edge."""
    w = 0.1 * len(label) + 0.4
    if right:
        x = x - w
    fill = DARK_ACCENT if dark else ACCENT
    rect(slide, x, y, w, 0.3, fill, rounded=True, radius=0.5)
    text(slide, x, y, w, 0.3, label, size=9, bold=True, color=DARK_BG if dark else PANEL, align=PP_ALIGN.CENTER,
         anchor=MSO_ANCHOR.MIDDLE, spacing=1.2)
    return w


def right_picture(slide, rel, max_h=4.45, max_w=7.3, border=FRAME):
    """A screenshot on the right, fitted inside max_w × max_h and flush with the right margin.
    Returns (x, y, w, h) so the text column and the caption can be laid out against it."""
    path, ratio = prep_image(rel)
    w, h = max_w, max_w / ratio
    if h > max_h:
        h, w = max_h, max_h * ratio
    x = W - MARGIN - w
    picture(slide, rel, x, 2.1, w=w, h=h, border=border)
    return x, 2.1, w, h


# ============ 1. Title ============
s = base(dark=True)
picture(s, "Docs/screenshots/ipad/semantic-map.png", 6.55, 0.9, w=6.2, border=RGBColor(0x2A, 0x2E, 0x36))
icon_path, _ = prep_image("FRUSExplorer/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png", max_w=512, jpeg=False)
s.shapes.add_picture(str(icon_path), Inches(MARGIN), Inches(1.25), Inches(1.5), Inches(1.5))
text(s, MARGIN, 3.0, 5.6, 1.0, "FRUS Explorer", size=44, bold=True, color=DARK_INK, font=HEAD)
text(s, MARGIN, 4.05, 5.6, 1.3,
     "The edited record of U.S. diplomacy, on your device, with tools built on its editors' work.",
     size=20, color=DARK_SUB, line_spacing=1.15)
pill(s, MARGIN, 5.2, "COMING SOON TO THE APP STORE", dark=True)
text(s, MARGIN, 5.6, 5.6, 0.7,
     ["App briefing · October 2026", "Version 1.0, build 1861, awaiting App Store submission · iPhone, iPad and Mac · free"],
     size=12, color=DARK_SUB, line_spacing=1.2)
text(s, 6.55, 5.7, 6.2, 0.3,
     "Semantic map of 314,616 documents, iPad. Layout preserves local similarity; distances between far regions are not meaningful. Experimental.",
     size=9, color=DARK_SUB, italic=True)
footer(s, 1, dark=True)
notes(s, "One line, from the launch kit §1: the edited record of U.S. diplomacy, on your device, with tools built "
         "on its editors' work.\n\nThe 105-word pitch: FRUS Explorer is a research tool for the Foreign Relations of the "
         "United States series, the State Department's documentary record of American foreign policy, published since "
         "1861 and edited today by historians in the Office of the Historian. It downloads the Office's TEI editions, "
         "indexes them on your iPhone, iPad or Mac, and works offline. Its tools are built on the editors' apparatus: "
         "source notes resolved to the shelf, cross-references drawn as a graph, and the people and dates the editors "
         "identified made searchable. It is an independent project, not an official product of the Office of the "
         "Historian or the U.S. Department of State.")

# ============ 2. The series ============
s = base()
header(s, "The series", "The official documentary record of U.S. foreign policy, published since 1861")
text(s, MARGIN, 2.15, 5.9, 4.3, [
    [("Foreign Relations of the United States", {"italic": True}),
     (" is the State Department's official documentary record of American foreign policy: declassified cables, "
      "memoranda, minutes and intelligence estimates, every one of them in the public domain.", {})],
    "The series is worth building on because of how it is made. Its editors, today the historians of the Office of "
    "the Historian, choose the documents that record major decisions from the files of the Department and the other "
    "agencies involved. They print them in date order, write each one's heading, note where the original is kept, "
    "point to related documents, summarize what they could not print, and mark what remains classified.",
    "By statute the series must be “a thorough, accurate, and reliable record”, with every deletion marked where it "
    "occurs. The Office also publishes it as open data: each digitized volume as TEI, with the editors' dates, people "
    "and cross-references encoded, free to read, search and download at history.state.gov.",
], size=14, color=INK, line_spacing=1.18, para_after=12)
sx, sy, sw, sh, gap = 7.03, 2.15, 2.75, 1.95, 0.2
stat(s, sx, sy, sw, sh, "553", "volumes in the app's bundled manifest", size=30)
stat(s, sx + sw + gap, sy, sw, sh, "1861", "the year the series began publishing", size=30)
stat(s, sx, sy + sh + gap, sw, sh, "107", "subseries, from the early volumes to 1981–1988", size=30)
stat(s, sx + sw + gap, sy + sh + gap, sw, sh, "~317,000", "documents in a full local index", size=30)
footer(s, 2)
notes(s, "Figures: 553 volumes (manifest.json entry count); published since 1861 (earliest publicationDate); 107 "
         "subseries (distinct subseries in the manifest); about 317,000 documents (316,814 at index v63, said with "
         "'about'). Never say 'every document': a full index holds 316,814 and the map places 314,616.\n\nThe statute "
         "quotation and the editors' method are from the series' own prefaces (Foreign Relations 1969–1976, vol. E–9, "
         "part 1, 'Editorial Methodology'). Speak about the series' method, never for the Office.")

# ============ 3. What the app is ============
s = base()
header(s, "The app", "FRUS Explorer puts the series on your iPhone, iPad or Mac and builds a workbench around it")
text(s, MARGIN, 2.15, 6.4, 3.0, [
    "It downloads the Office of the Historian's TEI editions, indexes them on your device, and works offline from "
    "then on. Its tools build on the Office's editorial excellence and its innovation in publishing: the editors' "
    "apparatus, encoded in open TEI, becomes source notes resolved to the shelf, cross-references drawn as a graph, "
    "and the people and dates the editors identified made searchable.",
    "What you read, search and write stays with you: notes and collections sync only through your own iCloud account, "
    "and the app reaches the National Archives' catalog or your Zotero library only when you ask it to.",
], size=14, color=INK, line_spacing=1.18, para_after=12)
cx, cy, cw, ch, g = MARGIN, 4.85, 2.0, 1.75, 0.2
for i, (t, b) in enumerate([("iPhone, iPad and Mac", "iOS, iPadOS and macOS 26"),
                            ("Free, coming soon", "Every storefront, English only"),
                            ("Offline", "After the volumes you choose are downloaded")]):
    rect(s, cx + i * (cw + g), cy, cw, ch, PANEL, line=FRAME, rounded=True, radius=0.06)
    text(s, cx + i * (cw + g) + 0.2, cy + 0.2, cw - 0.4, 0.75, t, size=16, bold=True, color=ACCENT, font=HEAD,
         line_spacing=1.0)
    text(s, cx + i * (cw + g) + 0.2, cy + 0.98, cw - 0.4, ch - 1.1, b, size=12, color=SUB, line_spacing=1.1)
card(s, 7.6, 2.15, 5.1, 4.35, "What it is not, said first by us", [
    [("Not official. ", {"bold": True, "color": INK}), ("An independent tool; the series is published by the Office of "
     "the Historian and is in the public domain. The app's commentary reflects personal views.", {})],
    [("Not every document. ", {"bold": True, "color": INK}), ("Two honest counts, neither “every”: about 317,000 "
     "in a full index, 314,616 on the map.", {})],
    [("Not a chatbot. ", {"bold": True, "color": INK}), ("The optional on-device model turns a question into a vector. "
     "Summaries are Apple's on-device framework, one document at a time, with authorship recorded.", {})],
    [("English only ", {"bold": True, "color": INK}), ("in this release.", {})],
], tint=True)
footer(s, 3)
notes(s, "Voice rule from the kit: plain, concrete, second person, with the research vocabulary the audience already has. "
         "No exclamation marks. A headline is a verb phrase or a claim; a subline says what the frame shows and one "
         "honest limit.")

# ============ 4. Three proof points ============
s = base()
header(s, "Three proof points", "Each claim has a screen that proves it")
cols = [
    ("Docs/screenshots/macos/search.png", "Offline, whole-series search with facets",
     "553 volumes; phrases, proximity and exact words; facets by year, volume, person, document type, provenance and subject.",
     "Built on the Office's open TEI editions: the dates, people and cross-references its editors encoded, indexed whole on your device."),
    ("Docs/screenshots/ipad/source-explorer.png", "The editors' apparatus, put to work",
     "A source note resolves to record group, entry and lot; a cross-reference becomes an edge in a graph; a name becomes a person you can follow across the series.",
     "A bulk release of documents has none of this. Nothing else turns a FRUS footnote into a pull slip."),
    ("Docs/screenshots/ipad/semantic-map.png", "The series as a whole",
     "A map of 314,616 documents by the language they share; term frequency, person networks, chronology, archival sourcing, exportable with their method.",
     "The first time anyone has been able to look at the published record from above."),
]
cw, g = 3.9, 0.2
for i, (img, t, b, why) in enumerate(cols):
    x = MARGIN + i * (cw + g)
    rect(s, x, 2.05, cw, 4.75, PANEL, line=FRAME, rounded=True, radius=0.04)
    picture(s, img, x + 0.2, 2.25, w=cw - 0.4, h=2.1, max_w=1200)
    text(s, x + 0.25, 4.45, cw - 0.5, 0.55, t, size=16, bold=True, color=INK, font=HEAD, line_spacing=1.05)
    text(s, x + 0.25, 5.0, cw - 0.5, 1.05, b, size=12, color=SUB, line_spacing=1.12)
    text(s, x + 0.25, 6.05, cw - 0.5, 0.7, why, size=11, italic=True, color=ACCENT, line_spacing=1.1)
footer(s, 4)
notes(s, "Launch kit §1, 'Three proof points, each with its screen'. The screens: Search with the Facets inspector "
         "(Mac), Source Explorer (iPad), the semantic map (iPad).")

# ============ 5. Built on the editors' work ============
s = base()
header(s, "Built on the Office's editorial work", "What the editors do, and what the app does with it")
rows = [
    ("What a researcher needs", "The edited series", "What the app does with it"),
    ("Selection", "“all records needed to provide comprehensive documentation of major foreign policy decisions”",
     "Searches the record the editors assembled; its counts are counts of what they chose to print"),
    ("Order", "“The documents are presented chronologically according to Washington time.”",
     "Chronology, Administrations and date order use the dates the editors assigned"),
    ("A name for each item", "“A heading has been supplied by the editors for each document included in the volume.”",
     "Results, Browse, citations and collections list documents under those headings"),
    ("Where the original is", "“The first footnote to each document indicates the document's source, original classification, distribution, and drafting information.”",
     "Source Explorer, the Archives Visit packet, the provenance facet and Archival Analytics"),
    ("How documents connect", "annotation that will “provide references to important related documents printed in other volumes”",
     "Live links, the Cross-Reference Graph and Cross-Reference Analytics"),
    ("What isn't there", "editorial notes “summarize pertinent material not printed”; withheld text is marked with the lines or pages omitted",
     "Editorial notes are searchable; the packet lists files the editors cited but didn't print"),
    ("Who is speaking", "lists of persons and of abbreviations and terms in the front matter",
     "Person cards, the People browser, the person facet and Person Analytics"),
]
tbl_shape = s.shapes.add_table(len(rows), 3, Inches(MARGIN), Inches(2.05), Inches(W - 2 * MARGIN), Inches(4.6))
tbl = tbl_shape.table
tbl.columns[0].width = Inches(2.5)
tbl.columns[1].width = Inches(5.2)
tbl.columns[2].width = Inches(W - 2 * MARGIN - 7.7)
# plain style: drop the default table style's banding
tblPr = tbl._tbl.tblPr
tblPr.set("bandRow", "0"); tblPr.set("firstRow", "0")
for r, row in enumerate(rows):
    for c, val in enumerate(row):
        cell = tbl.cell(r, c)
        cell.fill.solid()
        cell.fill.fore_color.rgb = TINT if r == 0 else (PANEL if r % 2 else BG)
        cell.margin_left = cell.margin_right = Inches(0.12)
        cell.margin_top = cell.margin_bottom = Inches(0.05)
        cell.vertical_anchor = MSO_ANCHOR.MIDDLE
        tf = cell.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        run = p.add_run(); run.text = val
        if r == 0:
            _apply_run(run, 12, True, False, ACCENT, BODY)
        elif c == 0:
            _apply_run(run, 12, True, False, INK, BODY)
        elif c == 1:
            _apply_run(run, 11, False, True, SUB, BODY)
        else:
            _apply_run(run, 12, False, False, INK, BODY)
text(s, MARGIN, 6.72, W - 2 * MARGIN, 0.3,
     "Middle column: the preface's “Editorial Methodology”, Foreign Relations of the United States, 1969–1976, vol. E–9, part 1 (2014), public domain. "
     "Of 553 volumes, 51 carry no source note paired with a document, nearly all published before 1910.",
     size=9, italic=True, color=SUB)
footer(s, 5)
notes(s, "Kit §1a. Rules: name the element, then the feature; credit the note to the editors and the reading to the "
         "app; keep the layers apart (FRUS text, joined, computed); speak about the series' method, never for the "
         "Office; mind the eras; never 'curated', 'annotated' or 'organized by FRUS Explorer'.\n\nFigures this theme "
         "may quote: 264,598 source notes paired with a document, in 502 of 553 volumes; 8,637 cross-volume citations "
         "into 5,747 documents from 185 volumes; 81 volumes published 1861–1922 whose header names no editor.")

# ============ 6. Search ============
s = base()
header(s, "For everyone · 1 of 3", "Search 553 volumes of the U.S. diplomatic record. Offline")
px, py, pw, ph = right_picture(s, "Docs/screenshots/macos/search.png")
tw = px - 0.45 - MARGIN
text(s, MARGIN, 2.15, tw, 1.4,
     "Full-text search with phrases, proximity and exact words, faceted by year, volume, person, document type, "
     "archival provenance and subject.", size=15, color=INK, line_spacing=1.18)
text(s, MARGIN, 3.65, tw, 0.3, "BUILT ON THE OFFICE'S TEI EDITIONS", size=10, bold=True, color=ACCENT, spacing=1.2)
text(s, MARGIN, 3.95, tw, 2.6, [
    "The Office of the Historian encodes each volume in TEI, with the editors' dates, people, document types and source notes marked. The app indexes that encoding whole, on your device, and adds:",
    "Facets that count the whole match before you narrow it: year, volume, the people the editors tagged, document or editorial note, and where the original is filed.",
    "A scope you can save, or a result set frozen as a working corpus, a denominator you can cite.",
    "The Query Inspector, and four readings of a result set: ranked list, timeline, concordance and collocates. All of it offline.",
], size=12, color=SUB, line_spacing=1.12, para_after=6, bullets=True)
text(s, px, py + ph + 0.06, pw, 0.3, "Search on the Mac, with the Facets inspector open. Build 1861.", size=9, italic=True, color=SUB)
footer(s, 6)
notes(s, "If asked about history.state.gov: it is the Office's own edition of the series and its search, and every "
         "document and citation in the app links back to its page there. The app is a research workbench on the same "
         "TEI editions, offline, and is described by what it adds, never against the site: facets computed over the "
         "match with counts (person, document type, archival provenance, subject, year, volume); a result set frozen "
         "as a working corpus; saved scopes; the Query Inspector; concordance and collocates; source-note resolution; "
         "and a route to Zotero. The Office's digitization, TEI encoding and open publication are what make the app "
         "possible. The app is free.")

# ============ 7. Reader ============
s = base()
header(s, "For everyone · 2 of 3", "Read it as printed. Keep what you find")
pic, pw, ph = picture(s, "Docs/screenshots/ipad/research-rail.png", MARGIN, 2.1, h=4.45)
tx = MARGIN + pw + 0.45
text(s, tx, 2.15, W - MARGIN - tx, 1.5,
     "The editors' headings, footnotes and cross-references, live, with a research rail beside the text for notes, "
     "highlights, tags, summaries and citations.", size=15, color=INK, line_spacing=1.18)
text(s, tx, 3.7, W - MARGIN - tx, 0.3, "FRUS TEXT, KEPT APART FROM YOURS", size=10, bold=True, color=ACCENT, spacing=1.2)
text(s, tx, 4.0, W - MARGIN - tx, 2.6, [
    "Documents render from the Office's own TEI with footnotes, page breaks, cross-references and person links live.",
    "Highlight, annotate and tag; file it all under a project. The app never mixes your notes into the published text.",
    "Cite in the Department's style, in BibTeX or RIS, or straight into Zotero. Every citation credits the volume's editors by name.",
    "Summaries, on request, from Apple's on-device model, one document at a time, with authorship recorded.",
], size=12, color=SUB, line_spacing=1.12, para_after=6, bullets=True)
text(s, MARGIN, 6.6, pw, 0.3, "The reader with the Research rail, iPad. Build 1861.", size=9, italic=True, color=SUB)
footer(s, 7)
notes(s, "Frame 02 of the store set. Layer rule: FRUS text is read from the volumes alone; the reader's own notes "
         "are a fourth thing the app never mixes into the published text.")

# ============ 8. Map ============
s = base(dark=True)
header(s, "For everyone · 3 of 3", "See the whole series at once", dark=True)
px, py, pw, ph = right_picture(s, "Docs/screenshots/ipad/semantic-map.png", border=RGBColor(0x2A, 0x2E, 0x36))
tw = px - 0.45 - MARGIN
sw = (tw - 0.2) / 2
text(s, MARGIN, 2.15, tw, 1.3,
     "314,616 documents placed by the language they share and named by the vocabulary that sets each region apart. "
     "Tap a document to open it, lasso a set to keep it.", size=15, color=DARK_INK, line_spacing=1.18)
stat(s, MARGIN, 3.6, sw, 1.75, "140", "regions, named by their own vocabulary", dark=True)
stat(s, MARGIN + sw + 0.2, 3.6, sw, 1.75, "0", "volumes needed: the map ships inside the app", dark=True)
text(s, px, py + ph + 0.06, pw, 0.3, "The semantic map, iPad. Build 1861.", size=9, italic=True, color=DARK_SUB)
text(s, MARGIN, 5.6, tw, 0.9,
     "Experimental. This is an AI model's reading of the language, not an editorial fact, and its quality before 1900 has not been measured. "
     "Layout preserves local similarity; distances between far regions are not meaningful.",
     size=10, color=DARK_ACCENT, line_spacing=1.12)
footer(s, 8, dark=True)
notes(s, "Frame 03. The map is a computed layer: the app's model reading the language, experimental, not an editorial "
         "fact. Figures: 314,616 documents on the map (semantic-vectors-index.json), 140 regions "
         "(semantic-map-index.json, after the EmbeddingGemma 2 relayout of 2026-10-15). The caveat line and "
         "'Experimental' must stay in any frame that shows the map.")

# ============ 9. Three audiences ============
s = base()
header(s, "Who it is for", "Three audiences, three jobs, three lead features each")
aud = [
    ("Researchers", "Historians and graduate students",
     "Find everything on a question across the series, read it with the apparatus intact, keep the receipts, cite it, and know where the originals are before the trip.",
     ["Search with facets, working corpora and the Query Inspector: a result set they can defend.",
      "Source Explorer and the Archives Visit packet: the source note resolved, the RG, entry and NAID lines, the advance inquiry drafted.",
      "Cite, Zotero and the method appendix: the citation in the Department's style, the search log a committee can read."]),
    ("Teachers", "Course readers, lecture material, classroom analytics",
     "Assemble a reader for next week with framing and questions; put a document in front of thirty students without thirty logins; show, live, why the record looks the way it does.",
     ["Collections with the Teaching reader preset, sections, excerpts, headnotes and front matter, exported to PDF or Word.",
      "A shareable collection file and Share Citation: the same set to every student, each annotating independently.",
      "The About the Series dashboards and Corpus Analytics with % of documents, all offline."]),
    ("Policy analysts", "Crisis chronologies, meaning search, who the record orbits",
     "What did Washington know and argue in the month of a crisis, across every file that printed it? Who was in the room? What did the record say the last time this came up?",
     ["Chronology: a date window, every dated document in it from every volume on the device.",
      "Search by meaning, on the device, and Person Analytics for who the record orbits.",
      "Corpus Analytics from a search, and the Briefing packet preset with on-device summaries."]),
]
cw, g = 3.9, 0.2
for i, (t, who, job, feats) in enumerate(aud):
    x = MARGIN + i * (cw + g)
    rect(s, x, 2.05, cw, 4.75, PANEL, line=FRAME, rounded=True, radius=0.04)
    text(s, x + 0.25, 2.25, cw - 0.5, 0.45, t, size=20, bold=True, color=ACCENT, font=HEAD)
    text(s, x + 0.25, 2.72, cw - 0.5, 0.55, who, size=12, bold=True, color=INK, line_spacing=1.05)
    text(s, x + 0.25, 3.35, cw - 0.5, 1.3, job, size=12, italic=True, color=SUB, line_spacing=1.12)
    text(s, x + 0.25, 4.7, cw - 0.5, 2.05, feats, size=11, color=INK, line_spacing=1.1, para_after=5, bullets=True)
footer(s, 9)
notes(s, "Kit §2. The demo data on the capture devices fits all three: the project Early Cold War, the scopes Berlin "
         "Crises 1958-1963, Cuba 1958-1963 and Soviet Union 1945-1950, the collection The Long Telegram and Its "
         "Readers, and an Archives Visit seeded from it.")


def audience_slide(n, eyebrow, title, frames, also, note, nara=False):
    s = base()
    header(s, eyebrow, title)
    cw = (W - 2 * MARGIN - 0.3) / 2
    for i, (img, head, sub) in enumerate(frames):
        x = MARGIN + i * (cw + 0.3)
        picture(s, img, x, 2.1, w=cw, h=3.15, max_w=1400)
        text(s, x, 5.3, cw, 0.4, head, size=17, bold=True, color=INK, font=HEAD)
        text(s, x, 5.7, cw, 0.75, sub, size=11, color=SUB, line_spacing=1.12)
    text(s, MARGIN, 6.48, W - 2 * MARGIN, 0.45, [[("Also: ", {"bold": True, "color": ACCENT}), (also, {})]],
         size=11, color=INK, line_spacing=1.1)
    footer(s, n, extra=NARA if nara else None)
    notes(s, note)
    return s


# ============ 10. Researchers ============
audience_slide(10, "For researchers", "From footnote to shelf, and the trip planned before you book it", [
    ("Docs/screenshots/ipad/source-explorer.png", "From footnote to shelf",
     "The editors' source note, resolved as far as the bundled reference data reaches: record group, entry, lot file, series dates and the repository that holds it. No network, no API key."),
    ("Docs/screenshots/ipad/trip-packet.png", "Plan the trip before you book it",
     "An Archives Visit turns your documents into research targets with the RG, entry and NAID lines staff ask you to quote, flags restricted series, and drafts the advance inquiry."),
], "Follow what the editors cited: their cross-references around any document, as a timeline or a network, one to three hops out. "
   "Cite as you write: the Department's recommended citation, BibTeX, RIS, or straight into your own Zotero library.",
   "If asked about history.state.gov: the app builds on the Office's TEI editions and links every document back to "
   "its page there. Describe what the app adds (offline search, facets with counts, a working corpus, source-note "
   "resolution, the Archives Visit packet, Zotero), never what the site lacks. The app is free.\n\nSource Explorer starts from the editors' source note (FRUS text) and joins it to the "
   "National Archives catalog where a key is given. Where the records are not at the National Archives it names the "
   "institution that holds them.", nara=True)

# ============ 11. Teachers ============
audience_slide(11, "For teachers", "A course reader in an afternoon, and lecture material before a single download", [
    ("Docs/screenshots/ipad/collections-editor.png", "Build a course reader in an afternoon",
     "Section the collection by week, excerpt the passages discussion will centre on, add a headnote per document, apply the Teaching reader preset, export PDF or Word."),
    ("Docs/screenshots/ipad/series-production.png", "Lecture material before a single download",
     "How late the official record runs against the law that governs it, and three more dashboards on the series itself. They ship inside the app and work offline."),
], "Why raw counts mislead, shown live: chart a term by year in Corpus Analytics, switch to share of documents, and tap into the documents behind the spike. "
   "Most charts export as a CSV with the method stated, and many as a figure.",
   "Objection: 'My students will not install an app.' They need not: the PDF and Word exports stand alone, and Share "
   "Citation sends a plain link. The app is for the teacher; the shareable collection file is for the class that does "
   "install it. The series dashboards and the Research Guide are the methods reading.")

# ============ 12. Analysts ============
audience_slide(12, "For policy analysts", "A crisis day by day, and a question asked in its own words", [
    ("Docs/screenshots/ipad/chronology.png", "A crisis, day by day, across every volume",
     "Chronology lays out every dated document in a window you set, whichever volume printed it, with the volumes that carry the weight named."),
    ("Docs/screenshots/ipad/semantic-search.png", "Ask a question, not a keyword",
     "Search by meaning ranks the whole series by what you asked, with an optional language model that runs on your device. Nothing you type leaves it. Experimental."),
], "Who the record orbits: Person Analytics around any name, the people most often in the same documents, and the trajectories of two rivals across the series. "
   "The Briefing packet preset gives a skimmable read with on-device summaries, authorship on every one.",
   "Objection: 'The series stops decades ago; I work on now.' The series runs to the early 1990s and the newest "
   "volumes to 1988 (vol. XVI of 1981–1988 is the latest in the bundle); the value is precedent, and the dashboards "
   "say exactly how far the record reaches. Never claim currency.\n\nMeaning search needs the optional 310 MB model "
   "(Google's EmbeddingGemma 2); describe, never brand, and keep 'experimental' in frame.")

# ============ 13. On your device ============
s = base()
header(s, "On your device", "The app collects no data, and the work stays yours")
cards = [
    ("Data Not Collected", "The App Store privacy label. No analytics, no tracking, no crash reporter of its own, and no account: the developer runs no server the app reports to."),
    ("Your research syncs through your own iCloud", "Notes, tags, collections and projects live on the device and, if you sign in, in your own iCloud account. Nothing else sees them."),
    ("Two optional connections, each with your own free key", "The National Archives Catalog, so Source Explorer can look up the records a source note cites; and Zotero, to send documents with your tags and notes."),
    ("Summaries on the device", "Apple Intelligence's on-device model, one document at a time or as unattended bulk runs, with authorship recorded on every summary."),
    ("Search by meaning on the device", "An optional 310 MB model turns your question into a vector. Experimental, and nothing you type leaves the device."),
    ("Your index, in your own tools", "On a Mac, Export Research Database saves a checked copy of the index as SQLite, your notes left out unless you say so. A guide explains the schema and its traps."),
]
cw, ch, g = (W - 2 * MARGIN - 0.4) / 3, 2.2, 0.2
for i, (t, b) in enumerate(cards):
    r, c = divmod(i, 3)
    card(s, MARGIN + c * (cw + g), 2.05 + r * (ch + g), cw, ch, t, b, tint=(i == 0), title_size=15, body_size=12,
         body_top=0.95)
footer(s, 13)
notes(s, "Support page and FAQ. Does it need the network? To download volumes, the optional search model and figure "
         "images; and when you ask it to look something up in the NARA Catalog or send to Zotero. Reading, search, "
         "annotation and most archival resolution run on the device.\n\nPrivacy policy: https://frusexplorer.app/privacy.")

# ============ 14. Availability ============
s = base()
header(s, "Availability · coming soon", "Free, in every storefront, English only")
pill(s, W - MARGIN, 0.45, "COMING SOON", right=True)
cols3 = [
    ("Requirements", [
        "Awaiting App Store submission as version 1.0; test builds are on TestFlight.",
        "iPhone or iPad on iOS or iPadOS 26, or a Mac on macOS 26.",
        "Document summaries need Apple Intelligence; on a Mac that means Apple silicon.",
        "The whole series is about 3.3 GB of volumes, with the index about 2.8 times that again. A subseries is a manageable fraction, and volumes can be removed later.",
        "An iCloud account is optional. NARA and Zotero keys are optional.",
    ]),
    ("Where to read more", [
        "Support: frusexplorer.app/support",
        "Privacy policy: frusexplorer.app/privacy",
        "User manuals for iPhone and iPad and for the Mac, linked from Settings › System › About.",
        "The FRUS Research Guide, an introduction to the series itself, inside the app.",
        "Help: help@frusexplorer.app",
    ]),
    ("Source", [
        "The app's code is public under the Apache License 2.0 at github.com/joshbotts/FRUS-Explorer.",
        "An independent project, developed with Claude Code.",
        "The series is in the public domain; the app downloads the Office of the Historian's TEI editions from its public repository.",
    ]),
]
cw, g = (W - 2 * MARGIN - 0.4) / 3, 0.2
for i, (t, items) in enumerate(cols3):
    x = MARGIN + i * (cw + g)
    rect(s, x, 2.05, cw, 4.6, PANEL, line=FRAME, rounded=True, radius=0.04)
    text(s, x + 0.28, 2.3, cw - 0.56, 0.45, t, size=18, bold=True, color=ACCENT, font=HEAD)
    text(s, x + 0.28, 2.85, cw - 0.56, 3.7, items, size=12, color=INK, line_spacing=1.12, para_after=7, bullets=True)
footer(s, 14)
notes(s, "Price and territories confirmed by the owner 2026-10-15: free, every storefront, English only. Version and "
         "build read 'Version 1.0 (1861)' in About.")

# ============ 15. The web edition ============
s = base()
header(s, "The web edition · in development", "FRUS Explorer Light: the same research tools, in a browser")
pill(s, W - MARGIN, 0.45, "IN DEVELOPMENT", right=True)
lw = 6.3
text(s, MARGIN, 2.15, lw, 2.3, [
    "A self-hosted web edition. One container serves the corpus, its full-text index, and each researcher's notes and "
    "highlights to any modern browser, for one person on a laptop or a class or team sharing an instance.",
    "It compiles the app's own Swift files, so the same inputs give the same index rows, the same results in the same "
    "order, and the same document HTML.",
], size=14, color=INK, line_spacing=1.18, para_after=8)
# The architecture strip, from the web repository's README diagram.
by, bh, bw, aw = 4.55, 0.9, 1.75, 0.3
boxes = [("Browser", "TypeScript, React"), ("frus-light server", "Swift 6 on Linux, Hummingbird")]
bx = MARGIN
for i, (t, b) in enumerate(boxes):
    rect(s, bx, by, bw, bh, PANEL, line=FRAME, rounded=True, radius=0.08)
    text(s, bx + 0.12, by + 0.15, bw - 0.24, 0.4, t, size=12, bold=True, color=INK, align=PP_ALIGN.CENTER)
    text(s, bx + 0.12, by + 0.45, bw - 0.24, 0.45, b, size=10, color=SUB, align=PP_ALIGN.CENTER, line_spacing=1.05)
    arrow = s.shapes.add_shape(MSO_SHAPE.RIGHT_ARROW, Inches(bx + bw + 0.08), Inches(by + bh / 2 - 0.12), Inches(aw), Inches(0.24))
    set_fill(arrow, ACCENT); arrow.line.fill.background(); no_shadow(arrow)
    bx += bw + aw + 0.16
sx2 = bx
for j, (t, b) in enumerate([("frus.db", "the corpus index, from a Mac export"), ("app.db", "users and their data")]):
    yy = by - 0.03 + j * 0.5
    rect(s, sx2, yy, 2.0, 0.46, PANEL, line=FRAME, rounded=True, radius=0.1)
    text(s, sx2 + 0.12, yy, 1.76, 0.46, [[(t + "  ", {"bold": True, "color": INK}), (b, {"size": 9})]], size=10,
         color=SUB, anchor=MSO_ANCHOR.MIDDLE, line_spacing=1.0)
text(s, MARGIN, by + bh + 0.12, lw, 0.5,
     "Docker Compose on a Mac or a Linux host, at localhost:8080. A folder of TEI volumes is mounted read-only; the index "
     "is the Mac app's own Export Research Database file.", size=10, italic=True, color=SUB, line_spacing=1.1)
text(s, MARGIN, 6.12, lw, 0.75,
     [[("Light leaves out what depends on Apple-only frameworks: ", {"bold": True, "color": INK}),
       ("on-device summaries, iCloud sync, widgets and Live Activities, Spotlight and native multi-window scenes. "
        "Imported summaries keep their authorship labels, and people can write their own.", {})]],
     size=11, color=SUB, line_spacing=1.12)
rx = MARGIN + lw + 0.3
rw = W - MARGIN - rx
card(s, rx, 2.05, rw, 2.5, "Where it stands", [
    "Phase 1, a Docker Compose install, was signed off on 13 October.",
    "In the browser today: search with the app's query language, facets six ways, the Query Inspector, results by date; "
    "the reader with live links and person and term cards; Browse; Cite with BibTeX and RIS.",
], tint=True, title_size=15, body_size=11, body_top=0.7)
card(s, rx, 4.7, rw, 2.1, "What comes next", [
    "Timeline and concordance readings; notes and highlights with a nightly backup; local accounts and sharing beyond one "
    "machine; search by meaning in a later phase; a managed deployment on AWS as phase 6.",
], title_size=15, body_size=11, body_top=0.7)
footer(s, 15, extra="FRUS Explorer Light is Apache 2.0 at github.com/joshbotts/FRUS-Explorer-Web-App.")
notes(s, "From the web edition's README and plan (joshbotts/FRUS-Explorer-Web-App, read 2026-10-22). Status: early "
         "development. Phase 1 shipped as a Compose install and the owner signed it off on 13 October; sessions 11a to "
         "11e then brought Cite, the facets, the Query Inspector and the date order to the browser app (the last merged "
         "14 October). Session 11f, the timeline and concordance readings, is next. Phase 2 adds user data and its "
         "nightly backup; phase 3 standalone indexing, local accounts and a reverse-proxy recipe for sharing beyond "
         "localhost; AWS returns as phase 6 (one ECS task on Fargate, about $155 to $170 a month). It is designed for a "
         "researcher or a small group, not a public high-traffic site. The web edition compiles the shared kits from a "
         "pinned commit of this repository; its CI renders and indexes fixture volumes on Linux byte-identical to the "
         "Mac. EmbeddingGemma is never bundled with the image.")

# ============ 16. Close ============
s = base(dark=True)
s.shapes.add_picture(str(icon_path), Inches(MARGIN), Inches(1.3), Inches(1.2), Inches(1.2))
text(s, MARGIN, 2.8, 11.5, 1.6,
     "An independent, offline research app for the Foreign Relations of the United States series, built on its editors' annotation.",
     size=30, bold=True, color=DARK_INK, font=HEAD, line_spacing=1.1)
text(s, MARGIN, 4.55, 11.5, 0.5, "Coming soon for iPhone, iPad and Mac. Free. A web edition is in development.", size=20, color=DARK_SUB)
text(s, MARGIN, 5.35, 11.5, 0.9, ["help@frusexplorer.app · frusexplorer.app/support · github.com/joshbotts/FRUS-Explorer"],
     size=13, color=DARK_ACCENT, line_spacing=1.3)
footer(s, 16, dark=True)
notes(s, "The one-line press description (kit §5.4), under 200 characters. Every asset that names the Office of the "
         "Historian carries the not-an-official-product sentence.")

def register_notes_master(prs):
    """python-pptx relates the notes master to the presentation but never lists it in
    <p:notesMasterIdLst>; PowerPoint tolerates that, Keynote refuses the file."""
    from pptx.opc.constants import RELATIONSHIP_TYPE as RT
    pres = prs.part._element
    if pres.find(qn("p:notesMasterIdLst")) is not None:
        return
    rId = None
    for rel in prs.part.rels.values():
        if rel.reltype == RT.NOTES_MASTER:
            rId = rel.rId
    if rId is None:
        return
    lst = pres.makeelement(qn("p:notesMasterIdLst"), {})
    el = lst.makeelement(qn("p:notesMasterId"), {qn("r:id"): rId})
    lst.append(el)
    pres.find(qn("p:sldMasterIdLst")).addnext(lst)


register_notes_master(prs)
prs.save(str(OUT))
print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB,", len(prs.slides), "slides")
