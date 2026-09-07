# C-0c — the v1.20 house-rules block, re-measured at 181 lines

Written 2026-09-06 BEFORE any C-0c run was launched and before any output was read. Frozen.

**This is C-0b's rubric with every item UNCHANGED, so the three experiments compare directly, plus
TWO ADDED ITEMS, P5 and P6.** C-0b's own file was C-2's rubric with P1–P4 appended and its header
and design prose were never updated — it was still titled for the long-session run and still named
that run's questions while scoring C-0b's memos. That is corrected here rather than inherited: the
design below describes THIS run.

## What C-0c measures

v1.20 rewrote two rules that failed in all eight threads of a field run, and the block grew from the
**143 lines C-0b measured at 100% against a 77.6% control** to **181**. That score does not cover
27% more text, and the guide says so in two places. This run settles it.

Design, unchanged from C-0b so the two compare directly: two questions x (block pasted | no rules)
x 2 runs, one blind scorer per memo, hard-marking instructions identical, and a per-agent
`queries.log` required in BOTH arms so the new instruction cannot itself be the treatment.

**Two fresh questions again**, because C-0b's two are now printed in the planning documents exactly
as C-0's were:

- *How did the United States pursue and negotiate rights to build and control an isthmian canal?*
- *What does this corpus show about United States participation in international sanitary
  conventions and quarantine practice?*

Neither appears in any planning document. The first is the FRUS-rich, variant-heavy arm (isthmian /
interoceanic / ship canal / Panama / Nicaragua). The second carries a deliberate false friend the
block's own SCOPING rules should catch: `quarantine` in this corpus is overwhelmingly the 1962 Cuban
naval quarantine, not public health.

## PRE-REGISTERED READING, fixed before launch

1. **Compliance holds at C-0b's level** — >= 95% overall, A6 at 4/4 in the block arm. Met means the
   longer block is still the instrument.
2. **No item carried from C-0b loses a run under the block.** A drop means the added length is
   costing attention, which is the whole risk of a 27% longer prompt.
3. **P5 and P6 — the two rewritten rules — score at the block arm's general level.** They replaced
   text that scored 0 of 8 in the field run. If they still fail under the block, the rewrite did not
   work and the guide must say so instead of claiming it did.

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
| P6 | REPORTING | Show the SQL for every number **including SQL a script ran** — or, where a number has no SQL behind it, name the script, keep its output on disk, and say which file holds which number. The log must not claim a completeness it lacks. | Predicates shown, or scripts named with their outputs and a file-to-number map. A log headed "every command, verbatim" above an elided command body or id list is `violated`. |
