#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Writes the domain's copies of the Privacy Policy and Support pages from their GitHub copies.

Plan of record decision 36 keeps each page in two copies, in step: the Markdown on GitHub
(`Docs/Privacy-Policy.md`, `Docs/Support.md`) and the HTML on frusexplorer.app
(`Docs/Website/privacy.html`, `Docs/Website/support.html`). The Markdown is the one edited; this
script writes the HTML from it, so the two say the same thing word for word. `--check` writes
nothing and fails when an HTML file is not what the Markdown would make, which is the state a
hand edit to one copy leaves.

It reads only the Markdown those two pages use: `#` and `##` headings, paragraphs, `- ` lists, one
`> ` blockquote line, `---`, and inline `**bold**`, `*italic*`, `` `code` ``, `[text](url)` and
`<url>`. Anything else passes through as text, so a new construct shows up in the review of the
HTML diff rather than silently.

Stdlib only, macOS's bundled python3 (3.9), no pip.

Usage:
    python3 Scripts/build_website_pages.py           # rewrite both HTML files
    python3 Scripts/build_website_pages.py --check   # exit 1 if either is out of step
"""

import html
import re
import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parent.parent

# The mailbox decision 26 waits on. Every copy spells it this way until the owner names it, and
# the HTML makes each one a mailto link.
ADDRESS = "[ADDRESS]@frusexplorer.app"

PAGES = [
    dict(source="Docs/Privacy-Policy.md", target="Docs/Website/privacy.html",
         url="https://frusexplorer.app/privacy", slug="privacy",
         title="FRUS Explorer Privacy Policy",
         description="FRUS Explorer collects no data. What the app keeps, where it keeps it, "
                     "and every place it connects to."),
    dict(source="Docs/Support.md", target="Docs/Website/support.html",
         url="https://frusexplorer.app/support", slug="support",
         title="FRUS Explorer Support",
         description="Manuals, contact and common questions for FRUS Explorer on iPhone, iPad "
                     "and Mac."),
]

TEMPLATE = """<!DOCTYPE html>
<!--
  One of two copies kept in step (plan of record decision 36). Its twin, on GitHub, is
  {source}. This copy is published at {url},
  the address App Store Connect names. Do not edit it: edit the twin and run
  Scripts/build_website_pages.py, which writes this file. Docs/Website/README.md has the rest.

  To publish on the Squarespace site, paste everything between <main> and </main> into a Code
  Block on a page whose URL slug is {slug}; the site's own type and colours then apply, and the
  <style> below, which is only for viewing this file on its own, is left behind.

  Before publishing, replace every [ADDRESS] with the mailbox's name (plan of record decision 26).
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


def anchor(heading):
    """The id GitHub gives a heading, so an in-page link works in both copies."""
    return re.sub(r"[^\w\- ]", "", heading.lower()).strip().replace(" ", "-")


def inline(text):
    """Escapes a line and converts its inline Markdown."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"(?<![\w*])\*([^*]+)\*(?![\w*])", r"<em>\1</em>", out)
    out = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', out)
    out = re.sub(r"&lt;(https?://[^&]+)&gt;", r'<a href="\1">\1</a>', out)
    return out.replace(ADDRESS, '<a href="mailto:{0}">{0}</a>'.format(ADDRESS))


def body(markdown):
    """Converts the page's Markdown, its leading comment removed, into the contents of <main>."""
    markdown = re.sub(r"<!--.*?-->\s*", "", markdown, flags=re.S)
    lines = markdown.split("\n")
    blocks, i = [], 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
        elif line.startswith("# "):
            blocks.append("<h1>{}</h1>".format(inline(line[2:])))
            i += 1
        elif line.startswith("## "):
            blocks.append('<h2 id="{}">{}</h2>'.format(anchor(line[3:]), inline(line[3:])))
            i += 1
        elif line.strip() == "---":
            blocks.append("<hr>")
            i += 1
        elif line.startswith("> "):
            blocks.append("<blockquote><p>{}</p></blockquote>".format(inline(line[2:])))
            i += 1
        elif line.startswith("- "):
            items = []
            while i < len(lines) and lines[i].startswith("- "):
                items.append("  <li>{}</li>".format(inline(lines[i][2:])))
                i += 1
            blocks.append("<ul>\n{}\n</ul>".format("\n".join(items)))
        else:
            paragraph = []
            while i < len(lines) and lines[i].strip() and not re.match(r"(# |## |- |> |---)", lines[i]):
                paragraph.append(lines[i])
                i += 1
            blocks.append("<p>{}</p>".format(inline(" ".join(paragraph))))
    return "\n\n".join(blocks)


def render(page):
    """The whole HTML file one page's Markdown makes."""
    markdown = (_REPO / page["source"]).read_text(encoding="utf-8")
    return TEMPLATE.format(main=body(markdown), **page)


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
        print("both pages in step")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
