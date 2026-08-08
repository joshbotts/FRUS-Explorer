# M1a findings — the gate measurements for the early-era people program (#234)

Run: `python3 Planning/early-era-people/m1a_survey.py` (deterministic, seed 234, read-only).
Artifacts: `m1a-survey.json` (machine), `m1a-eval-candidates.csv` (300 rows for hand-keying).
Measured 2026-08-07 against the 552-volume manifest, the local TEI corpus, and the POCOM checkout.

---

## The headline: M2 (detection) is **not** optional

`Planning/People-Early-Era-Program.md` said the core problem looked like *reconciliation, not
detection*, with an explicit caveat that markup coverage was unmeasured and that the answer would
size the program. **It is now measured, and it goes the other way.**

Across a stratified 12-volume sample, taking each volume's 25 most-frequent marked-up surnames and
counting how often those same surnames appear in body text *outside* any `<persName>`:

| band | volumes | markup share |
|---|---|---|
| 1861–1899 | frus1872p1 / frus1867p2 / frus1895p1 | 66.0% / 33.2% / 27.5% |
| 1900–1929 | frus1904 / frus1924v02 / frus1929v02 | 44.3% / 51.1% / 45.1% |
| 1930–1945 | frus1942v05 / frus1937v02 / frus1938v01 | 41.5% / 47.0% / 44.9% |
| 1946– | frus1948v05p2 / frus1948v06 / frus1949v06 | 12.4% / 31.3% / 17.8% |
| **pooled** | 10,682 marked / 20,739 unmarked | **34.0%** |

**Roughly two-thirds of person mentions in these volumes carry no markup at all**, and coverage
*degrades* in the later volumes. The editors mark up the correspondence apparatus — the `from`/`to`
of each despatch — and leave the body prose alone.

Spot-checked, the unmarked hits are genuine mentions, not noise: telegram signature lines
(`… live in south Korea. **Marshall** 501.BB Korea/1–948 Memorandum by …`), title parentheticals
(`the Under Secretary of State ( **Lovett** )`), and running prose (`Mr. **Bevin** agreed that the
matter should be settled`).

> **Read this as a lower bound on markup, not a precise figure.** A bare surname regex over
> de-tagged text will also match a surname in a table of contents, an index, or a footnote
> citation, which inflates the unmarked count. The claim it supports is directional and large —
> *most mentions are unmarked* — not "exactly 66% are".

**Consequence for the plan:** M1b (reconciling the `from`/`to` names) remains a real, cheap,
high-value deliverable, but it buys the correspondence apparatus, not person coverage. Anything
promising full early-era person coverage needs M2.

---

## POCOM constrains the `from`/`to` names strongly

For each `from`/`to` name in a dated document, does POCOM know that surname, and does exactly one
of its officeholders serve in that year (±1)?

| | |
|---|---|
| `from`/`to` names in dated documents (12-volume sample) | **12,384** |
| surname known to POCOM | **83.2%** |
| **resolves to exactly one officeholder serving that year** | **63.9%** |

That is a strong prior, and it is the argument for anchoring M1b on POCOM rather than on name
strings alone.

> **This is an upper bound on precision.** The match is surname-only: a unique POCOM officeholder
> in the right year can still be the wrong person — a foreign minister, a private citizen, a
> namesake. Converting 63.9% into a real precision figure is exactly what the eval set is for.
> The 1946– volumes already show the ceiling falling (frus1948v06 resolves 38%), as correspondence
> widens beyond US chiefs of mission.

---

## The eval set — the one part that is owner work

`m1a-eval-candidates.csv` holds **300 rows** (25 per sampled volume, stratified across the four
bands): volume, document, year, role, the name as printed, its surname, and two empty columns —
`TRUE_IDENTITY_pocom_slug_or_name` and `notes`.

Nothing downstream is measurable until those are keyed by a human. That was the archived plan's
non-negotiable and it still is: an accept/reject artifact scored against a machine's own guesses
measures nothing.

---

## Two defects found while validating the survey

Both were turned up by cross-checking the TEI-derived volume split against the app's own database —
they disagreed on three volumes, and every disagreement was a bug.

### 1. Two volumes' person lists are never read
`frus1873p1v1` and `frus1873p1v2` each carry a real editor list of **57 entries**:

```xml
<div type="section" xml:id="correspondents">
  <head>List of persons whose correspondence with or from the Department of State is
        contained in this volume.</head>
  <list><item><persName xml:id="p_HF1">Hamilton Fish</persName>, Secretary of State.</item>
```

`FRUSDocumentParser.structuralKind` requires `subtype == "index"` **and**
`xml:id ∈ {persons, persname, listofpersons}`. These sections have no `subtype` and use
`xml:id="correspondents"`, so both conditions fail and 114 person entries are dropped.

### 2. A volume's back-of-book subject index is parsed as people
`frus1941-43` contributes **77 rows** to the `persons` table that are not people — `Atlantic
Islands`, `Casablanca Conference` — with page runs in the description field. They appear in the
People browser under A and C.

Neither changes the program's shape; both are small and worth fixing on their own.

---

## Reconciling two volume counts

`People-Early-Era-Program.md` says **268** volumes have no person list; this survey says **267**.
Both are right, for different questions:

- **268** = volumes where the *app currently shows no people* (from the live index).
- **267** = volumes whose *TEI carries no editor list* (from the corpus).

The difference is exactly the three defect volumes above: `frus1873p1v1`/`p1v2` have a list the app
does not read (in the app's 268, not in the TEI's 267), and `frus1941-43` has no list but has rows
the app should not have (in the TEI's 267, not in the app's 268).

---

## What M1a settles, and what it does not

| question | answer |
|---|---|
| Is detection needed? | **Yes.** ~two-thirds of mentions are unmarked, worsening in later volumes. |
| Is the `from`/`to` layer worth doing on its own? | **Yes.** 12,384 names in the sample alone, 83.2% surname-known to POCOM. |
| How precisely does POCOM resolve them? | **Unknown.** 63.9% unique-by-year is a ceiling, not a precision. |
| Does a ground-truth eval set exist? | **No.** 300 candidates are staged; keying is owner work. |

**Recommended next step: key the 300 rows.** Until then M1b's precision is unmeasured, and the
archived plan's rule — no extraction before ground truth — holds.
