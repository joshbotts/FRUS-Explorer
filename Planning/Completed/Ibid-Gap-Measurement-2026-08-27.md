# The bare-`Ibid.` gap, measured — #1014 step 1 (W-1)

**Status:** measurement COMPLETE and the go EXECUTED — W-1b shipped the same day (owner-confirmed): the walker is now the harvest's inheritance engine in both channels, the artifact carries 29,890 decimal references (+1,169, matching this measurement to the reference), and `currentDateIndexVersion` is 47. Measurement record follows as written. Instrument: `FootnoteIbidGapWalker`
(`SourceNoteKit/FootnoteCitationGrammar.swift`) driven by `MEASURE_IBID_GAP=1
swift run -c release ExternalCitationIndexGenerator`. Artifacts:
`Planning/ibid-gap-measurement.json` (the report) and
`Planning/ibid-gap-measurement-sample.json` (810 stratified samples, read before any number
below was trusted). Nothing bundled changed; no index version moved.

## The verdict first

**GO — with its size stated honestly.** The real gap is **1,169 references (4.1% of the
28,721-reference decimal channel)**, cleanly measurable, concentrated in exactly the files
researchers use — and **not** the pre-war rescue #834's framing suggests: the 1910–1945 band
gains **27 references (0.7%)** and the pre-1910 band **zero**. If the owner reads 4.1% as not
worth an index bump, no-go is defensible; the argument for go is that the rule is already
designed and proven (it is the lot/library channel's own, and this walker validated it against
the corpus), the samples are clean, and W-1b's cost is one grammar change plus the artifact
regen and the `external_citations` re-index (v46 → 47) the PoR already budgets.

## What was measured, and how the instrument is known honest

`classCandidates(inNote:)` takes a single note and requires the class inside the clause, so a
bare `Ibid.` is structurally invisible to it — the re-scope's diagnosis, confirmed. The walker
adds the missing cross-footnote state: a single *last-cited* slot that class candidates and
lot/library citations **compete** for in clause order (because `Ibid.` on the page means *the
source last cited*, whatever kind that was), with `FootnoteCitationScanner.scan`'s own
refusals — absence per clause, publications tested **before** `Ibid.` resolution, per-note
publication invalidation, `ibidReach = 3` — and two shadow states that price the reach cap and
refusal 3 without ever feeding the count.

Two validity checks, both exact:

- **Parity.** The walker re-derives the direct channel with the shipped guard chain as it
  walks: `28,703` in class-won clauses `+ 18` in archival-won clauses `= 28,721` — the
  artifact's own `decimalReferences`, to the reference. The walker measures the shipped
  grammar, not a nearby one. (`footnotesScanned` = 470,827, also exact.)
- **Samples.** The first run's sample file caught a real defect — a clause naming a
  publication and trailing off in `…and ibid` (`frus1948v04/d404`: "See *Foreign Relations*,
  1944, vol. iv, pp. 257–282, passim and ibid") classified as a class inheritance, when the
  page's referent is the publication. The walker tested publications *after* the bare-`Ibid.`
  branch; `scan` tests them before. Fixed to mirror `scan`'s order, pinned by a test, re-run.
  **This is the third `Ibid.` defect in this program found by reading samples and the third
  found no other way.**

## The numbers (552 shippable volumes, 314,479 documents, 470,827 body footnotes)

Of **19,843 bare standalone `Ibid.` clauses**:

| referent | count | note |
|---|---|---|
| **class the shipped rule admits — THE GAP** | **1,169** | 380 distinct keys, 113 volumes, 71 chained |
| class the shipped rule refuses | 1,952 | subjectNumeric 1,214 · noSerial 421 · notComposing 300 · notInVocabulary 15 · absence 2 |
| lot/library (existing channel's inheritance) | 1,531 | already harvested; counting it here would double-attribute |
| beyond `ibidReach` | 20 | only **5** admitted — the cap costs almost nothing |
| cleared by a publication (refusal 3) | 201 | 86 admitted — the refusal's deliberate price |
| nothing citable precedes | 14,970 | mostly publications and cross-references this grammar does not read |

Per band: **before 1910: 0** of 10 direct. **1910–1945: 27** vs 4,099 direct (0.7%).
**1946+: 1,142** vs 24,594 direct (4.6%). Distances: 0 → 426, 1 → 702, 2 → 38, 3 → 3 — 96.5%
of the gap sits in the same or the very next footnote. Top inherited keys: `751J.00` (110,
Laos), `751G.00` (71, Vietnam), `770G.00`, `762.00`, `762.0221`, `611.93` — the Indochina,
Germany, and US–China files.

Context the step-2 rule needs: **5,070 explicit-`Ibid.` references (`Ibid., Central Files,
684A.86/8–956`) are already harvested** — the class is in the clause, so the shipped rule sees
it without any state. And 957 clauses carry both an archival anchor and a class candidate, the
shapes a combined rule must not resolve silently.

## The extrapolation, retired

#1014 extrapolated ~2,600 from the lot/library channel's 9.0% inheritance rate and said of
itself it should not be quoted. Correctly: the real number is **1,169 — the extrapolation was
2.2× the truth** — because the decimal channel's bare `Ibid.`s overwhelmingly follow sources
the grammar refuses on purpose (subject-numeric files, publications) or cannot read at all.

## What step 2's rule should be, on this evidence

1. **`ibidStandsAlone` does not change.** #1014 asks whether it should admit
   `Ibid., Central Files, 684A.86/8–956`; the measurement answers that the class channel
   already harvests that form (5,070 references) because the class is written in the clause —
   the refusal only gates the *lot/library* inheritance, where it is load-bearing. Only
   **bare** standalone `Ibid.` inheritance is missing.
2. **The inheritance rule is the walker's classification, verbatim**: last-cited-wins
   competition with the archival state, publications tested before `Ibid.` resolution,
   per-note publication invalidation, reach 3, and inheritance only of a class the shipped
   admission chain would accept directly. Every piece is now corpus-validated and pinned by
   16 walker tests.
3. **If go**: regenerate `external-citation-index.json` (expect `decimalReferences`
   28,721 → ~29,890 and an inherited-count field the coverage block should disclose), bump
   `currentDateIndexVersion` 46 → 47 in the same change, and read `SAMPLE_OUTPUT` before
   trusting the run — the defect this measurement caught is the standing argument for that
   step.
