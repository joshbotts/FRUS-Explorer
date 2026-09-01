# C-0 falsifier — PRE-REGISTERED scoring rubric

Written 2026-08-31 BEFORE any run was launched and before any output was read. Frozen.

## Design

- **Question 1** (expected FRUS-rich, variant-heavy): *How did the United States handle disputes
  over fishing rights and territorial waters with other governments?*
- **Question 2** (expected FRUS-thin, archives-rich): *What role did the Department of State play
  in international narcotics control before 1970?*
- **Arm BLOCK**: the §12 house-rules block (110 lines, guide v1.10) pasted at the top of the
  session.
- **Arm CONTROL**: identical resources, identical question, identical deliverable, **no rules**.
- 2 runs per cell = 8 runner agents. Each scored by its own scorer agent, blind to the arm.

The control arm is the whole point. §14.11 recorded a zero for the archival half, but against a
different guide, different questions and no concurrent baseline — so "N of 24 rules obeyed" is
uninterpretable without a same-day arm that had no rules at all.

**What this measures**: the rules, *given that the resources are known*. Both arms are handed the
same inventory of paths, including the archival JSON. That is deliberate and it is conservative
against the block: a CLI would also make the resources known, so hiding them from the control
would have credited the block with something a tool provides anyway.

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

## Pre-registered reading of the result

- **Falsifier FIRES (build nothing)** if the BLOCK arm reaches high compliance across the board —
  and specifically if the ARCHIVAL block (A1–A5) is substantially obeyed, since that is the failure
  §14.11 measured at zero and the block was written to fix.
- **Falsifier does NOT fire (build the CLI)** if BLOCK-arm compliance stays low on the blocks a
  tool could make structural, and the CLI's subcommand list is then the set of rules that failed.
- **Neither**: if BLOCK and CONTROL are indistinguishable, the rules are doing nothing at all and
  the question becomes whether the resources alone carry the behaviour.

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
