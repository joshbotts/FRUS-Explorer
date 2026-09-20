# FRUS TEI — structural encoding defects found by an independent scan

Generated 2026-09-20 against the corpus at commit `550a8c5c5`. **Every line and byte offset below is relative to that revision.**

## What this is

We maintain [FRUS Explorer](https://github.com/joshbotts/FRUS-Explorer), an independent reader that parses your TEI. Scanning all 744 files (339,389 `<div>` elements) for structural consistency turned up **23 places in 18 volumes** where a `</div>` appears to sit in the wrong place, nesting material one level deeper than the printed book puts it.

**Every one of these files is well-formed, and every `</div>` count balances.** The closing tag is simply written after the divisions it should close before, so no XML validator, no schema and no ODD can see any of it — which is presumably why it has gone unnoticed. It follows that **every correction below is a move, never an insertion**: the tag count does not change.

## How each row was checked

A row is `confirmed` only when two independent things agree AND the repair has been simulated: the edit is applied to a scratch copy, the file is re-parsed, and the rule that fired is checked to be silent afterwards. **5 of 23** rows meet that bar. The rest are offered as questions, marked `please-verify-against-print`.

The strongest check available is the volume's own printed table of contents: where it prints two headings at the same level, the book itself says they are siblings. 473 of 744 files carry a machine-readable contents list.

## What this scan does NOT claim

- **It is not complete.** It finds a tag displaced *later* — material absorbed into its predecessor — and, through the id grammar, some displaced *earlier*. Other shapes exist that these rules cannot see.
- **It is not series-wide in practice.** Modern FRUS is structurally flat: most volumes after 1977 have almost no nested structure for this scan to test, so a clean result there says nothing about their quality.
- **Where the findings concentrate, the adjudicator is weakest.** The older volumes hold most of these, and they are the least likely to carry a machine-readable contents list. 5 row(s) are marked `NO-TOC-UNADJUDICATED` and are offered as questions rather than assertions.
- **It says nothing about whether a `<ref target>` resolves.** That is a separate scan.
- The one clean NEGATIVE, measured by this same run: across all 744 files the scan finds **0 duplicate `xml:id`** and **0 duplicate document `@n` within a volume**. The anchor layer everything else depends on is sound.

## The rows

The full set is attached as `structure-sweep.csv`, one row per fix site, with a `corrected_encoding` column stating each edit precisely enough to apply by hand. The confirmed rows:

| Volume | Element | What is wrong | The edit |
|---|---|---|---|
| `frus1873p1v2` | [`ch5subsubch16`](https://history.state.gov/historicaldocuments/frus1873p1v2/ch5subsubch16) | one </div> sits after the divs it should close before, so 9 divs are nested one level too deep: ch5subsubch16 (R6-id-level), ch5subsubch17 (R6-id-level), ch5subsubch18 (R6-id-level), ch5subsubch19 (R6-id-level), ch5subsubch20 (R6-id-level), ch5subsubch21 (R6-id-level), ch5subsubch22 (R6-id-level), ch5subsubch23 (R6-id-level), ch5subsubch24 (R6-id-level) | move the </div> at line 61318 to line 58025, immediately before <div xml:id="ch5subsubch16">; tag count unchanged |
| `frus1943CairoTehran` | [`ch12subsubch24`](https://history.state.gov/historicaldocuments/frus1943CairoTehran/ch12subsubch24) | one </div> sits after the divs it should close before, so 2 divs are nested one level too deep: ch12subsubch24 (R3-session-in-session) | move the </div> at line 71095 to line 71015, immediately before <div xml:id="ch12subsubch24">; tag count unchanged |
| `frus1945Berlinv02` | [`ch7subch3`](https://history.state.gov/historicaldocuments/frus1945Berlinv02/ch7subch3) | a session inside another session: “Meeting of the Combined Chiefs of Staff, 3:30 p.m.” (ch7subch3, subchapter) sits inside “Meeting of the Joint Chiefs of Staff, 12:15 p.m.” (ch7subch2, subchapter) — and 4 further div(s) at the same level are absorbed by the same tag | move the </div> at line 47016 to line 45167, immediately before this div; tag count unchanged |
| `frus1945Malta` | [`ch8subch22`](https://history.state.gov/historicaldocuments/frus1945Malta/ch8subch22) | one </div> sits after the divs it should close before, so 6 divs are nested one level too deep: ch9 (R1-rank), ch8subch23 (R2-day-in-day), ch8subch31 (R2-day-in-day), ch8subch40 (R2-day-in-day), ch8subch45 (R2-day-in-day), ch8subch22 (R3-session-in-session) | move the </div> at line 94240 to line 71605, immediately before <div xml:id="ch8subch22">; tag count unchanged |
| `frus1949v07p2` | [`comp2`](https://history.state.gov/historicaldocuments/frus1949v07p2/comp2) | structural rank violation: “East Asian-Pacific area” (comp2, compilation) sits inside “Northeast Asia:” (comp1, compilation) | move the </div> at line 48905 to line 41483, immediately before this div; tag count unchanged |

## Worth naming separately

Where a single displaced tag explains several symptoms, this report says so in one row rather than repeating the same edit: the tool applies each candidate move to a scratch copy and keeps the one that takes the whole volume to zero violations.

We are not asking for anything but the correction, and we would rather hear that a row is wrong than not hear at all — each one names what we checked, so it should be quick to dismiss the ones that are deliberate.
