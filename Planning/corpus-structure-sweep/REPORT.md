# FRUS TEI — structural encoding defects found by an independent scan

Generated 2026-10-10 against the corpus at commit `99d851c79`. **Every line and byte offset below is relative to that revision.**

## What this is

We maintain [FRUS Explorer](https://github.com/joshbotts/FRUS-Explorer), an independent reader that parses your TEI. Scanning all 744 files (339,436 `<div>` elements) for structural consistency turned up **7 places in 6 volumes** where a `</div>` appears to sit in the wrong place, nesting material one level deeper than the printed book puts it.

**Every one of these files is well-formed, and every `</div>` count balances.** The closing tag is simply written after the divisions it should close before, so no XML validator, no schema and no ODD can see any of it — which is presumably why it has gone unnoticed. It follows that **every correction below is a move, never an insertion**: the tag count does not change.

## How each row was checked

A row is `confirmed` only when two independent things agree AND the repair has been simulated: the edit is applied to a scratch copy, the file is re-parsed, and the rule that fired is checked to be silent afterwards. **0 of 7** rows meet that bar. The rest are offered as questions, marked `please-verify-against-print`.

The strongest check available is the volume's own printed table of contents: where it prints two headings at the same level, the book itself says they are siblings. 473 of 744 files carry a machine-readable contents list.

## What this scan does NOT claim

- **It is not complete.** It finds a tag displaced *later* — material absorbed into its predecessor — and, through the id grammar, some displaced *earlier*. Other shapes exist that these rules cannot see.
- **It is not series-wide in practice.** Modern FRUS is structurally flat: most volumes after 1977 have almost no nested structure for this scan to test, so a clean result there says nothing about their quality.
- **Where the findings concentrate, the adjudicator is weakest.** The older volumes hold most of these, and they are the least likely to carry a machine-readable contents list. 2 row(s) are marked `NO-TOC-UNADJUDICATED` and are offered as questions rather than assertions.
- **It says nothing about whether a `<ref target>` resolves.** That is a separate scan.
- The one clean NEGATIVE, measured by this same run: across all 744 files the scan finds **0 duplicate `xml:id`** and **0 duplicate document `@n` within a volume**. The anchor layer everything else depends on is sound.

## The rows

The full set is attached as `structure-sweep.csv`, one row per fix site, with a `corrected_encoding` column stating each edit precisely enough to apply by hand. The confirmed rows:

| Volume | Element | What is wrong | The edit |
|---|---|---|---|

## Worth naming separately

Where a single displaced tag explains several symptoms, this report says so in one row rather than repeating the same edit: the tool applies each candidate move to a scratch copy and keeps the one that takes the whole volume to zero violations.

We are not asking for anything but the correction, and we would rather hear that a row is wrong than not hear at all — each one names what we checked, so it should be quick to dismiss the ones that are deliberate.
