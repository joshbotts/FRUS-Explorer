#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Writes the domain's copies of the Privacy Policy, Support and quick-start pages from their
GitHub copies.

Plan of record decision 36 keeps each page in two copies, in step: the Markdown on GitHub
(`Docs/Privacy-Policy.md`, `Docs/Support.md`) and the HTML on frusexplorer.app
(`Docs/Website/privacy.html`, `Docs/Website/support.html`). The two quick starts
(`Docs/iOS-Quick-Start.md`, `Docs/macOS-Quick-Start.md`) are kept the same way, in
`Docs/Website/quick-start-ios.html` and `Docs/Website/quick-start-mac.html`. The Markdown is the
one edited; this script writes the HTML from it, so the two say the same thing word for word.
`--check` writes nothing and fails when an HTML file is not what the Markdown would make, which
is the state a hand edit to one copy leaves.

It reads only the Markdown those pages use: `#` and `##` headings, paragraphs, `- ` and `1. `
lists, one-line `> ` blockquotes, `---`, `|` tables, a line holding only an image (`![alt](path)`,
or `<img>` tags with `src`, `width` and `alt`), and inline `**bold**`, `*italic*`, `` `code` ``,
`[text](url)` and `<url>`. Anything else passes through as text, so a new construct shows up in
the review of the HTML diff rather than silently.

A relative link names a file under `Docs/`: it becomes that file's page here when it has one,
and its GitHub copy otherwise. An image becomes the same file on raw.githubusercontent.com, at
the default branch's head, so the published page shows the repository's current capture.

Stdlib only, macOS's bundled python3 (3.9), no pip.

Usage:
    python3 Scripts/build_website_pages.py           # rewrite every HTML file
    python3 Scripts/build_website_pages.py --check   # exit 1 if any is out of step
"""

import html
import posixpath
import re
import struct
import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parent.parent

# The two mailboxes the owner named on 2026-10-18 (plan of record decision 26): help@ for the
# Support page and the policy's questions, feedback@ for Semantic Match Feedback's file, which the
# app's mail draft addresses (`SemanticFeedbackMail.address`). The HTML makes each a mailto link.
ADDRESSES = ("help@frusexplorer.app", "feedback@frusexplorer.app")

# Where a relative link to a repository file without a page here goes: its GitHub copy, the form
# `AboutLinks` uses for the manuals (`HEAD` follows the default branch).
GITHUB_BLOB = "https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/"

# Where an image loads from: the repository's own file, at the default branch's head.
GITHUB_RAW = "https://raw.githubusercontent.com/joshbotts/FRUS-Explorer/HEAD/"

# The Privacy Policy's and Support page's header comment, which their HTML has carried since
# decision 36.
POLICY_COMMENT = """\
  One of two copies kept in step (plan of record decision 36). Its twin, on GitHub, is
  {source}. This copy is published at {url},
  the address App Store Connect names. Do not edit it: edit the twin and run
  Scripts/build_website_pages.py, which writes this file. Docs/Website/README.md has the rest.

  To publish on the Squarespace site, paste everything between <main> and </main> into a Code
  Block on a page whose URL slug is {slug}; the site's own type and colours then apply, and the
  <style> below, which is only for viewing this file on its own, is left behind."""

# A quick start's: the same arrangement, plus the <style> it carries inside <main> and the
# screenshots it loads from GitHub.
GUIDE_COMMENT = """\
  One of two copies kept in step, as the Privacy Policy and Support pages are (plan of record
  decision 36). Its twin, on GitHub, is {source}; this copy is for
  {url}. Do not edit it: edit the twin and run
  Scripts/build_website_pages.py, which writes this file. Docs/Website/README.md has the rest.

  To publish on the Squarespace site, paste everything between <main> and </main> into a Code
  Block on a page whose URL slug is {slug}. The <style> at the top of <main> goes with
  it: it sizes the screenshots and rules the tables, and leaves type and colour to the site. The
  screenshots load from the repository on GitHub, so a retaken capture shows here without a new
  paste. The <style> in <head>, which is only for viewing this file on its own, is left behind."""

# Pasted with a quick start's contents; every rule is scoped to the wrapper it opens.
GUIDE_STYLE = """\
<style>
  .frus-quick-start img { max-width: 100%; height: auto; }
  .frus-quick-start .shots img { margin: 0 0.75rem 0.5rem 0; vertical-align: top; }
  .frus-quick-start table { border-collapse: collapse; margin: 1rem 0; width: 100%; }
  .frus-quick-start th, .frus-quick-start td {
    border: 1px solid rgba(128, 128, 128, 0.35);
    padding: 0.4rem 0.6rem;
    text-align: left;
    vertical-align: top;
  }
</style>"""

PAGES = [
    dict(source="Docs/Privacy-Policy.md", target="Docs/Website/privacy.html",
         url="https://frusexplorer.app/privacy", slug="privacy",
         title="FRUS Explorer Privacy Policy",
         description="FRUS Explorer collects no data. What the app keeps, where it keeps it, "
                     "and every place it connects to.",
         comment=POLICY_COMMENT),
    dict(source="Docs/Support.md", target="Docs/Website/support.html",
         url="https://frusexplorer.app/support", slug="support",
         title="FRUS Explorer Support",
         description="Manuals, contact and common questions for FRUS Explorer on iPhone, iPad "
                     "and Mac.",
         comment=POLICY_COMMENT),
    dict(source="Docs/iOS-Quick-Start.md", target="Docs/Website/quick-start-ios.html",
         url="https://frusexplorer.app/quick-start-ios", slug="quick-start-ios",
         title="FRUS Explorer for iPad and iPhone — Quick Start",
         description="A first session with FRUS Explorer on iPad and iPhone, from the first "
                     "download to a cited document, with screenshots.",
         comment=GUIDE_COMMENT, guide=True),
    dict(source="Docs/macOS-Quick-Start.md", target="Docs/Website/quick-start-mac.html",
         url="https://frusexplorer.app/quick-start-mac", slug="quick-start-mac",
         title="FRUS Explorer for macOS — Quick Start",
         description="A first session with FRUS Explorer on the Mac, from the first download "
                     "to a cited document, with screenshots.",
         comment=GUIDE_COMMENT, guide=True),
]

TEMPLATE = """<!DOCTYPE html>
<!--
{comment}
-->
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{description}">
<style>
  :root {{ color-scheme: light dark; }}
  body {{
    margin: 0;
    font: 17px/1.55 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Helvetica, Arial, sans-serif;
    color: #1d1d1f;
    background: #ffffff;
  }}
  main {{ max-width: 46rem; margin: 0 auto; padding: 2.5rem 16px 4rem; }}
  h1 {{ font-size: 2rem; line-height: 1.2; margin: 0 0 1rem; }}
  h2 {{ font-size: 1.3rem; margin: 2.2rem 0 0.6rem; }}
  a {{ color: #0b57d0; }}
  code {{ font: 0.9em ui-monospace, SFMono-Regular, Menlo, monospace; }}
  blockquote {{ margin: 1.2rem 0; padding: 0.2rem 1rem; border-left: 3px solid #c7c7cc; color: #3a3a3c; }}
  li {{ margin: 0.35rem 0; }}
  hr {{ border: 0; border-top: 1px solid #d2d2d7; margin: 2.5rem 0 1rem; }}
  @media (prefers-color-scheme: dark) {{
    body {{ color: #f5f5f7; background: #1c1c1e; }}
    a {{ color: #7cacf8; }}
    blockquote {{ border-left-color: #48484a; color: #d1d1d6; }}
    hr {{ border-color: #3a3a3c; }}
  }}
</style>
</head>
<body>
<main>

{main}

</main>
</body>
</html>
"""

# Lines that end a paragraph: a heading, a list item, a blockquote, a rule, a table row, or an
# image line.
_BLOCK_START = re.compile(r"(# |## |- |> |---|\||!\[|<img |\d+\. )")


def anchor(heading):
    """The id GitHub gives a heading, so an in-page link works in both copies."""
    return re.sub(r"[^\w\- ]", "", heading.lower()).strip().replace(" ", "-")


def resolve(href, source):
    """Where a link in `source` goes on the site: a relative path to a file under the repository
    becomes that file's page here when it has one, and its GitHub copy otherwise; an absolute URL
    or an in-page anchor is unchanged."""
    if re.match(r"[a-z]+:", href) or href.startswith("#"):
        return href
    path, _, fragment = href.partition("#")
    path = posixpath.normpath(posixpath.join(posixpath.dirname(source), path))
    pages = {page["source"]: page["url"] for page in PAGES}
    base = pages.get(path, GITHUB_BLOB + path)
    return base + ("#" + fragment if fragment else "")


def inline(text, source=""):
    """Escapes a line and converts its inline Markdown."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"(?<![\w*])\*([^*]+)\*(?![\w*])", r"<em>\1</em>", out)
    out = re.sub(r"\[([^\]]+)\]\(([^)]+)\)",
                 lambda m: '<a href="{}">{}</a>'.format(resolve(m.group(2), source), m.group(1)),
                 out)
    out = re.sub(r"&lt;(https?://[^&]+)&gt;", r'<a href="\1">\1</a>', out)
    for address in ADDRESSES:
        out = out.replace(address, '<a href="mailto:{0}">{0}</a>'.format(address))
    return out


def png_size(path):
    """A PNG's width and height in pixels, read from its header."""
    with open(_REPO / path, "rb") as handle:
        header = handle.read(24)
    return struct.unpack(">II", header[16:24])


def image(src, alt, source, width=None):
    """One screenshot: loaded from GitHub, sized for its column, given its height so the page
    does not jump while it loads."""
    path = posixpath.normpath(posixpath.join(posixpath.dirname(source), src))
    natural_width, natural_height = png_size(path)
    width = int(width) if width else natural_width
    height = round(natural_height * width / natural_width)
    return ('<img src="{}" alt="{}" width="{}" height="{}" loading="lazy">'
            .format(GITHUB_RAW + path, html.escape(alt, quote=True), width, height))


def cells(row):
    """A table row's cells, without the outer pipes."""
    return [cell.strip() for cell in row.strip().strip("|").split("|")]


def body(markdown, source=""):
    """Converts the page's Markdown, its leading comment removed, into the contents of <main>."""
    markdown = re.sub(r"<!--.*?-->\s*", "", markdown, flags=re.S)
    lines = markdown.split("\n")
    blocks, i = [], 0
    while i < len(lines):
        line = lines[i]
        picture = re.fullmatch(r"!\[([^\]]*)\]\(([^)\s]+)\)", line.strip())
        if not line.strip():
            i += 1
        elif line.startswith("# "):
            blocks.append("<h1>{}</h1>".format(inline(line[2:], source)))
            i += 1
        elif line.startswith("## "):
            blocks.append('<h2 id="{}">{}</h2>'.format(anchor(line[3:]), inline(line[3:], source)))
            i += 1
        elif line.strip() == "---":
            blocks.append("<hr>")
            i += 1
        elif line.startswith("> "):
            blocks.append("<blockquote><p>{}</p></blockquote>".format(inline(line[2:], source)))
            i += 1
        elif line.startswith("- "):
            items = []
            while i < len(lines) and lines[i].startswith("- "):
                items.append("  <li>{}</li>".format(inline(lines[i][2:], source)))
                i += 1
            blocks.append("<ul>\n{}\n</ul>".format("\n".join(items)))
        elif re.match(r"\d+\. ", line):
            items = []
            while i < len(lines) and re.match(r"\d+\. ", lines[i]):
                items.append("  <li>{}</li>".format(inline(lines[i].split(". ", 1)[1], source)))
                i += 1
            blocks.append("<ol>\n{}\n</ol>".format("\n".join(items)))
        elif line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(cells(lines[i]))
                i += 1
            head = "".join("<th>{}</th>".format(inline(cell, source)) for cell in rows[0])
            rest = ["    <tr>{}</tr>".format("".join(
                "<td>{}</td>".format(inline(cell, source)) for cell in row)) for row in rows[2:]]
            blocks.append("<table>\n  <thead>\n    <tr>{}</tr>\n  </thead>\n  <tbody>\n{}\n"
                          "  </tbody>\n</table>".format(head, "\n".join(rest)))
        elif picture:
            blocks.append('<p class="shots">{}</p>'.format(
                image(picture.group(2), picture.group(1), source)))
            i += 1
        elif line.startswith("<img "):
            tags = re.findall(r"<img ([^>]*)>", line)
            pictures = []
            for tag in tags:
                attributes = dict(re.findall(r'(\w+)="([^"]*)"', tag))
                pictures.append(image(attributes["src"], html.unescape(attributes.get("alt", "")),
                                      source, attributes.get("width")))
            blocks.append('<p class="shots">{}</p>'.format(" ".join(pictures)))
            i += 1
        else:
            paragraph = []
            while i < len(lines) and lines[i].strip() and not _BLOCK_START.match(lines[i]):
                paragraph.append(lines[i])
                i += 1
            blocks.append("<p>{}</p>".format(inline(" ".join(paragraph), source)))
    return "\n\n".join(blocks)


def render(page):
    """The whole HTML file one page's Markdown makes."""
    markdown = (_REPO / page["source"]).read_text(encoding="utf-8")
    main = body(markdown, page["source"])
    if page.get("guide"):
        main = '{}\n\n<div class="frus-quick-start">\n\n{}\n\n</div>'.format(GUIDE_STYLE, main)
    fields = dict(page, main=main, comment=page["comment"].format(**page))
    return TEMPLATE.format(**fields)


def main(argv):
    check = "--check" in argv[1:]
    stale = []
    for page in PAGES:
        target = _REPO / page["target"]
        expected = render(page)
        current = target.read_text(encoding="utf-8") if target.exists() else None
        if current == expected:
            continue
        if check:
            stale.append(page["target"])
        else:
            target.write_text(expected, encoding="utf-8")
            print("wrote {}".format(page["target"]))
    if stale:
        print("out of step with its Markdown: {} (run Scripts/build_website_pages.py)".format(
            ", ".join(stale)))
        return 1
    if check:
        print("every page in step")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
