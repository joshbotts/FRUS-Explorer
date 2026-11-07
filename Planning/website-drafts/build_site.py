#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Writes a local preview of frusexplorer.app for review (plan of record decision 101).

Nothing here is published, and nothing is a copy of record. The preview puts every page the site
is to carry in one shell standing in for Squarespace's (header, nav, footer), with a review bar on
top that switches between the coming-soon and launch versions and shows or hides review notes:

    site/index.html             Home             from site-src/home.html
    site/tour.html              Tour             from tour/tour.html (images from tour/img/)
    site/quick-start-ios.html   Quick start      from Docs/iOS-Quick-Start.md
    site/quick-start-mac.html   Quick start      from Docs/macOS-Quick-Start.md
    site/support.html           Support          from Support-draft.md (the plain-language draft)
    site/privacy.html           Privacy          from Privacy-Policy-draft.md (the same)
    site/review.html            The review sheet: figures recounted from the bundle, screens
                                set against the current captures, and the owner's open calls

Support, Privacy and the quick starts are rendered by Scripts/build_website_pages.py's own `body()`,
so their text is what that script would paste. Two things differ from a paste, for viewing offline:
links between the site's pages go to the files here, and the quick starts' screenshots load from
Docs/screenshots/ in this checkout rather than from raw.githubusercontent.com.

The figures in review.html are recomputed on every run from FRUSExplorer/Resources, and each is
looked for in the pages' text, so a revision that changes a number shows there.

Stdlib only. Run from anywhere:
    python3 Planning/website-drafts/build_site.py           # build once
    python3 Planning/website-drafts/build_site.py --watch   # rebuild on every save
then serve the repository root (python3 -m http.server 8765) and open
http://localhost:8765/Planning/website-drafts/site/index.html. While --watch runs, each rebuild writes
site/build-stamp.txt, and every open page, which reads it once a second through reload.js, reloads.
"""

import datetime
import html
import importlib.util
import json
import re
import subprocess
import sys
import time
import traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SRC = HERE / "site-src"
OUT = HERE / "site"
RES = REPO / "FRUSExplorer" / "Resources"

_spec = importlib.util.spec_from_file_location("bwp", REPO / "Scripts" / "build_website_pages.py")
bwp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bwp)

# The site's pages, in nav order. `nav` is the label in the header; None keeps a page out of it.
PAGES = [
    ("index.html", "Home", None),
    ("tour.html", "Tour", "Tour"),
    ("quick-start-ios.html", "Quick Start", "Quick Start"),
    ("support.html", "Support", "Support"),
    ("privacy.html", "Privacy", "Privacy"),
]
# The live addresses the Markdown names, and the preview file each becomes here.
LOCAL = {
    "https://frusexplorer.app/privacy": "privacy.html",
    "https://frusexplorer.app/support": "support.html",
    "https://frusexplorer.app/quick-start-ios": "quick-start-ios.html",
    "https://frusexplorer.app/quick-start-mac": "quick-start-mac.html",
}
DISCLAIMER = (
    "FRUS Explorer is an independent, private-capacity research tool. It is not an official "
    "product of the Office of the Historian or the U.S. Department of State. Any commentary, "
    "advice, or guidance about the FRUS series in this app reflects personal views about "
    "historical research methodology and makes no interpretive claims about the history of U.S. "
    "foreign policy. Those views are not necessarily those of the Department of State or the U.S. "
    "Government. The FRUS series itself is in the public domain.")
NARA = ("FRUS Explorer is not affiliated with, endorsed by, or sponsored by the National Archives "
        "and Records Administration.")

SHELL = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{title}</title>
<meta name="robots" content="noindex">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,600;0,8..60,700;1,8..60,400&display=swap">
<link rel="stylesheet" href="site.css">
</head>
<body data-state="soon">
{bar}
<header class="site-head"><div class="inner">
  <a class="brand" href="index.html"><img src="../tour/img/icon.png" alt="">FRUS Explorer</a>
  <nav class="site-nav" aria-label="Site">{nav}</nav>
</div></header>
<div class="soon-strip" data-show="soon"><div class="inner"><b>Coming soon</b><span>FRUS Explorer has been submitted to the App Store for iPhone, iPad and Mac.</span></div></div>
<main class="site-main"><div class="inner">
{body}
</div></main>
<footer class="site-foot"><div class="inner">
  <p>{disclaimer}</p>
  <p>{nara}</p>
  <nav aria-label="Footer"><a href="support.html">Support</a><a href="privacy.html">Privacy</a><a href="tour.html">Tour</a><a href="quick-start-ios.html">Quick start</a><a href="https://github.com/joshbotts/FRUS-Explorer">Source code</a></nav>
</div></footer>
<script src="site.js"></script>
<script src="reload.js"></script>
</body>
</html>
"""

BAR = """<div class="review-bar" role="region" aria-label="Review controls (not part of the site)"><div class="inner">
  <span><b>Review copy</b>, not published · built {built}</span>
  <span class="seg" role="group" aria-label="Page version">
    <button type="button" data-state-btn="soon" aria-pressed="true">Coming soon</button>
    <button type="button" data-state-btn="launch" aria-pressed="false">At launch</button>
  </span>
  <button class="tgl" id="notes-btn" type="button" aria-pressed="true">Review notes: on</button>
  <span class="sp"><a href="review.html">Review sheet</a></span>
</div></div>"""


def git_short():
    try:
        return subprocess.run(["git", "-C", str(REPO), "rev-parse", "--short", "HEAD"],
                              capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        return "?"


BUILT = "{} at {}".format(datetime.date.today().isoformat(), git_short())


def nav_html(current):
    out = []
    for file, _, label in PAGES:
        if not label:
            continue
        here = current == file or (file.startswith("quick-start") and current.startswith("quick-start"))
        out.append('<a href="{}"{}>{}</a>'.format(file, ' aria-current="page"' if here else "", label))
    return "".join(out)


def localize(text):
    """Points the live addresses at this preview's files, and the GitHub screenshots at this
    checkout's, so the preview reads offline and shows captures not yet merged."""
    for live, local in LOCAL.items():
        text = text.replace('href="{}'.format(live), 'href="{}'.format(local))
    return text.replace(bwp.GITHUB_RAW, "../../../")


def note(title, items):
    lis = "\n".join("    <li>{}</li>".format(i) for i in items)
    return ('<aside class="rv" data-rv>\n  <p class="rv-h">Review note · {}</p>\n  <ul>\n{}\n  </ul>\n'
            '</aside>\n'.format(html.escape(title), lis))


def page(file, title, body):
    text = SHELL.format(title=html.escape(title), bar=BAR.format(built=BUILT), nav=nav_html(file),
                        body=body, disclaimer=DISCLAIMER, nara=NARA)
    (OUT / file).write_text(text, encoding="utf-8")
    return text


def markdown_page(source, extra_class=""):
    path = REPO / source
    return '<article class="doc{}">\n{}\n</article>'.format(
        extra_class, localize(bwp.body(path.read_text(encoding="utf-8"), source)))


# ---- The tour: its own stylesheet and script, with the site's links and a review note added.

def build_tour():
    t = (HERE / "tour" / "tour.html").read_text(encoding="utf-8")
    t = t.replace('src="img/', 'src="../tour/img/').replace('poster="img/', 'poster="../tour/img/')
    manual = ('<a href="https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/iOS-User-Manual.md" '
              'target="_blank" rel="noopener">Read the manual</a>')
    t = t.replace(manual, '<span>Quick start: <a href="quick-start-ios.html">iPad and iPhone</a> · '
                          '<a href="quick-start-mac.html">Mac</a></span>')
    t = t.replace('<a class="btn" href="https://frusexplorer.app" target="_blank" rel="noopener">',
                  '<a class="btn" href="index.html">')
    t = t.replace('href="https://frusexplorer.app/support" target="_blank" rel="noopener"',
                  'href="support.html"')
    # The site's pages, in the tour's own draft bar, and the review sheet.
    site_links = ('<span style="margin-left:auto;display:flex;flex-wrap:wrap;gap:4px 14px">'
                  '<a href="index.html">Home</a><a href="quick-start-ios.html">Quick Start</a>'
                  '<a href="support.html">Support</a><a href="privacy.html">Privacy</a>'
                  '<a href="review.html"><b>Review sheet</b></a></span>')
    t = re.sub(r'(<button class="toggle" id="new-toggle"[^<]*</button>)', r"\1\n    " + site_links, t, 1)
    t = t.replace("<b>Draft preview.</b>", "<b>Review copy</b>, not published · built {} ·".format(BUILT))
    rv_css = ('<style>.preview a{color:var(--note-ink)} .rv{font-family:var(--sans);font-size:14px;'
              'line-height:1.55;color:var(--note-ink);background:var(--note-bg);border:1px dashed '
              'var(--note-line);border-radius:6px;padding:12px 16px;margin:28px 0 0}.rv-h{font-weight:600;'
              'font-size:12px;letter-spacing:.1em;text-transform:uppercase;margin-bottom:6px}.rv ul{margin:0;'
              'padding-left:1.2em;display:grid;gap:4px}.rv a{color:var(--note-ink)}'
              'body.hide-notes [data-rv]{display:none!important}</style>\n')
    t = t.replace("<script>document.body", rv_css + "<script>document.body", 1)
    rv = note("Tour", [
        "<b>Source:</b> <code>Planning/website-drafts/tour/tour.html</code> (2026-10-27). Its closing section "
        "points to the quick starts and this site's pages.",
        "<b>Revised 2026-11-03:</b> all seventeen screens re-cropped from the build-1861 captures, and their "
        "captions, alt text and production notes brought to them. The review sheet sets each beside the crop it replaced.",
        "<b>Figures:</b> 553, 264,598 in 502 volumes, 8,637 and 314,616 all recount the same from the "
        "bundle. The counts inside captions (13,177; 9,114; 1,154; 1,000 of 11,122; 900; 103) are read off their screens.",
        "<b>Part 0 now shows the Marshall–Stalin meeting</b> (<code>frus1947v02/d127</code>, 15 April 1947), chosen "
        "after PPS 37 and five other candidates. Six kinds are its own; footnote 61's early draft, filed separately, stands "
        "for what wasn't printed, and G is the editorial note listing the conference's delegations (<code>d78</code>). "
        "No Marshall document of spring 1947 carries all seven kinds.",
        "<b>Still owed:</b> captures for steps 19 and 20 and a Cite capture to replace step 15's text slip if wanted. Steps 14 and 18 gained screens on 2026-11-06, and step 13 the map film, re-rendered from build 51's layout.",
        "Production notes under each step stay visible with the tour's own <b>Notes</b> switch.",
    ])
    t = t.replace("<main>", "<main>\n<div class=\"inner\">" + rv + "</div>", 1)
    t = t.replace("</body>", '<script src="reload.js"></script>\n</body>', 1) if "</body>" in t \
        else t + '\n<script src="reload.js"></script>\n'
    (OUT / "tour.html").write_text(t, encoding="utf-8")
    return t


# ---- The figures, recounted from the bundle

def figures():
    manifest = json.loads((RES / "manifest.json").read_text())
    usage = json.loads((RES / "collection-usage-index.json").read_text())["coverage"]
    edges = json.loads((RES / "resolved-edge-index.json").read_text())["coverage"]
    smap = json.loads((RES / "semantic-map-index.json").read_text())
    vectors = json.loads((RES / "semantic-vectors-index.json").read_text())
    gb = sum(v.get("sizeBytes") or 0 for v in manifest) / 1e9
    cross = edges["documentEdges"] - edges["sameVolumeEdges"]
    hub = (REPO / "FRUSExplorer/Settings/MacVolumesStorageHub.swift").read_text()
    ratio = "2.8" if "roughly 2.8× that in search index" in hub else "?"
    return [
        ("Volumes in the catalogue", "553", "{:,}".format(len(manifest)),
         "<code>manifest.json</code>, entries"),
        ("Corpus size", "about 3.3 GB", "{:.2f} GB".format(gb),
         "<code>manifest.json</code>, <code>sizeBytes</code> summed"),
        ("Index, against the volumes", "about 2.8 times", ratio + "×",
         "the app's own estimate, <code>MacVolumesStorageHub</code>; not a measurement"),
        ("Source notes paired with a document", "264,598", "{:,}".format(usage["noteCount"]),
         "<code>collection-usage-index.json</code>, <code>coverage.noteCount</code>"),
        ("Volumes with source notes", "502", "{:,}".format(usage["volumesWithNotes"]),
         "the same, <code>volumesWithNotes</code>"),
        ("Cross-references between volumes", "8,637", "{:,}".format(cross),
         "<code>resolved-edge-index.json</code>: {:,} document edges less {:,} within a volume".format(
             edges["documentEdges"], edges["sameVolumeEdges"])),
        ("Documents on the semantic map", "314,616", "{:,}".format(smap["documentCount"]),
         "<code>semantic-map-index.json</code>; <code>semantic-vectors-index.json</code> reads {:,}".format(
             vectors["documentCount"])),
        ("Map regions (not stated on a page)", "—", "{:,}".format(len(smap["clusters"])),
         "<code>semantic-map-index.json</code>, <code>clusters</code>; for the map's retake"),
    ]


def plain(text):
    text = re.sub(r"<style.*?</style>|<script.*?</script>", "", text, flags=re.S)
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", text)))


# ---- Screens: each tour crop, re-cut on 2026-11-03 from the build-1861 capture in Docs/screenshots/,
# beside the build 47-48 crop it replaced (kept in tour/img-builds-47-48/), with what the caption now says.

SCREENS = [
    (1, "search.jpg", "macos/search.png", "899 matches became 900. Re-cut 2026-11-06 from the screens-1861 retake (#1865): 1948–49 rows now carry classification chips (#1853, #1857)."),
    (2, "meaning.jpg", "ipad/semantic-search.png",
     "Now the project's own question under EmbeddingGemma 2, not “free and fair elections”; its re-shoot note removed. Re-cut 2026-11-06 from the screens-1861 retake (#1865): index v74."),
    (3, "truman.jpg", "ipad/browse-administrations-truman.png", "“Largest share first” became “most documents first”, as the screen says. Re-cut 2026-11-06 from the screens-1861 retake (#1865): the Browse root now shows the Editors’ Annotations door."),
    (4, "related.jpg", "ipad/related-documents.png", "Now Kennan's Long Telegram, not a Yalta document."),
    (5, "people.jpg", "ipad/people-detail.png",
     "13,174 became 13,177 documents and Active 1923–2015 became 1961–1988 (#1370, #1441); its re-shoot note removed. The entry is now a sheet over the People list. Re-cut on 2026-11-04 from the retake for the people source's new label, “FRUS + OH people data” (#1849, #1850). Re-cut 2026-11-06 from the screens-1861 retake (#1865): same sheet; the People list behind it now has the 288-volume line."),
    (6, "rail.jpg", "ipad/research-rail.png", "The tag is Containment, not Cold War Origins; the rail shows no summary yet, which the prose does not claim."),
    (7, "research.jpg", "macos/research.png", "One highlight, not two; eight documents."),
    (8, "browse.jpg", "ipad/browse-working-corpora.png",
     "Now the Early Cold War project's three searches (1,000 of 11,122 matches saved), not another project's map selections. Re-cut 2026-11-06 from the screens-1861 retake (#1865): the Browse column moved for the new door."),
    (9, "source.jpg", "ipad/source-explorer.png", "Same record; only the build in the caption. Re-cut 2026-11-06 from the screens-1861 retake (#1865): the source note now shows its Top Secret marking."),
    (9, "packet.jpg", "ipad/trip-packet.png", "Same plan, now shown as the sheet over Research."),
    (10, "analytics.jpg", "ipad/analytics.png", "Same four terms; only the build in the caption."),
    (11, "chronology.jpg", "ipad/chronology.png", "The retired editorial-notes line is gone (#1422); its re-shoot note removed."),
    (12, "graph.jpg", "ipad/cross-reference-graph.png",
     "Now document 16 of frus1952-54v02p1, after #1438, #1481 and #1764, not document 149 of frus1964-68v19; its re-shoot note removed."),
    (13, "map.jpg", "ipad/semantic-map.png", "Build 51's layout and 140 regions. The map film beside it was re-rendered from the same layout on 2026-11-06."),
    (14, "lag.jpg", "ipad/series-production.png", "Same chart, now as the sheet over Research."),
    (14, "annotations.jpg", "ipad/browse-annotations.png", "New on 2026-11-06 for 1.0’s Editors’ Annotations (#1859–#1862), from the screens-1861 sitting (#1865): the matrix pane, header cut."),
    (16, "reader.jpg", "ipad/collections-editor.png", "The preview now opens on the collection's title page and contents."),
    (17, "table.jpg", "macos/analytics-table.png",
     "9,162 documents across 502 volumes became 9,114 across 267: the capture's Mac held 267 volumes."),
    (18, "history.jpg", "ipad/research-history.png", "New on 2026-11-06 from the screens-1861 sitting (#1865): Research ▸ History's right pane, with the slip kept below it."),
]


# This worktree's branch can lag v2, where #1865's captures landed; date from whichever is newer.
SCREENS_BRANCH = "refs/remotes/origin/v2"


def capture_date(rel):
    dates = []
    for ref in ("HEAD", SCREENS_BRANCH):
        try:
            out = subprocess.run(["git", "-C", str(REPO), "log", "-1", "--format=%ad", "--date=short", ref, "--",
                                  "Docs/screenshots/" + rel], capture_output=True, text=True).stdout.strip()
        except Exception:
            out = ""
        if out:
            dates.append(out + ("" if ref == "HEAD" else " on v2"))
    return max(dates) if dates else "uncommitted"


def build_review(texts):
    allt = {k: plain(v) for k, v in texts.items()}
    rows = []
    for name, stated, recount, source in figures():
        bare = stated.replace("about ", "").replace(" times", "").replace(" GB", "")
        where = [k for k, v in allt.items() if bare != "—" and bare in v]
        same = (stated == "—") or (bare.replace(",", "") in recount.replace(",", "").replace("×", "")) or \
            (stated.endswith("GB") and recount.startswith(bare))
        status = ('<span class="st ok">matches</span>' if same and stated != "—" else
                  '<span class="st warn">for reference</span>' if stated == "—" else
                  '<span class="st bad">differs</span>')
        rows.append("<tr><td>{}</td><td class=num>{}</td><td class=num>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>"
                    .format(name, stated, recount, ", ".join(where) or "—", source, status))
    shots = []
    for step, crop, cap, change in SCREENS:
        before = ("<figure><img src=\"../tour/img-builds-47-48/{0}\" alt=\"\" loading=lazy>"
                  "<figcaption>before: builds 47–48</figcaption></figure>".format(crop)
                  if (HERE / "tour" / "img-builds-47-48" / crop).exists() else
                  "<figure><figcaption>before: none, a new screen</figcaption></figure>")
        shots.append(
            "<tr><td class=num>{}</td><td><div class=shots>{}<figure><img src=\"../tour/img/{}\" alt=\"\" loading=lazy>"
            "<figcaption>now: from <code>{}</code>, committed {}</figcaption></figure></div></td><td>{}</td></tr>".format(
                step, before, crop, cap, capture_date(cap), change))
    for step, what in [(19, "Citation Lookup with a pasted chapter of notes"),
                       (20, "Review… on a corrected volume's highlights")]:
        shots.append("<tr><td class=num>{}</td><td>No capture yet: {}.</td><td>Capture from the submitted "
                     "build; Docs/screenshots has nothing for it.</td></tr>".format(step, what))
    body = REVIEW.format(built=BUILT, figures="\n".join(rows), shots="\n".join(shots))
    page("review.html", "Website review sheet", body)


REVIEW = """<div class="sheet">
<p class="mono" style="color:var(--muted)">frusexplorer.app · review sheet · built {built}</p>
<h1>The website, generated for review</h1>
<p class="lead">Every page the site is to carry, in one local preview with a stand-in for Squarespace's header and footer. Use the bar at the top to switch between the coming-soon and launch versions and to hide these notes. Nothing here is published.</p>

<section>
<h2><span class="n">1</span>The pages</h2>
<div class="pages">
  <a href="index.html"><b>Home</b><span>frusexplorer.app/ · from site-src/home.html</span></a>
  <a href="tour.html"><b>Tour</b><span>/tour · from tour/tour.html</span></a>
  <a href="quick-start-ios.html"><b>Quick start, iPad and iPhone</b><span>/quick-start-ios · Docs/iOS-Quick-Start.md</span></a>
  <a href="quick-start-mac.html"><b>Quick start, Mac</b><span>/quick-start-mac · Docs/macOS-Quick-Start.md</span></a>
  <a href="support.html"><b>Support</b><span>/support · Support-draft.md</span></a>
  <a href="privacy.html"><b>Privacy</b><span>/privacy · Privacy-Policy-draft.md</span></a>
</div>
<p class="sub">To revise: edit the source named on each card (for a quick start, the Markdown in <code>Docs/</code>), then run <code>python3 Planning/website-drafts/build_site.py</code> and reload.</p>
</section>

<section>
<h2><span class="n">2</span>Figures, recounted from the bundle</h2>
<p class="sub">Recomputed from <code>FRUSExplorer/Resources</code> on every build; “Pages” lists where the stated figure appears.</p>
<div class="tw"><table>
<thead><tr><th>Figure</th><th>Stated</th><th>Recount</th><th>Pages</th><th>Source</th><th>Status</th></tr></thead>
<tbody>
{figures}
</tbody></table></div>
</section>

<section>
<h2><span class="n">3</span>Screens in the tour</h2>
<p class="sub">Re-cropped on 2026-11-03 from the build-1861 captures in <code>Docs/screenshots/</code>, each at its old crop's width and framing, with its caption and alt text re-read against the new screen. The old crops are kept in <code>tour/img-builds-47-48/</code> for this comparison.</p>
<div class="tw"><table>
<thead><tr><th>Step</th><th>Before · now</th><th>What the caption now says</th></tr></thead>
<tbody>
{shots}
</tbody></table></div>
</section>

<section>
<h2><span class="n">4</span>What this pass changed</h2>
<ul class="plain">
  <li><b>Support draft:</b> the two quick-start links and their sentences, which the copy of record took in #1847 and #1848 after the draft, folded in plain language. Its other claims are the copy of record's.</li>
  <li><b>Privacy draft:</b> unchanged. <code>Docs/Privacy-Policy.md</code> has not moved since the draft's base, <code>1c18b51</code>.</li>
  <li><b>Home:</b> the hero, the closing section and a new “Where do I start?” answer point to the quick starts; links go to the site's own pages.</li>
  <li><b>Tour:</b> its closing links point to the quick starts and this site's pages; all seventeen screens re-cropped from build 1861, with their captions, alt text and production notes brought to the new screens (section 3); Part 0's specimen is now the record of Marshall's meeting with Stalin, 15 April 1947; and the tour no longer claims an Office “register of people”: it says the editors point each tagged name to the volume's own list of persons, and names the HistoryAtState/people repository as a partial foundation where the People step cites it.</li>
  <li><b>Editors’ Annotations, 2026-11-06, later:</b> the pages describe 1.0's new Editors’ Annotations (#1859–#1863), the People list's 288-of-553 line (#1851, #1862) and the classification markings now shown in Search and Source Explorer (#1853, #1857). The tour's figures row gains a fourth figure, 288. The proposals are in <code>Revisions-proposed-2026-11-06.md</code>, and the owner's last edits to them are folded in. On the same day the screens-1861 sitting retook the captures behind steps 1, 2, 3, 5, 8 and 9 (chips, the Browse door, the 288-volume line), and step 14 gained the Editors’ Annotations matrix and step 18 Research ▸ History; the captures merged in #1865.</li>
  <li><b>Owner's revisions, 2026-11-06:</b> both pages rewritten from the owner's Markdown copies (<code>Home-draft.md</code>, <code>Tour-draft.md</code>): the tour's step titles, Part 0's introduction and notes, the source labels' wording, and steps 6, 9, 16 and 18 restructured. Each new claim was checked against the manuals and the corpus (287 of 553 volumes tag people). Typos fixed; two claims corrected: a cross-reference to a volume not on the device offers the download rather than starting it, and Part II's privacy line names the app, since Apple can pass opted-in analytics to the developer.</li>
  <li><b>Quick starts:</b> as <code>Docs/Website/</code> renders them, unchanged.</li>
</ul>
</section>

<section>
<h2><span class="n">5</span>Checked against the launch kit's §6</h2>
<ul class="plain">
  <li>Every page carries the not-an-official-product sentence and the full disclaimer in the footer; Support also opens with it.</li>
  <li>Every page names the National Archives only with the not-affiliated sentence in the same footer.</li>
  <li>The map (tour step 13) is labelled Experimental, says far distances mean nothing, and is marked as made by the app.</li>
  <li>Meaning search is described, never branded, and called experimental on Home, Support and the tour.</li>
  <li>history.state.gov appears only as the Office's own edition, in the tour's Cite step and Citation Lookup step; no comparison.</li>
  <li>FRUS Explorer Light is named nowhere.</li>
  <li>Counts are §9 figures, with “about” where the kit has it.</li>
</ul>
</section>

<section>
<h2><span class="n">6</span>Your calls</h2>
<ol class="calls">
  <li><b>The quick-start addresses.</b> <code>/quick-start-ios</code> and <code>/quick-start-mac</code> are still proposals (<code>Docs/Website/README.md</code>).</li>
  <li><b>“Coming soon to the App Store” and “will be free”</b> on Home and the tour assume approval; App Review decides.</li>
  <li><b>Home and the tour as copies of record</b>, under <code>Docs/Website/</code> with a trace per factual sentence, or drafts here.</li>
  <li><b>Folding the Support and Privacy drafts</b> into <code>Docs/</code>: then <code>Scripts/build_website_pages.py</code>, its <code>--check</code>, and the TEI sentence's row in the README.</li>
  <li><b>The tour's remaining screens</b>: steps 18 to 20 have no capture, and step 15 is a text slip.</li>
</ol>
</section>
</div>"""


def build():
    global BUILT
    BUILT = "{} at {}".format(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), git_short())
    OUT.mkdir(exist_ok=True)
    for name in ("site.css", "site.js", "reload.js"):
        (OUT / name).write_text((SRC / name).read_text(encoding="utf-8"), encoding="utf-8")
    texts = {}
    home = re.sub(r"<!--.*?-->\s*", "", (SRC / "home.html").read_text(encoding="utf-8"), count=1, flags=re.S)
    texts["Home"] = page("index.html", "FRUS Explorer", home)
    texts["Tour"] = build_tour()
    for file, source, title, other, label in [
            ("quick-start-ios.html", "Docs/iOS-Quick-Start.md", "FRUS Explorer for iPad and iPhone — Quick Start",
             "quick-start-mac.html", "iPad and iPhone"),
            ("quick-start-mac.html", "Docs/macOS-Quick-Start.md", "FRUS Explorer for macOS — Quick Start",
             "quick-start-ios.html", "Mac")]:
        ios_first = file == "quick-start-ios.html"
        switch = ('<nav class="qs-switch" aria-label="Platform"><a href="quick-start-ios.html"{}>iPad and iPhone</a>'
                  '<a href="quick-start-mac.html"{}>Mac</a></nav>').format(
                      ' aria-current="page"' if ios_first else "", "" if ios_first else ' aria-current="page"')
        rv = note("Quick start, " + label, [
            "<b>Source:</b> <code>{}</code>, the copy of record, rendered by <code>Scripts/build_website_pages.py</code>; "
            "<code>Docs/Website/{}</code> is its paste.".format(source, file),
            "Here the screenshots load from this checkout. Published, they load from GitHub at the default "
            "branch's head, so the repository must stay public.",
            "The platform switch above the title belongs to this preview; the paste has none. Worth adding to "
            "the site as two links?",
        ])
        body = rv + switch + "\n" + bwp.GUIDE_STYLE + "\n" + markdown_page(source, " wide frus-quick-start")
        texts["Quick start, " + label] = page(file, title, body)
    texts["Support"] = page("support.html", "FRUS Explorer Support", note("Support", [
        "<b>Source:</b> <code>Planning/website-drafts/Support-draft.md</code>, the plain-language draft "
        "(grade 6.9 against the copy of record's 8.1).",
        "<b>Revised 2026-11-03:</b> the quick starts' links and sentences folded in from the copy of record.",
        "The <b>Coming soon</b> paragraph is in the Markdown itself; it comes out on release day, so it shows "
        "in both versions of this preview.",
        "One sentence is new against the copy of record: what TEI is. It needs a row in "
        "<code>Docs/Website/README.md</code>.",
    ]) + markdown_page("Planning/website-drafts/Support-draft.md"))
    texts["Privacy"] = page("privacy.html", "FRUS Explorer Privacy Policy", note("Privacy", [
        "<b>Source:</b> <code>Planning/website-drafts/Privacy-Policy-draft.md</code>, the plain-language draft "
        "(grade 8.5 against 9.7).",
        "The copy of record has not changed since the draft's base, so every claim is still traced in "
        "<code>Docs/Website/README.md</code>.",
    ]) + markdown_page("Planning/website-drafts/Privacy-Policy-draft.md"))
    build_review(texts)
    (OUT / "build-stamp.txt").write_text(str(time.time_ns()), encoding="utf-8")


# The files a build reads. A change to any of them rebuilds; a change to this script or to
# Scripts/build_website_pages.py needs --watch restarted, since the running code is already loaded.
def sources():
    files = [HERE / "Support-draft.md", HERE / "Privacy-Policy-draft.md", HERE / "tour" / "tour.html",
             REPO / "Docs" / "iOS-Quick-Start.md", REPO / "Docs" / "macOS-Quick-Start.md"]
    files += sorted(SRC.glob("*")) + sorted((HERE / "tour" / "img").glob("*"))
    return files


def stamp():
    out = {}
    for f in sources():
        try:
            out[f] = f.stat().st_mtime_ns
        except OSError:
            out[f] = None
    return out


def watch():
    code = {Path(__file__).resolve(): None, REPO / "Scripts" / "build_website_pages.py": None}
    code = {f: f.stat().st_mtime_ns for f in code}
    build()
    print("built {}; watching {} files (Ctrl-C to stop)".format(BUILT, len(sources())), flush=True)
    seen = stamp()
    while True:
        time.sleep(0.6)
        now = stamp()
        if now != seen:
            changed = [f for f in now if now[f] != seen.get(f)] + [f for f in seen if f not in now]
            time.sleep(0.2)  # let an editor finish writing
            seen = stamp()
            try:
                build()
                print("rebuilt {} ({})".format(BUILT, ", ".join(f.name for f in changed[:4])), flush=True)
            except Exception:
                traceback.print_exc()
                print("build failed; the preview keeps the last good pages. Still watching.", flush=True)
        if any(f.stat().st_mtime_ns != m for f, m in code.items()):
            print("the build code itself changed: restart --watch to use it", flush=True)
            code = {f: f.stat().st_mtime_ns for f in code}


def main():
    if "--watch" in sys.argv[1:]:
        try:
            watch()
        except KeyboardInterrupt:
            print("stopped")
        return
    build()
    for f in sorted(OUT.iterdir()):
        print("wrote", f.relative_to(REPO))


if __name__ == "__main__":
    main()
