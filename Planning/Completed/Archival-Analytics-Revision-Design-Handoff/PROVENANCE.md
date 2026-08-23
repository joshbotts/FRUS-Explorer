# Provenance — Archival Analytics revision design handoff

**Added to the repo:** 2026-08-10. **Source:** `Archival Analytics Review Design.zip`, supplied by
the owner. The contents here are **byte-identical to the handoff as delivered** — `README.md`,
`Archival-Analytics-Revision.dc.html` (renamed from `Archival Analytics Revision.dc.html` only to
drop the spaces), and the eleven artboards `1a`–`1k` under `screenshots/`.

## What governs

This folder is the **design** record. The **plan of record** is
`../Archival-Analytics-Adversarial-Review.md`, whose **§10** assesses this handoff against the
filed issues and records the owner's decisions on it. Where the two disagree, §10 governs — and
they do disagree in five places, because the handoff's own opening paragraph records a "later
owner pass" that added work no issue carried. §10 says where each of those five now lives.

## Two things to know before implementing from these files

**The `.dc.html` is the copy authority, not the PNGs.** Artboard 1a is drawn with its info popover
open, which occludes the middle of the denominator line, two filter chips, the top ranking row's
count, and the segmented control's caption. Every occluded string is present in the design file.

**Do not hard-code numbers from the artboards.** The `●` / `○` glyphs are the handoff's
measured/illustrative convention and are drawn *inside* UI labels on every board — they never
ship. Three drawn figures are internally inconsistent, and issue numbers, artboard ids, and
British spellings appear in otherwise copy-final strings. The full list, and the rules that
resolve it, are on issue #838.
