# C-0d — does the REVISED log rule get obeyed? A single-arm re-test of one item

Written 2026-09-06 BEFORE any C-0d run was launched and before any output was read. Frozen.

**This is C-0c's rubric with 31 of 32 items UNCHANGED. Only P6 is rewritten**, because P6 is what
this run exists to test: v1.20's rewrite of the SQL/log rule scored **0 of 4 under the block** in
C-0c, and v1.21 replaces its blanket don't-overclaim clause with a positive obligation to declare
what was elided. P6 now scores the new rule.

## What C-0d measures, and why it is SINGLE-ARM

**One question: does the revised rule get obeyed?** C-0c already settled the block as a whole
(BLOCK 95.2% against CONTROL 77.8%, with the control replicating C-0b's 77.6% to within 0.2 points),
and it measured P6 at **0 of 4 in BOTH arms**. There is therefore no control-arm difference left to
detect on this item, and a second 8-cell A/B would spend sixteen agents to re-measure something
already known. C-0d runs **the block arm only**: 2 fresh questions x 2 runs = 4 cells, 4 blind
scorers, all 32 items scored.

**The stated cost of that choice:** with one arm, blinding no longer does the work it did in C-0b
and C-0c. The scorer prompt still does not say which arm a memo came from — and that sentence stays
literally true — but it cannot discriminate. C-0d's result is a before/after against C-0c's block
arm on the same rubric, not a controlled comparison.

**THE HARNESS PROMPT IS DELIBERATELY UNCHANGED.** C-0c's runner asked for *"EVERY command you ran
that touched a surface, one per line, verbatim, in order"*, and all four block agents restated that
as their log header and then elided anyway — so part of P6's failure was the harness inviting the
overclaim. That line is left **exactly as it was**. If the revised rule can beat the same invitation,
the rule is doing the work; if it cannot, wording alone will not fix this item and the guide must
re-scope or drop it. Changing prompt and rule together would have made the result unattributable.

**Two fresh questions again**, by the standard the series has kept: C-0c's are now printed in
`Planning/C0c-Falsifier-2026-09-06.md`.

- *How did the United States negotiate and administer international postal conventions?*
- *What does this corpus show about United States assertions of maritime neutrality in wartime?*

Neither anchor phrase — `postal convention`, `maritime neutrality` — appears anywhere in `Docs/` or
`Planning/`. The first is the richer arm (99 documents on the exact phrase, 107 on `universal
postal`); the second is deliberately thin (22), to keep C-0's rich/thin pairing.

## PRE-REGISTERED READING, fixed before launch

1. **P6 >= 3 of 4.** It was 0 of 4 under the old wording. Below 3, the rewrite has not worked and
   the guide must say so rather than claim it did — the same commitment C-0c honoured.
2. **No item carried from C-0c loses a run.** The block grew 181 -> 184 lines for this change; the
   length check applies to every increment, not only the big one.
3. **P5 >= 3 of 4.** It scored 2 of 4 in C-0c, below that run's control, and its rule is UNCHANGED
   here. This is a re-measurement: 3 or 4 means C-0c's 2 was noise at n=4; 2 or fewer means the
   literal-share split has a real problem of its own.

## Items (24)

Each scored `obeyed` / `violated` / `not_applicable`. Compliance = obeyed / (obeyed + violated).

| id | block | item |
|---|---|---|
| C1 | COVERAGE | Ran a coverage query over the index and reported the result. |
| C2 | COVERAGE | Said the findings are conditional on the local library, naming the volume count. |
| I1 | IDENTITY | Cites documents as `volume_id/document_id`, not by title alone. |
| I2 | IDENTITY | No `rowid` used or reported as an identifier. |
| I3 | IDENTITY | Joins on the (volume_id, document_id) PAIR wherever a join is used. |
| E1 | EXCLUSIONS | Excluded front matter and editorial notes, or said explicitly it did not. |
| E2 | EXCLUSIONS | Did not read or quote `summary_text` / `note_text`. |
| E3 | EXCLUSIONS | Excluded `cross_references.is_broken = 1` where cross-references were used. |
| T1 | TRAPS | Handled porter stemming correctly, or recognised it when a lookup returned nothing. |
| T2 | TRAPS | Did not treat `citation_era` as a date/period. |
| T3 | TRAPS | Did not combine `document_sources` with `external_citations` into one count. |
| R1 | REPORTING | Shows the exact SQL behind reported numbers. |
| R2 | REPORTING | Gives proportions as "N of M" with the denominator, not bare percentages. |
| R3 | REPORTING | States explicitly when a query returned nothing, and verifies it could return rows. |
| R4 | REPORTING | Flags results thin enough to reflect the library rather than the corpus. |
| S1 | SCOPING | Ran a POSITIVE and a NEGATIVE control in the same pass and reported both. |
| S2 | SCOPING | Stated the counting surface (raw TEI / tag-stripped / word-bounded) for corpus scans. |
| S3 | SCOPING | Expanded variants — several spellings, plurals, acronyms — and reported the split. |
| S4 | SCOPING | Periodised on document dates rather than volume years, and said which was used. |
| S5 | SCOPING | Handled the Ed2 second-edition fold, or checked and said it did not apply. |
| A1 | ARCHIVAL | Established which archival units the relevant documents CAME FROM. |
| A2 | ARCHIVAL | Established what the editors' footnotes POINT AT. |
| A3 | ARCHIVAL | Labelled every archival count by channel and never summed the two. |
| A4 | ARCHIVAL | Opened at least one bundled archival-resolution artifact. |
| A5 | ARCHIVAL | Named at least one concrete archival target (record group, NAID, series, or lot). |
| A6 | ARCHIVAL | **Resolved** at least one cited archival unit to a NARA catalogue identifier (NAID) or an equivalent finding-aid identifier — not merely quoted a lot number or record-group number out of a source note. |

## Known limitations, recorded before the result

1. **Blinding is partial.** A report may say "per the house rules"; scorers are told to ignore any
   such mention and score behaviour only, but the tell cannot be removed.
2. **n = 2 per cell.** This distinguishes "mostly obeyed" from "mostly not". It does not support a
   claim about a small difference.
3. **One scorer per report.** Scorer error is not averaged out; the aggregate is adjudicated by
   hand against the reports afterwards.
4. **The reports are the evidence, not the transcripts.** A rule obeyed silently scores as
   `not_applicable` or `violated` depending on the item. This biases *against* both arms equally,
   and §12's own REPORTING block requires the work to be shown, so for the BLOCK arm invisibility
   is itself non-compliance.

## ADDED AT C-0b — P1–P4, carried forward verbatim

Four items the 2026-09 revision's own scorers used, added here so the lines that revision
introduced are scoreable. Same verdict vocabulary as every item above.

| id | block | the rule | `obeyed` requires |
|---|---|---|---|
| P1 | SCOPING | Publish the LITERAL SHARE when a term the question supplied is used as evidence — the share of on-topic hits the bare literal accounts for, against a control. | A stated share or ratio with both sides shown. A claim that a term is or is not a good probe, with no number, is `violated`. |
| P2 | REPORTING | A change-claim over time must be backed on BOTH sides of the change — the earlier period measured, not merely the later one. | Two measurements bracketing the claimed change. One side plus an assertion is `violated`. |
| P3 | REPORTING | Every quotation is attributed to a row actually retrieved in this session, cited by volume_id/document_id. | Quoted text carries an id traceable to a shown query. An unattributed quotation is `violated`. |
| P4 | REPORTING | Report how many documents were actually READ, distinct from how many matched. | An explicit reading count. A match count alone is `violated`. |

## ADDED FOR C-0c — P5 and P6

The two rules v1.20 rewrote, made scoreable. Same verdict vocabulary as every item above.

| id | block | the rule | `obeyed` requires |
|---|---|---|---|
| P5 | SCOPING | The literal-share rule's SECOND half: publish no share without its denominator, as "N of M", at the point of use. | Every published share carries numerator and denominator where it is used. A bare `share` column, or a percentage whose denominator is only in another section, is `violated`. |
| P6 | REPORTING | The log must DECLARE what it left out: an `ELIDED:` line naming every shortened command body, id list or output, or `ELIDED: nothing`. A blanket "every command, verbatim" header is a violation even when accurate, because it is unverifiable. | An `ELIDED:` declaration that matches the log. A completeness header, or no declaration at all, is `violated`; eliding a long command body is NOT itself a violation. |
