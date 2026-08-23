#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""The trip packet's link checker (#830, decisions D12/D19).

An OWNER-RUN release-checklist step, like notarize.sh beside it — never CI. It reads
every `RepositoryLink(url:...)` out of FRUSExplorer/TripPacket/RepositoryFactTable.swift
(the table is Swift source, not JSON, by design), fetches each URL, and reports. With
`--stamp` it rewrites the table's `confirmed` date to today WHEN AND ONLY WHEN every
checkable link passed — D12's "explicit stamp flag writes today's date onto the rows
that pass" (the table stamps all rows with one owner-confirmation date, so a partial
pass stamps nothing rather than muddying which rows were checked).

THE REDIRECT RULE IS LOAD-BEARING (D12): NARA reorganises its site, and a dead deep
link characteristically 301s to a section index that answers 200. A checker that greps
for a status code calls that a pass. So this one follows redirects, records the FINAL
url, and reports `final != declared` as NEEDS REVIEW rather than as success.

THE 403 VOCABULARY (D19): jfklibrary.org and discoverlbj.org refuse every automated
fetch (403 on real and invented paths alike), so a 403 from those hosts is
OWNER-ASSERTED — the script cannot confirm or refute the link and says so, never "dead".
And a 200 proves only that the URL resolves, not that the page still says what the
packet claims about it — that half stays genuinely owner-only (honesty rule 7).

Stdlib only, macOS's bundled python3, no pip — the tools/semantic-harvest contract.

Usage:
    python3 Scripts/check_repository_links.py            # report only
    python3 Scripts/check_repository_links.py --stamp    # stamp `confirmed` on a clean pass
"""

from __future__ import annotations   # the machines run python 3.9 — PEP 604 unions in
                                     # signatures need this to stay annotations
import re
import ssl
import sys
import urllib.request
from datetime import date, timezone, datetime
from pathlib import Path

TABLE = Path(__file__).resolve().parent.parent / \
    "FRUSExplorer/TripPacket/RepositoryFactTable.swift"

# Hosts that 403 every automated fetch, real and invented paths alike (D19's measured
# vocabulary). A 403 here is "owner-asserted", never "dead".
OWNER_ASSERTED_HOSTS = ("jfklibrary.org", "discoverlbj.org")

TIMEOUT = 20
UA = "FRUS-Explorer-link-check/1 (owner-run release checklist; see repo Scripts/)"


def links_in_table(text: str) -> list[tuple[str, str]]:
    """Every (url, label) the table declares, in source order.

    Two shapes: literal `RepositoryLink(url: "…", label: "…")` initializers (the NACP
    row), and the `library(_:_:visit:holdings:)` builder whose URLs arrive as labelled
    arguments (the ten library rows). Parsing only the first silently dropped twenty of
    twenty-three links — which is why the caller refuses an implausibly small parse.
    """
    direct = re.compile(
        r'RepositoryLink\(\s*url:\s*"([^"]+)"\s*,\s*label:\s*"([^"]+)"', re.S)
    found = list(direct.findall(text))
    builder = re.compile(
        r'library\("[^"]+",\s*"([^"]+)",\s*'
        r'visit:\s*"([^"]+)",\s*'
        r'holdings:\s*"([^"]+)"\)', re.S)
    for name, visit, holdings in builder.findall(text):
        found.append((visit, f"{name} — Plan a research visit"))
        found.append((holdings, f"{name} — Finding aids"))
    return found


def fetch(url: str) -> tuple[str, int | None, str | None]:
    """(verdict, status, final_url). Verdicts: ok / redirected / owner-asserted / dead / error."""
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    context = ssl.create_default_context()
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT, context=context) as response:
            final = response.geturl()
            status = response.status
            if final.rstrip("/") != url.rstrip("/"):
                return ("redirected", status, final)
            return ("ok", status, final)
    except urllib.error.HTTPError as error:
        if error.code == 403 and any(host in url for host in OWNER_ASSERTED_HOSTS):
            return ("owner-asserted", 403, None)
        return ("dead", error.code, None)
    except Exception as error:  # DNS, TLS, timeout — reported, never crashes the run
        return ("error", None, str(error))


def stamp_confirmed(text: str, today: date) -> str:
    """Rewrites the table's one `confirmed` DateComponents to today's date."""
    return re.sub(
        r"(year:\s*)\d{4}(,\s*month:\s*)\d{1,2}(,\s*day:\s*)\d{1,2}",
        rf"\g<1>{today.year}\g<2>{today.month}\g<3>{today.day}",
        text,
        count=1)


def main() -> int:
    stamp = "--stamp" in sys.argv
    text = TABLE.read_text(encoding="utf-8")
    links = links_in_table(text)
    # The anti-vacuity floor: the shipping table declares 23 links (3 NACP + 10×2
    # libraries). A parse well under that is broken, and a broken parse reporting "all
    # clear" is the one failure mode a checker must not have.
    if len(links) < 20:
        print(f"REFUSED: only {len(links)} links parsed from {TABLE} — the shipping "
              "table declares 23, so the parse is broken, not the table small.")
        return 2

    print(f"{len(links)} links declared in {TABLE.name} "
          f"(checked {datetime.now(timezone.utc).date().isoformat()})\n")
    needs_review = 0
    failed = 0
    asserted = 0
    for url, label in links:
        verdict, status, extra = fetch(url)
        if verdict == "ok":
            print(f"  OK             {label}\n                 {url}")
        elif verdict == "redirected":
            needs_review += 1
            print(f"  NEEDS REVIEW   {label}\n                 declared {url}\n"
                  f"                 final    {extra}\n"
                  f"                 (a dead deep link characteristically 301s to a live "
                  f"section index — check the final page still answers the label)")
        elif verdict == "owner-asserted":
            asserted += 1
            print(f"  OWNER-ASSERTED {label}\n                 {url}\n"
                  f"                 (this host 403s every automated fetch; only the owner "
                  f"can confirm it)")
        else:
            failed += 1
            print(f"  DEAD ({status if status is not None else extra})  {label}\n"
                  f"                 {url}")
    print()
    print(f"ok {len(links) - needs_review - failed - asserted} · "
          f"needs review {needs_review} · owner-asserted {asserted} · dead {failed}")
    print("A 200 proves the URL resolves, not that the page still says what the packet "
          "claims about it — read anything you have not read since the last stamp.")

    if stamp:
        if failed or needs_review:
            print("\nNOT STAMPED: the table carries one owner-confirmation date for all "
                  "rows, and a partial pass would muddy which were checked. Fix or review "
                  "the failures, then re-run --stamp.")
            return 1
        TABLE.write_text(stamp_confirmed(text, date.today()), encoding="utf-8")
        print(f"\nStamped `confirmed` to {date.today().isoformat()} in {TABLE.name}. "
              "Re-run the test suite: RepositoryLinkRenderTests pins the stamp's shape.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
