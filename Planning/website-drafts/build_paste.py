#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Writes what the owner pastes into Squarespace, and keeps the entry guide in step with it.

frusexplorer.app is a Squarespace 7.1 site on the Basic plan. Read on 2026-11-10 in Squarespace's
help centre: a Code Block there renders HTML and a <style>, up to 400 KB, and does not run
<script> or <iframe>; the Announcement Bar is not on the plan. So a page goes up one of two ways,
and Squarespace-Entry.md walks the owner through both:

    paste/privacy.txt           one Code Block   <main> of Docs/Website/privacy.html
    paste/support.txt           one Code Block   <main> of Docs/Website/support.html
    paste/quick-start-ios.txt   one Code Block   <main> of Docs/Website/quick-start-ios.html
    paste/quick-start-mac.txt   one Code Block   <main> of Docs/Website/quick-start-mac.html
    paste/tour-block-1.txt      one Code Block   the tour, its opening to step 13
    paste/tour-block-2.txt      one Code Block   the tour, step 14 to step 20
    paste/home-coming-soon.txt  one Code Block   the home page as it reads before release
    paste/home-launch.txt       one Code Block   the home page as it reads from release day
    paste/tour-coming-soon-line.txt, tour-closing-coming-soon.txt, tour-closing-launch.txt
                                small Code Blocks: the tour's coming-soon line and its closing
                                section, which are all of the tour that differs at launch
    paste/footer.txt            one Code Block   the footer every page shares: the disclaimer, the
                                                 National Archives sentence and the links
    Squarespace-Entry.md        the guide        its generated parts: the home page's two pastes,
                                                 and the same page block by block for native
                                                 blocks (site-src/home.html), the tour's native
                                                 sections, the site footer and the fingerprints
    page-drafts.html            (review sheet)   its Support and Privacy frames, from the drafts

The tour's two blocks are tour/tour.html made static, since the page as drafted needs a script:
  - its stylesheet is scoped to a wrapper, `.frus-tour`, light only, with what the site's own
    theme might set on a heading or a paragraph set back first;
  - a screen is a link to its full-size image, where the draft opens a lightbox;
  - the screens load from this folder on GitHub, as the quick starts load theirs, so a re-cut crop
    shows on the site with no new paste, and the repository has to stay public;
  - the film is left out, for a Squarespace Video block: GitHub serves an .mp4 as
    application/octet-stream, which a browser's player may refuse;
  - the coming-soon banner and the closing section, the only parts that differ at launch, are
    left out of the two, each for a small block of its own, so that neither large block is pasted
    again on release day; the production notes, the running head, the footer (the site's own
    carries the disclaimer) and the draft's review bar are left out too.
The split falls where the film goes, after the map's band.

The home page's block is site-src/home.html with the rules of site-src/site.css it uses, scoped
to `.frus-home` after the same reset. Squarespace has no switch between a page's two versions, so
each is a file of its own, and release day is one paste over the other. The launch version links
Apple's badge, loaded from Apple's marketing toolbox, to the app's page on the App Store: an
address the app has only once it is approved, so until APP_STORE_URL below is set that file holds
a placeholder and says NOT READY on its first line.

Every paste opens with a comment naming its page, its source and a fingerprint of what follows,
so the block on the site says which version it holds. The published page is a copy the repository
cannot see (Docs/Website/README.md); the fingerprint is what a later check can read.

Stdlib only, macOS's bundled python3 (3.9), no pip. Run from anywhere:
    python3 Planning/website-drafts/build_paste.py           # rewrite whatever is out of step
    python3 Planning/website-drafts/build_paste.py --check   # exit 1 if anything is
Run it after any change to a page's source: Docs/Support.md, Docs/Privacy-Policy.md or a quick
start (after Scripts/build_website_pages.py), site-src/home.html, tour/tour.html, or a draft.
"""

import hashlib
import html
import importlib.util
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
PASTE = HERE / "paste"
GUIDE = HERE / "Squarespace-Entry.md"
SHEET = HERE / "page-drafts.html"
HOME = HERE / "site-src" / "home.html"
TOUR = HERE / "tour" / "tour.html"


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


bwp = _load("bwp", REPO / "Scripts" / "build_website_pages.py")
site = _load("build_site", HERE / "build_site.py")

# The wrapper every rule of the tour's stylesheet is scoped to.
SCOPE = ".frus-tour"
# Where the tour's screens load from: this folder, at the default branch's head.
TOUR_IMAGES = bwp.GITHUB_RAW + "Planning/website-drafts/tour/img/"
# The film, which the owner uploads to a Video block: its path from this folder.
FILM = "tour/img/map-film.mp4"
# A Code Block's limit, from Squarespace's help centre.
CODE_BLOCK_LIMIT = 400 * 1000
# The wrapper of the home page's block.
HOME_SCOPE = ".frus-home"
# The app's page on the App Store: "https://apps.apple.com/app/id" and the app's Apple ID. It has
# one once it is approved, so this is set on release day. While it is None the launch version of
# the home page holds the placeholder where the address goes, and says so on its first line.
APP_STORE_URL = None
APP_STORE_PLACEHOLDER = "APP-STORE-ADDRESS"
# Apple's own artwork for that link, served by its marketing toolbox: the black badge, 120 by 40,
# which is the smallest Apple allows on a screen.
APP_STORE_BADGE = ("https://toolbox.marketingtools.apple.com/api/v2/badges/"
                   "download-on-the-app-store/black/en-us")


class OutOfShape(Exception):
    """A source no longer has the shape this script reads; the message says which and where."""


def one(pattern, text, what, flags=re.S):
    """The single match of `pattern` in `text`, or an error naming what was looked for."""
    found = re.findall(pattern, text, flags)
    if len(found) != 1:
        raise OutOfShape("expected one {}, found {}".format(what, len(found)))
    return found[0]


def between(text, start, end, what):
    """What lies between the one `start` and the next `end`."""
    if text.count(start) != 1:
        raise OutOfShape("expected one {!r} in {}, found {}".format(start, what, text.count(start)))
    rest = text.split(start, 1)[1]
    if end not in rest:
        raise OutOfShape("no {!r} after {!r} in {}".format(end, start, what))
    return rest.split(end, 1)[0]


def stamped(payload, page, source, note=""):
    """A paste: its comment, then the payload. The fingerprint is the payload's alone."""
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()[:8]
    return "<!-- frusexplorer.app{} · from {} · {}fingerprint {} -->\n{}\n".format(
        page, source, note + " · " if note else "", digest, payload)


def fingerprint(paste):
    return one(r"fingerprint ([0-9a-f]{8}) -->", paste.split("\n", 1)[0], "fingerprint")


# ---- The four pages Scripts/build_website_pages.py writes: the contents of <main>

def docs_pastes():
    out = {}
    for page in bwp.PAGES:
        rendered = bwp.render(page)
        if (REPO / page["target"]).read_text(encoding="utf-8") != rendered:
            raise OutOfShape("{} is not what {} makes: run Scripts/build_website_pages.py first"
                             .format(page["target"], page["source"]))
        main = between(rendered, "\n<main>\n", "\n</main>\n", page["target"]).strip("\n")
        if re.search(r"<script|<iframe", main):
            raise OutOfShape("{} holds a script or an iframe, which the Basic plan does not run"
                             .format(page["target"]))
        out[page["slug"] + ".txt"] = stamped(main, "/" + page["slug"], page["target"])
    return out


# ---- A draft's stylesheet, scoped to its paste's wrapper

# A selector that goes: page-level rules (the wrapper carries what it needs), the dark theme, and
# the parts the paste leaves out.
_DROPPED = re.compile(
    r"^(html|body)(?![\w-])|^:root\["
    r"|\.(runhead|toggle|preview|seg|pnote|soon-banner|close|cta|btn|lb)(?![\w-])|\.lb-"
    r"|footer\.foot|figure\.film|\[data-new\]|\[data-show")

# Set before a draft's own rules, so that each of those, which follows it or is more specific,
# still wins: what a site's theme sets on bare elements is put back to the wrapper's.
_RESET = """\
{s} {{ font-family: var(--serif); font-size: {size}; line-height: 1.6; font-weight: 400; font-style: normal; letter-spacing: normal; text-transform: none; text-align: left; color: var(--ink); font-optical-sizing: auto; -webkit-font-smoothing: antialiased; }}
{s} h1, {s} h2, {s} h3, {s} p, {s} ol, {s} ul, {s} li, {s} dl, {s} dt, {s} dd, {s} figcaption, {s} blockquote, {s} span, {s} a, {s} b, {s} i, {s} em, {s} sup, {s} code {{ font-family: inherit; font-size: inherit; font-style: inherit; line-height: inherit; letter-spacing: inherit; text-transform: inherit; color: inherit; }}
{s} li, {s} blockquote, {s} dl, {s} dt, {s} dd {{ margin: 0; }}
{s} blockquote {{ padding: 0; border: 0; quotes: none; }}
{s} blockquote::before, {s} blockquote::after {{ content: none; }}
{s} code {{ background: none; padding: 0; border: 0; }}
{s} a {{ text-decoration: underline; }}"""

# Set after them: the page's own section supplies the gutters, the band keeps its own, an anchor
# clears a site header that stays on screen, and a screen is a link.
_FITTED = """\
{s} .inner {{ padding-left: 0; padding-right: 0; }}
{s} .opening {{ padding-top: 8px; }}
{s} .night {{ border-radius: 4px; }}
{s} .night .inner {{ padding-left: clamp(16px, 4vw, 40px); padding-right: clamp(16px, 4vw, 40px); }}
{s} .part, {s} .entry, {s} .fns p {{ scroll-margin-top: 96px; }}
{s} a.zoom {{ text-decoration: none; }}"""


def _rules(css):
    """A stylesheet's top-level rules as (prelude, body), comments removed."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    i = 0
    while True:
        j = css.find("{", i)
        if j < 0:
            return
        depth, k = 1, j + 1
        while depth:
            depth += {"{": 1, "}": -1}.get(css[k], 0)
            k += 1
        yield css[i:j].strip(), css[j + 1:k - 1]
        i = k


def _scoped_selector(selector, scope, dropped, kept):
    selector = " ".join(selector.split())
    if dropped.search(selector) or (kept and not kept(selector)):
        return None
    if selector == ":root":
        return scope
    if selector == "*":
        return "{0}, {0} *".format(scope)
    return "{} {}".format(scope, selector)


def scoped_css(css, scope, dropped, kept=None):
    """A stylesheet with every rule under `scope`, light only: a selector `dropped` matches goes,
    and so does one `kept`, when given, does not accept."""
    out = []
    for prelude, body in _rules(css):
        if prelude.startswith("@media"):
            if "prefers-color-scheme" in prelude:
                continue
            inner = scoped_css(body, scope, dropped, kept)
            if inner:
                out.append("{} {{\n{}\n}}".format(prelude, "\n".join("  " + r for r in inner)))
            continue
        if prelude.startswith("@"):
            raise OutOfShape("a draft's stylesheet has an at-rule this script does not read: "
                             + prelude)
        selectors = [s for s in (_scoped_selector(s, scope, dropped, kept) for s in prelude.split(","))
                     if s]
        if selectors:
            out.append("{} {{ {} }}".format(", ".join(selectors), " ".join(body.split())))
    return out


def scoped_style(css, scope, size, dropped, fitted, kept=None, what="stylesheet"):
    """The <style> a paste opens with: the draft's variables, the reset, its rules, then what
    fits them to a page that is not its own."""
    rules = scoped_css(css, scope, dropped, kept)
    if not rules or not rules[0].startswith(scope + " { --paper"):
        raise OutOfShape("the {} no longer opens with its :root variables".format(what))
    reset = [_RESET.format(s=scope, size=size)]
    # The reset makes <i> and <em> take their style from what holds them, so that a theme's rule
    # for either goes. A draft whose own stylesheet does not then set them italic (the tour's
    # does; the preview's, which the home page uses, leaves it to the browser) has it set here.
    italic = "{0} i, {0} em {{ font-style: italic; }}".format(scope)
    if italic not in rules:
        reset.append(italic)
    lines = [rules[0]] + reset + rules[1:] + [fitted.format(s=scope)]
    return "<style>\n{}\n</style>".format("\n".join(lines))


def tour_style(tour):
    return scoped_style(between(tour, "<style>", "</style>", "tour.html"), SCOPE, "18px",
                        _DROPPED, _FITTED, what="tour's stylesheet")


# ---- The tour: its body, static, in two blocks

def tour_blocks():
    """The two Code Blocks, by file name."""
    tour = TOUR.read_text(encoding="utf-8")
    style = tour_style(tour)
    body = between(tour, "<main>\n", "</main>", "tour.html")

    body, notes = re.subn(r'[ \t]*<p class="pnote">.*?</p>\n', "", body, flags=re.S)
    body, films = re.subn(r'[ \t]*<figure class="film">.*?</figure>\n', "", body, flags=re.S)
    body, close = re.subn(r'<section class="close".*?</section>\n', "", body, flags=re.S)
    if films != 1 or close != 1 or not notes:
        raise OutOfShape("tour.html: expected one film figure and one closing section, and "
                         "production notes; found {}, {} and {}".format(films, close, notes))

    def screen(match):
        label, file, rest = match.groups()
        url = TOUR_IMAGES + file
        return ('<a class="zoom" href="{0}" target="_blank" rel="noopener" aria-label="{1}, at full '
                'size in a new tab"><img src="{0}" {2} loading="lazy" decoding="async"></a>'
                .format(url, label, rest))
    body, screens = re.subn(
        r'<button class="zoom" type="button" aria-label="([^"]*)"><img src="img/([^"]+)" ([^>]*)></button>',
        screen, body)
    body = re.sub(r"<!--.*?-->\n*", "", body, flags=re.S)
    body = body.replace(" data-new>", ">")
    body = body.replace('id="title"', 'id="tour-title"').replace(
        'aria-labelledby="title"', 'aria-labelledby="tour-title"')
    for leftover in ('src="img/', "<button", "<script", "<iframe", "<video", "data-show", "data-new"):
        if leftover in body:
            raise OutOfShape("tour.html: {!r} is left in the body after the static pass".format(leftover))
    if screens != len(re.findall(r'class="zoom"', tour)):
        raise OutOfShape("tour.html: {} screens made links, of {}".format(
            screens, len(re.findall(r'class="zoom"', tour))))

    # The split: the map's band closes block 1, and step 14's column opens block 2. Part III's
    # section is closed in the first and reopened, without its id, in the second.
    seam = '  <div class="inner" style="padding-top:56px;padding-bottom:24px">\n'
    if body.count(seam) != 1:
        raise OutOfShape("tour.html: the column that follows the map's band was not found once")
    first, second = body.split(seam)
    first = first.rstrip("\n") + "\n</section>"
    second = '<section class="part" style="padding-top:0">\n' + seam + second.rstrip("\n")

    out = {}
    for name, part in (("tour-block-1.txt", first), ("tour-block-2.txt", second)):
        payload = '{}\n<div class="frus-tour">\n\n{}\n\n</div>'.format(style, part.strip("\n"))
        out[name] = stamped(payload, "/tour", "Planning/website-drafts/tour/tour.html")
    return out


# ---- The home page as one Code Block, in each of its two versions

_HOME_DROPPED = re.compile(r"^(html|body)(?![\w-])|^:root\[")
# What the home page uses of the preview's stylesheet: its variables, these bare elements, and
# its own classes. The shell's and the review layer's rules stay behind.
_HOME_BASE = (":root", "*", "h1", "h2", "h3", "p", "a", "a:focus-visible")
# Two of its classes the paste restyles, so the preview's rule for each stays behind: the banner,
# which the preview hides, and the badge's stand-in, which the paste replaces with the badge.
_HOME_REPLACED = (".pg-banner", ".pg-badge")

# Set after the draft's own rules. The preview hides the draft's banner, since its shell shows
# one; pasted, the page has no other. The badge is Apple's artwork at its smallest size.
_HOME_FITTED = """\
{s} .pg-banner {{ display: flex; flex-wrap: wrap; gap: 4px 12px; align-items: baseline; margin: 0 0 26px; padding: 10px 16px; background: var(--tint); border: 1px solid var(--rule); border-radius: 4px; font-family: var(--sans); font-size: 14.5px; }}
{s} .pg-banner b {{ color: var(--red); font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; font-size: 12px; }}
{s} .pg-list {{ list-style: disc outside; }}
{s} .pg-badge-link {{ display: inline-block; line-height: 0; }}
{s} .pg-badge-link img {{ display: block; height: 40px; width: auto; max-width: none; border: 0; border-radius: 0; box-shadow: none; }}
{s} .pg-unready {{ margin: 0 0 26px; padding: 12px 16px; background: #FFF7E6; border: 2px dashed var(--red); border-radius: 4px; font-family: var(--sans); font-size: 15px; color: var(--ink); }}"""

# Shown at the top of the launch version while it has no App Store address, so that a paste of
# the unready file cannot be mistaken on the page for a finished one.
_HOME_UNREADY = ('<p class="pg-unready"><b>Not ready to publish.</b> The App Store badge below links '
                 'nowhere yet: this file was made before the app had an App Store address. Set '
                 'APP_STORE_URL in build_paste.py, run it, and paste the file it writes.</p>\n\n')


def home_source():
    """site-src/home.html without its leading comment and its review note."""
    text = re.sub(r"<!--.*?-->\s*", "", HOME.read_text(encoding="utf-8"), count=1, flags=re.S)
    text, notes = re.subn(r'<aside class="rv" data-rv>.*?</aside>\s*', "", text, count=1, flags=re.S)
    if notes != 1:
        raise OutOfShape("home.html: its review note was not found")
    return text


def home_blocks():
    """The home page's Code Block in its coming-soon and its launch version, by file name."""
    style = scoped_style((HERE / "site-src" / "site.css").read_text(encoding="utf-8"), HOME_SCOPE,
                         "17px", _HOME_DROPPED, _HOME_FITTED,
                         kept=lambda selector: selector in _HOME_BASE or (
                             ".pg-" in selector and selector not in _HOME_REPLACED),
                         what="preview's stylesheet")
    source = home_source()
    out = {}
    for state, other, name, version in (("soon", "launch", "home-coming-soon.txt", "coming-soon"),
                                        ("launch", "soon", "home-launch.txt", "launch")):
        body = re.sub(r'[ \t]*<(\w+)\b[^>]*\bdata-show="{}"[^>]*>.*?</\1>\n?'.format(other), "",
                      source, flags=re.S)
        body = body.replace(' data-show="{}"'.format(state), "")
        body = re.sub(r'href="([^"]*)"', lambda m: 'href="{}"'.format(site_path(m.group(1))), body)
        note = ""
        if state == "launch":
            badge = ('<a class="pg-badge-link" href="{}"><img src="{}" alt="Download on the App Store" '
                     'width="120" height="40"></a>'.format(APP_STORE_URL or APP_STORE_PLACEHOLDER,
                                                             APP_STORE_BADGE))
            body, badges = re.subn(r'<span class="pg-badge"[^>]*>.*?</span>', badge, body, flags=re.S)
            if badges != 1:
                raise OutOfShape("home.html: its launch version has no one badge to replace")
            if not APP_STORE_URL:
                note = "NOT READY: {} stands where the app's App Store address goes".format(
                    APP_STORE_PLACEHOLDER)
                body = _HOME_UNREADY + body
        for leftover in ("data-show", "<script", "<iframe", "<button", '.html"', 'class="pg-badge"'):
            if leftover in body:
                raise OutOfShape("home.html: {!r} is left in its {} version".format(leftover, version))
        payload = '{}\n<div class="frus-home">\n\n{}\n\n</div>'.format(style, body.strip("\n"))
        out[name] = stamped(payload, "/", "Planning/website-drafts/site-src/home.html, {} version"
                            .format(version), note)
    return out


# ---- Text for native blocks: a fragment of a draft's HTML as the words to type

def site_path(href):
    """A draft's link as the address to give Squarespace: a page of the site by its path."""
    href = html.unescape(href)
    if href.startswith("mailto:"):
        return href
    href = re.sub(r"^https://frusexplorer\.app", "", href) or "/"
    if re.match(r"[a-z]+:", href):
        return href
    path, _, fragment = href.partition("#")
    path = "/" + re.sub(r"(index)?\.html$", "", path).lstrip("/")
    return path + ("#" + fragment if fragment else "")


def words(fragment):
    """The fragment as Markdown: italics and bold kept, a link as its text."""
    out = re.sub(r"<a\b[^>]*>(.*?)</a>", r"\1", fragment, flags=re.S)
    out = re.sub(r"</?(i|em)\b[^>]*>", "*", out)
    out = re.sub(r"</?(b|strong)\b[^>]*>", "**", out)
    out = html.unescape(re.sub(r"<[^>]+>", "", out))
    out = " ".join(out.split())
    if "|" in out:
        raise OutOfShape("a draft's text holds a |, which a table cell here cannot: " + out[:60])
    return out


def touches(fragment):
    """What to put back after a paste, since Squarespace's keeps the words alone: the italics,
    the bold, and each link with its address."""
    notes = []
    for tag, name in (("i", "italic"), ("em", "italic"), ("b", "bold"), ("strong", "bold")):
        for text in re.findall(r"<{0}\b[^>]*>(.*?)</{0}>".format(tag), fragment, re.S):
            notes.append("{}: *{}*".format(name, words(text)) if name == "italic"
                         else "{}: **{}**".format(name, words(text)))
    for href, text in re.findall(r'<a\b[^>]*?href="([^"]*)"[^>]*>(.*?)</a>', fragment, re.S):
        notes.append("link: “{}” → `{}`".format(words(text), site_path(href)))
    return notes


def then(*fragments):
    """The line under a block that lists what to put back, or nothing."""
    notes = [note for fragment in fragments for note in touches(fragment)]
    return "*After pasting* — {}.\n".format("; ".join(notes)) if notes else ""


def quoted(*paragraphs):
    return "\n>\n".join("> " + p for p in paragraphs)


# ---- The home page, block by block

def home_parts():
    """site-src/home.html's parts, by the classes its markup carries."""
    text = home_source()
    hero = one(r'<section class="pg-hero">(.*?)</section>', text, "hero in home.html")
    sections = re.findall(r'<section class="pg-sec"(?: data-show="(soon|launch)")?>(.*?)</section>',
                          text, re.S)
    plain = [body for state, body in sections if not state]
    contact = {state: body for state, body in sections if state}
    if len(plain) != 5 or set(contact) != {"soon", "launch"}:
        raise OutOfShape("home.html: expected five sections and a contact section for each state, "
                         "found {} and {}".format(len(plain), sorted(contact)))
    doing, editors, holds, yours, questions = plain

    def by_state(pattern, source, what):
        found = dict(re.findall(pattern, source, re.S))
        if set(found) != {"soon", "launch"}:
            raise OutOfShape("home.html: expected a coming-soon and a launch {}".format(what))
        return found

    def section(body, what):
        return dict(title=one(r"<h2>(.*?)</h2>", body, what + " heading"),
                    more=re.findall(r'<p class="pg-more">(.*?)</p>', body, re.S),
                    body=body)

    faq = []
    for tag, state, inner in re.findall(r'<(dt|dd)(?: data-show="(soon|launch)")?>(.*?)</\1>',
                                        questions, re.S):
        if tag == "dt":
            faq.append(dict(question=inner, only=state, answers={}))
        else:
            faq[-1]["answers"][state or "both"] = inner
    return dict(
        banner=one(r'<div class="pg-banner" data-show="soon"><b>(.*?)</b><span>(.*?)</span></div>',
                   text, "coming-soon banner in home.html"),
        kicker=by_state(r'<p class="pg-kick" data-show="(soon|launch)">(.*?)</p>', hero, "kicker"),
        headline=one(r"<h1>(.*?)</h1>", hero, "headline in home.html"),
        lead=by_state(r'<p class="pg-lead" data-show="(soon|launch)">(.*?)</p>', hero, "lead"),
        cta=by_state(r'<div class="pg-cta" data-show="(soon|launch)">(.*?)</div>', hero, "row of links"),
        disclaimer=one(r'<p class="pg-disc">(.*?)</p>', hero, "hero disclaimer"),
        doing=dict(section(doing, "What it does"),
                   four=re.findall(r"<div><h3>(.*?)</h3><p>(.*?)</p></div>", doing, re.S)),
        editors=dict(section(editors, "editors' section"),
                     paragraphs=re.findall(r"<p>(.*?)</p>", editors, re.S)),
        holds=dict(section(holds, "Work that holds up"),
                   items=re.findall(r"<li>(.*?)</li>", holds, re.S)),
        yours=dict(section(yours, "privacy section"),
                   paragraphs=re.findall(r"<p>(.*?)</p>", yours, re.S)),
        questions=dict(title=one(r"<h2>(.*?)</h2>", questions, "Questions heading"), faq=faq),
        contact={state: dict(title=one(r"<h2>(.*?)</h2>", body, "contact heading"),
                             text=one(r"<p>(.*?)</p>", body, "contact paragraph"))
                 for state, body in contact.items()},
    )


def home_chapter():
    """The guide's chapter on the home page, coming-soon version first."""
    p = home_parts()
    soon_cta = p["cta"]["soon"]
    tour_link = one(r'(<a href="tour\.html">.*?</a>)', soon_cta, "tour link in the hero")
    quick = one(r'<span class="pg-qs">(.*?)</span>', soon_cta, "quick-start links in the hero")
    if len(p["doing"]["four"]) != 4 or len(p["holds"]["items"]) != 3:
        raise OutOfShape("home.html: expected four things it does and three ways work holds up")
    for part in ("doing", "editors", "holds", "yours"):
        if len(p[part]["more"]) != 1:
            raise OutOfShape("home.html: expected one closing link in its {} section".format(part))

    def more(part):
        fragment = p[part]["more"][0]
        return fragment, words(fragment)

    out = []
    add = out.append

    add("#### 0. The coming-soon line: a thin section of its own\n")
    add("| Block | Style | Content |\n|---|---|---|\n"
        "| Text | **Paragraph 2**, centred | **{}** — {} |\n".format(
            words(p["banner"][0]), words(p["banner"][1])))
    add("- Bold the first two words. Under **Edit Section**, give the section the smallest height "
        "and a background that sets it off, so it reads as a notice.\n"
        "- This takes the place of the Announcement Bar, which the Basic plan does not include "
        "(see *Three things the Basic plan changes*, above).\n"
        "- On release day, delete the whole section.\n")

    add("#### 1. Hero\n")
    add("| Block | Style | Content |\n|---|---|---|\n"
        "| Text | **Heading 4** (a small label) | {} |\n"
        "| Text | **Heading 1** | {} |\n"
        "| Text | **Paragraph 1** | {} |\n"
        "| Button | Primary | **{}** → `{}` |\n"
        "| Text | **Paragraph 2** | {} |\n"
        "| Text | **Paragraph 3** (small) | {} |\n".format(
            words(p["kicker"]["soon"]), words(p["headline"]), words(p["lead"]["soon"]),
            words(tour_link), site_path(one(r'href="([^"]*)"', tour_link, "tour address")),
            words(quick), words(p["disclaimer"])))
    add(then(p["lead"]["soon"], quick))
    add("- The draft's outlined “{}” pill is left out on purpose: a Button block with no link looks "
        "clickable and does nothing, and the label above already says it.\n".format(
            words(one(r'<span class="pg-btn soon">(.*?)</span>', soon_cta, "coming-soon pill"))))

    add("#### 2. {}: a heading, four columns, a link\n".format(words(p["doing"]["title"])))
    fragment, text = more("doing")
    add("| Block | Style | Content |\n|---|---|---|\n"
        "| Text, full width | **Heading 2** | {} |\n"
        "| Text × 4, side by side | **Heading 3**, then **Paragraph 2** | the four below |\n"
        "| Text | **Paragraph 2** | {} |\n".format(words(p["doing"]["title"]), text))
    add("\n".join("{}. **{}** — {}".format(n, words(title), words(body))
                  for n, (title, body) in enumerate(p["doing"]["four"], 1)) + "\n")
    add(then(fragment))
    add("- Each of the four is one Text block: its title on the first line as Heading 3, its "
        "sentence under it.\n"
        "- For four columns, make the first block and drag its right edge in to a quarter of the "
        "width, then add the others and drag each beside the last. Check the phone view (the "
        "phone icon at the top of the editor): they should stack.\n")

    add("#### 3. {}: one Text block\n".format(words(p["editors"]["title"])))
    fragment, text = more("editors")
    add("The first line is **Heading 2**, the rest **Paragraph 2**.\n")
    add(quoted("**{}**".format(words(p["editors"]["title"])),
               *[words(para) for para in p["editors"]["paragraphs"]], text) + "\n")
    add(then(*(p["editors"]["paragraphs"] + [fragment])))

    add("#### 4. {}: one Text block\n".format(words(p["holds"]["title"])))
    fragment, text = more("holds")
    add("**Heading 2**, then a bulleted list (select the three lines and use the toolbar's list "
        "button), then the link.\n")
    add(quoted("**{}**".format(words(p["holds"]["title"])),
               "\n> ".join("- " + words(item) for item in p["holds"]["items"]), text) + "\n")
    add(then(*(p["holds"]["items"] + [fragment])))

    add("#### 5. {}: one Text block\n".format(words(p["yours"]["title"])))
    fragment, text = more("yours")
    add(quoted("**{}**".format(words(p["yours"]["title"])),
               *[words(para) for para in p["yours"]["paragraphs"]], text) + "\n")
    add(then(*(p["yours"]["paragraphs"] + [fragment])))
    add("- Give this section a different background from its neighbours (**Edit Section ▸ "
        "Colors**), so it reads as a promise and not one more feature.\n")

    add("#### 6. {}: a heading and an Accordion block\n".format(words(p["questions"]["title"])))
    add("| Block | Content |\n|---|---|\n| Text, **Heading 2** | {} |\n"
        "| **Accordion** | one item for each row below |\n".format(words(p["questions"]["title"])))
    rows, links = [], []
    for item in p["questions"]["faq"]:
        if item["only"] == "launch":
            continue
        answer = item["answers"].get("both", item["answers"].get("soon"))
        rows.append("| {} | {} |".format(words(item["question"]), words(answer)))
        links.append(answer)
    add("| Title | Description |\n|---|---|\n" + "\n".join(rows) + "\n")
    add(then(*links))
    add("- **Add Block ▸ Accordion**, then the block's pencil: each item takes a **Title** (the "
        "question) and a **Description** (the answer).\n")

    add("#### 7. Contact: one Text block\n")
    add(quoted("**{}**".format(words(p["contact"]["soon"]["title"])),
               words(p["contact"]["soon"]["text"])) + "\n")
    add(then(p["contact"]["soon"]["text"]))

    # What release day changes, each from the launch version of the same element.
    soon_only = [i for i in p["questions"]["faq"] if i["only"] == "soon"]
    changed = [i for i in p["questions"]["faq"] if "launch" in i["answers"]]
    badge = words(one(r'<span class="pg-badge"[^>]*>(.*?)</span>', p["cta"]["launch"], "badge"))
    add("#### On release day, change six things\n")
    steps = [
        "**Section 0:** delete it.",
        "**Hero label:** {}".format(words(p["kicker"]["launch"])),
        "**Hero paragraph:** {}".format(words(p["lead"]["launch"])),
        "**Hero, above the button:** add an **Image** block with Apple's “{}” badge, from Apple's "
        "marketing resources, linked to the app's App Store page. Use Apple's artwork as "
        "supplied.".format(badge),
        "**Questions:** " + " ".join(
            ["delete “{}”.".format(words(i["question"])) for i in soon_only]
            + ["Under “{}”, the answer becomes: {}".format(words(i["question"]),
                                                           words(i["answers"]["launch"]))
               for i in changed]),
        "**Section 7:** the heading becomes **{}**, and the text: {}".format(
            words(p["contact"]["launch"]["title"]), words(p["contact"]["launch"]["text"])),
    ]
    add("\n".join("{}. {}".format(n, step) for n, step in enumerate(steps, 1)) + "\n")
    add(then(p["lead"]["launch"], p["contact"]["launch"]["text"]))
    return "\n".join(piece for piece in out if piece).rstrip("\n") + "\n"


# ---- The tour's coming-soon line and its closing section, and the site's footer: small blocks

# The line stands alone in a section of its own, above the tour's first block, so it carries what
# it needs and no more. A <div>, since a site's theme has rules for a paragraph.
_TOUR_LINE = """\
<style>
.frus-tour-line {{ box-sizing: border-box; display: flex; flex-wrap: wrap; gap: 4px 12px; align-items: baseline; margin: 0; padding: 10px 16px; background: {tint}; border: 1px solid {rule}; border-radius: 4px; font-family: {sans}; font-size: 14.5px; font-weight: 400; font-style: normal; line-height: 1.5; letter-spacing: normal; text-transform: none; text-align: left; color: {ink}; }}
.frus-tour-line b, .frus-tour-line span {{ font-family: inherit; font-size: inherit; font-style: inherit; line-height: inherit; letter-spacing: inherit; text-transform: inherit; color: inherit; }}
.frus-tour-line b {{ color: {red}; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; font-size: 12px; }}
</style>
<div class="frus-tour-line"><b>{label}</b><span>{line}</span></div>"""

# What the closing section uses of the tour's stylesheet: its variables, these, and its own
# classes. The two large blocks leave those classes behind, so the rules do not meet.
_CLOSE_DROPPED = re.compile(r"^(html|body)(?![\w-])|^:root\[")
_CLOSE_BASE = (":root", "*", "h1", "h2", "h3", "p", "a", "a:focus-visible", "code", ".mono", ".inner")
_CLOSE_OWN = re.compile(r"\.(close|cta|btn)(?![\w-])")
_CLOSE_FITTED = """\
{s} .inner {{ padding-left: 0; padding-right: 0; }}
{s} .close {{ margin-top: 0; }}"""

# The footer is the site's own, so its type and colour stay the site's: a theme colours a
# footer's text paragraph by paragraph, and a colour set here would not follow a dark one. Its
# links are underlined here, since a theme leaves a link in a Code Block as plain as the words
# around it (seen on the site, 2026-11-10; Scripts/build_website_pages.py has the measurement).
_FOOTER = """\
<style>
.frus-foot p {{ font-size: 13px; line-height: 1.55; margin: 0 0 8px; text-align: left; }}
.frus-foot .frus-foot-links {{ display: flex; flex-wrap: wrap; gap: 4px 16px; margin: 0; }}
.frus-foot a {{ text-decoration: underline; }}
</style>
<div class="frus-foot">
<p>{disclaimer}</p>
<p>{nara}</p>
<p class="frus-foot-links">{links}</p>
</div>"""


def tour_variables(tour):
    """The tour's own colours and faces, by name, from its stylesheet's first :root block."""
    root = one(r":root \{(.*?)\}", between(tour, "<style>", "</style>", "tour.html"),
               "light :root block in the tour's stylesheet")
    return {name[2:]: " ".join(value.split()) for name, value in re.findall(r"(--[\w-]+):\s*([^;]+);", root)}


def tour_banner(tour):
    """The words of the tour's coming-soon banner: its label and its line."""
    return one(r'<div class="soon-banner" data-show="soon">\s*<div class="inner"><b>(.*?)</b>'
               r"<span>(.*?)</span></div>", tour, "coming-soon banner in tour.html")


def tour_closings(tour):
    """The tour's closing section in each version: what its one column holds."""
    close = one(r'<section class="close".*?</section>', tour, "closing section in tour.html")
    states = dict(re.findall(r'  <div class="inner" data-show="(soon|launch)">\n(.*?)\n  </div>', close, re.S))
    if set(states) != {"soon", "launch"}:
        raise OutOfShape("tour.html: its closing section has no coming-soon and launch halves")
    return states


def tour_small_blocks():
    """The tour's coming-soon line, and its closing section in each version, by file name."""
    tour = TOUR.read_text(encoding="utf-8")
    source = "Planning/website-drafts/tour/tour.html"
    label, line = tour_banner(tour)
    values = tour_variables(tour)
    out = {"tour-coming-soon-line.txt": stamped(
        _TOUR_LINE.format(label=label, line=line, **{k: values[k] for k in ("tint", "rule", "sans", "ink", "red")}),
        "/tour", source + ", its coming-soon line")}

    style = scoped_style(between(tour, "<style>", "</style>", "tour.html"), SCOPE, "18px", _CLOSE_DROPPED,
                         _CLOSE_FITTED, kept=lambda s: s in _CLOSE_BASE or bool(_CLOSE_OWN.search(s)),
                         what="tour's stylesheet")
    for state, inner in tour_closings(tour).items():
        # "Get the app" goes to the App Store once the app has an address there, and until then
        # to the home page, whose badge does.
        inner = inner.replace('href="https://frusexplorer.app"', 'href="{}"'.format(APP_STORE_URL or "/"))
        inner = re.sub(r'href="(https://frusexplorer\.app/[^"]*)"',
                       lambda m: 'href="{}"'.format(site_path(m.group(1))), inner)
        inner = inner.replace(' target="_blank" rel="noopener"', "")
        for address in bwp.ADDRESSES:
            inner = inner.replace(address, '<a href="mailto:{0}">{0}</a>'.format(address))
        if 'id="close-h"' not in inner:
            inner, headed = re.subn(r"<h2>", '<h2 id="close-h">', inner, count=1)
            if headed != 1:
                raise OutOfShape("tour.html: the {} closing has no heading".format(state))
        for leftover in ("data-show", "frusexplorer.app/", "target=", "<script", "<iframe", "<button"):
            if leftover in inner:
                raise OutOfShape("tour.html: {!r} is left in its {} closing".format(leftover, state))
        version = "coming-soon" if state == "soon" else "launch"
        payload = ('{}\n<div class="frus-tour">\n\n<section class="close" aria-labelledby="close-h">\n'
                   '  <div class="inner">\n{}\n  </div>\n</section>\n\n</div>').format(style, inner)
        out["tour-closing-{}.txt".format(version)] = stamped(
            payload, "/tour", "{}, its closing section, {} version".format(source, version))
    return out


def footer_links():
    """The preview's footer links, as (text, address on the site)."""
    return [(text, site_path(href)) for href, text in re.findall(
        r'<a href="([^"]*)">(.*?)</a>',
        one(r'<nav aria-label="Footer">(.*?)</nav>', site.SHELL, "footer links"))]


def footer_block():
    """The site's footer, shared by every page: the disclaimer, the National Archives sentence
    and the links, as the preview's shell has them."""
    links = "".join('<a href="{}">{}</a>'.format(address, text) for text, address in footer_links())
    payload = _FOOTER.format(disclaimer=html.escape(site.DISCLAIMER, quote=False),
                             nara=html.escape(site.NARA, quote=False), links=links)
    return {"footer.txt": stamped(payload, "", "Planning/website-drafts/build_site.py, the footer "
                                  "of every page")}


# ---- The guide's chapters on the tour and the footer

def tour_chapter():
    tour = TOUR.read_text(encoding="utf-8")
    film = one(r'<figure class="film">(.*?)</figure>', tour, "film in tour.html")
    caption = one(r"<figcaption><span class=\"sn\">Film</span>(.*?)</figcaption>", film, "film caption")
    poster = one(r'<video[^>]*poster="([^"]*)"', film, "film's poster")
    closings = tour_closings(tour)
    title = {state: words(one(r"<h2[^>]*>(.*?)</h2>", body, "closing heading")) for state, body in closings.items()}
    button = words(one(r'<a class="btn"[^>]*>(.*?)</a>', closings["launch"], "launch button"))
    pill = words(one(r'<span class="btn soon"[^>]*>(.*?)</span>', closings["soon"], "coming-soon pill"))
    out = []
    add = out.append
    add("| Section | Block | What goes in it |\n|---|---|---|\n"
        "| 1, coming soon only | Code | all of [paste/tour-coming-soon-line.txt](paste/tour-coming-soon-line.txt) |\n"
        "| 2 | Code | all of [paste/tour-block-1.txt](paste/tour-block-1.txt) |\n"
        "| 3, optional | Video | the film: upload [{0}]({0}) ({1:.1f} MB) |\n"
        "| 4 | Code | all of [paste/tour-block-2.txt](paste/tour-block-2.txt) |\n"
        "| 5 | Code | all of [paste/tour-closing-coming-soon.txt](paste/tour-closing-coming-soon.txt) |\n"
        .format(FILM, (HERE / FILM).stat().st_size / 1e6))
    add("**Section 3, the film.** Add Block ▸ **Video**, the block's pencil, then **Upload file**. "
        "Leave **Autoplay** off and the player's controls on. For the frame shown before it plays, "
        "turn on **Custom featured image** and upload [tour/{0}](tour/{0}). In the editor's "
        "**Description** field, which shows under the film as its caption:\n".format(poster))
    add(quoted(words(caption)) + "\n")
    add("**On release day, change two things.**\n")
    add("1. **Section 1:** delete it.\n"
        "2. **Section 5:** paste all of [paste/tour-closing-launch.txt](paste/tour-closing-launch.txt) "
        "over what its block holds. Its heading becomes *{}*, where it was *{}*; it says the app is "
        "free, where it said it will be; and a **{}** button stands where the outlined “{}” did. {}\n".format(
            title["launch"], title["soon"], button, pill,
            "The button goes to <{}>.".format(APP_STORE_URL) if APP_STORE_URL else
            "The button goes to the home page, whose badge goes on to the App Store; once "
            "`APP_STORE_URL` is set in `build_paste.py` it goes there itself."))
    return "\n".join(piece for piece in out if piece).rstrip("\n") + "\n"


def footer_chapter():
    """What the footer holds either way, and its words and links for the footer's own Text
    block: the guide's way B, for a footer that offers no Add Block."""
    links = footer_links()
    rows = ["| {} | {} |".format(text, "`{}`, typed in full".format(address) if "://" in address
                                 else "your page at `{}`".format(address))
            for text, address in links]
    out = ["Either way the footer holds, word for word, the store listing's disclaimer and the "
           "National Archives sentence, and under them {} links.\n".format(
               {5: "five"}.get(len(links), len(links))),
           "**The words**, for way B's step 2:\n",
           quoted(site.DISCLAIMER, site.NARA, " · ".join(text for text, _ in links)) + "\n",
           "**The links**, for way B's step 4:\n",
           "| Select | Link it to |\n|---|---|\n" + "\n".join(rows) + "\n"]
    return "\n".join(out)


def home_paste_chapter():
    """The guide's lines on the home page's two pastes: which goes in when, what the second
    changes, and what it still waits for."""
    p = home_parts()
    gone = [i for i in p["questions"]["faq"] if i["only"] == "soon"]
    changed = [i for i in p["questions"]["faq"] if "launch" in i["answers"]]
    pill = words(one(r'<span class="pg-btn soon">(.*?)</span>', p["cta"]["soon"], "coming-soon pill"))
    out = ["| When | What the Code Block holds |\n|---|---|\n"
           "| Now | all of [paste/home-coming-soon.txt](paste/home-coming-soon.txt) |\n"
           "| Release day | all of [paste/home-launch.txt](paste/home-launch.txt), pasted over it |\n",
           "The launch version differs from the first in six places, and in nothing else:\n",
           "\n".join("{}. {}".format(n, line) for n, line in enumerate([
               "the coming-soon line at the top is gone;",
               "the label over the headline reads *{}*, where it read *{}*;".format(
                   words(p["kicker"]["launch"]), words(p["kicker"]["soon"])),
               "the opening paragraph no longer says the app is coming soon;",
               "Apple's “Download on the App Store” badge, linked to the app's page there, stands "
               "where the outlined “{}” did;".format(pill),
               "under *{}*, {} and {};".format(
                   words(p["questions"]["title"]),
                   " and ".join("*{}* is gone".format(words(i["question"])) for i in gone),
                   " and ".join("*{}* answers *{}*".format(words(i["question"]),
                                                             words(i["answers"]["launch"]))
                                for i in changed)),
               "the last section is *{}*, where it was *{}*.".format(
                   words(p["contact"]["launch"]["title"]), words(p["contact"]["soon"]["title"])),
           ], 1)) + "\n"]
    if APP_STORE_URL:
        out.append("The badge links to <{}>. It is Apple's own artwork, loaded from Apple's "
                   "marketing toolbox.\n".format(APP_STORE_URL))
    else:
        out.append("**The launch file is not ready yet.** Its badge has to link to the app's page on "
                   "the App Store, an address the app has only once it is approved: "
                   "`https://apps.apple.com/app/id` followed by the app's Apple ID, which App Store "
                   "Connect shows under **App Information**. Until then the file holds `{0}` in its "
                   "place, says *NOT READY* on its first line, and shows a notice in a dashed box at "
                   "the top of the page, so a paste of it cannot pass for the finished page.\n"
                   .format(APP_STORE_PLACEHOLDER))
        out.append("On release day, give the address to a session, or set `APP_STORE_URL` near the "
                   "top of `build_paste.py` yourself and run "
                   "`python3 Planning/website-drafts/build_paste.py`. The file it then writes has the "
                   "address, no notice and a new fingerprint: paste that one.\n")
        out.append("The badge itself is Apple's own artwork, loaded from Apple's marketing toolbox, "
                   "so there is nothing to upload.\n")
    return "\n".join(out)


# Where each paste goes, in the order the guide enters them.
_GOES_IN = [
    ("privacy.txt", "`/privacy`"),
    ("support.txt", "`/support`"),
    ("quick-start-ios.txt", "`/quick-start-ios`"),
    ("quick-start-mac.txt", "`/quick-start-mac`"),
    ("footer.txt", "the footer of every page"),
    ("home-coming-soon.txt", "`/`, until release day"),
    ("home-launch.txt", "`/`, from release day"),
    ("tour-coming-soon-line.txt", "`/tour`, section 1, until release day"),
    ("tour-block-1.txt", "`/tour`, section 2"),
    ("tour-block-2.txt", "`/tour`, section 4"),
    ("tour-closing-coming-soon.txt", "`/tour`, section 5, until release day"),
    ("tour-closing-launch.txt", "`/tour`, section 5, from release day"),
]


def kit_chapter(pastes):
    if sorted(name for name, _ in _GOES_IN) != sorted(pastes):
        raise OutOfShape("the kit's files and the table of where each goes have parted: {}".format(
            sorted(set(pastes) ^ {name for name, _ in _GOES_IN})))
    rows = ["| File | Goes in | Size | Fingerprint |", "|---|---|---|---|"]
    for name, where in _GOES_IN:
        text = pastes[name]
        waiting = ", not ready: it waits for the App Store address" if "NOT READY" in text.split("\n", 1)[0] else ""
        rows.append("| [paste/{0}](paste/{0}) | {1} | {2:,} bytes | `{3}`{4} |".format(
            name, where, len(text.encode("utf-8")), fingerprint(text), waiting))
    return "\n".join(rows) + "\n"


# ---- The review sheet's two frames, from the drafts

def sheet_frame(draft, prefix):
    """A draft as page-drafts.html shows it: the repository script's HTML, with its headings'
    ids kept apart from the sheet's own and its links pointed within the sheet."""
    source = "Planning/website-drafts/" + draft
    out = bwp.body((HERE / draft).read_text(encoding="utf-8"), source)
    out = out.replace('<h2 id="', '<h2 id="{}-'.format(prefix))
    out = out.replace('href="#', 'href="#{}-'.format(prefix))
    out = out.replace('href="https://frusexplorer.app/privacy"', 'href="#pg-privacy"')
    out = out.replace('href="https://frusexplorer.app/support"', 'href="#pg-support"')
    out = re.sub(r'href="https://frusexplorer\.app/(quick-start-(?:ios|mac))"',
                 r'href="site/\1.html" target="_blank" rel="noopener"', out)
    out = re.sub(r'<a href="(https://[^"]+)">', r'<a href="\1" target="_blank" rel="noopener">', out)
    return out.replace("<p><strong>Coming soon.</strong>",
                       '<p data-show="soon" class="pg-soonline"><strong>Coming soon.</strong>')


def sheet_markdown(draft, record):
    """What replaces a copy of record when its draft is folded in: the copy's own header comment,
    then the draft's text."""
    header = one(r"\A(<!--.*?-->)", (REPO / record).read_text(encoding="utf-8"), "header of " + record)
    body = re.sub(r"\A<!--.*?-->\s*", "", (HERE / draft).read_text(encoding="utf-8"), flags=re.S)
    return html.escape(header + "\n\n" + body)


def sheet(text):
    for key, draft, prefix, record in (("support", "Support-draft.md", "sp", "Docs/Support.md"),
                                       ("privacy", "Privacy-Policy-draft.md", "pv", "Docs/Privacy-Policy.md")):
        frame = re.compile(r'(<section class="work" id="pg-{}".*?<div class="frame-body"><div class="pg-doc">\n)'
                           r"(.*?)(\n        </div></div>)".format(key), re.S)
        source = re.compile(r'(<pre class="src" id="md-{}">)(.*?)(</pre>)'.format(key), re.S)
        for pattern, value in ((frame, "\n" + sheet_frame(draft, prefix) + "\n"),
                               (source, sheet_markdown(draft, record))):
            if len(pattern.findall(text)) != 1:
                raise OutOfShape("page-drafts.html: the {} frame or its Markdown was not found once"
                                 .format(key))
            text = pattern.sub(lambda m, v=value: m.group(1) + v + m.group(3), text)
    # The Home frame is the draft's own text, kept by hand: say so when the two part.
    frame = between(text, 'id="home-frame">', '<footer class="pg-foot">', "page-drafts.html's Home frame")
    home = re.sub(r"<!--.*?-->\s*", "", HOME.read_text(encoding="utf-8"), count=1, flags=re.S)
    home = re.sub(r'<aside class="rv" data-rv>.*?</aside>', "", home, count=1, flags=re.S)
    if site.plain(frame).split() != site.plain(home).split():
        raise OutOfShape("page-drafts.html's Home frame no longer reads as site-src/home.html does: "
                         "copy the draft's sections into the frame")
    return text


# ---- The guide's generated parts

def filled(text, name, content):
    start, end = "<!-- generated:{} -->".format(name), "<!-- /generated:{} -->".format(name)
    if text.count(start) != 1 or text.count(end) != 1:
        raise OutOfShape("Squarespace-Entry.md: the markers for its {!r} part were not found once"
                         .format(name))
    head, rest = text.split(start)
    return head + start + "\n\n" + content.strip("\n") + "\n\n" + end + rest.split(end)[1]


def outputs():
    """Every file this script keeps, by path, as it should read."""
    pastes = dict(docs_pastes(), **tour_blocks())
    pastes.update(home_blocks())
    pastes.update(tour_small_blocks())
    pastes.update(footer_block())
    for name, text in pastes.items():
        if len(text.encode("utf-8")) > CODE_BLOCK_LIMIT:
            raise OutOfShape("paste/{} is {:,} bytes, over a Code Block's 400 KB".format(
                name, len(text.encode("utf-8"))))
    out = {PASTE / name: text for name, text in pastes.items()}
    guide = GUIDE.read_text(encoding="utf-8")
    for name, content in (("home-paste", home_paste_chapter()), ("home", home_chapter()),
                          ("tour", tour_chapter()), ("footer", footer_chapter()),
                          ("kit", kit_chapter(pastes))):
        guide = filled(guide, name, content)
    out[GUIDE] = guide
    out[SHEET] = sheet(SHEET.read_text(encoding="utf-8"))
    return out


def stale():
    """The files that are not what their sources make, by path relative to the repository."""
    return [str(path.relative_to(REPO)) for path, text in outputs().items()
            if not path.exists() or path.read_text(encoding="utf-8") != text]


def main(argv):
    check = "--check" in argv[1:]
    try:
        wanted = outputs()
    except OutOfShape as problem:
        print("build_paste.py: {}".format(problem))
        return 2
    behind = []
    for path, text in wanted.items():
        if path.exists() and path.read_text(encoding="utf-8") == text:
            continue
        behind.append(str(path.relative_to(REPO)))
        if not check:
            path.parent.mkdir(exist_ok=True)
            path.write_text(text, encoding="utf-8")
            print("wrote {}".format(path.relative_to(REPO)))
    extra = sorted(p.name for p in PASTE.glob("*") if p not in wanted) if PASTE.exists() else []
    if extra:
        print("paste/ holds files this script does not write: {}".format(", ".join(extra)))
        return 1
    if check and behind:
        print("out of step with its sources: {} (run Planning/website-drafts/build_paste.py)".format(
            ", ".join(behind)))
        return 1
    if check:
        print("the paste kit, the guide and the review sheet are in step")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
