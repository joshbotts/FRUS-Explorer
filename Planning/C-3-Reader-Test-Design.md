# C-3 — the reader-facing revisions under the block, and model × effort on one question

**Status:** DESIGN, written 2026-10-14 before any run, to be frozen before the first cell launches.
The owner's four inputs arrived the same day: the question without its dates (§1), the Max 20x
plan (the budget rule), the guide edits landing before the run (so the block section is pasted
from the guide, not generated from the review), and the instruments on Fable at max (§2).
Companion to `Agentic-Guide-Accessibility-Review-2026-10-14.md` (the revisions it tests) and
successor to C-0b/C-0c (`c0c-falsifier/RUBRIC.md`, whose 24 items it carries unchanged) and C-2.
The runs are the owner's, on the Mac that holds the full index; nothing here was run.

**Two questions, one run.**

1. **Do the reader-facing revisions hold under the block?** The review's R8 adds a
   READER-FACING OUTPUT section (17 lines, six rules, in the guide since v1.29) to the §12 house-rules block and three rubric items (O1–O3). C-0c
   measured that a rule which asks for a guarantee gets the guarantee and not the behaviour; this
   run measures whether the new section gets the behaviour.
2. **Which model and effort to recommend.** The guide today says nothing about either. After this
   run its §3 gains a short table: the choice for the fastest result, for the best value, and for
   the highest quality, each with the figures it was measured on.

**The budget rule, first because it binds everything below.** The whole run, scorers, refuters and
judge included, spends no more than **25% of the owner's weekly usage allowance on the Max 20x
plan** (the owner's answer of 2026-10-14), read from `/usage` in Claude Code before the first cell
and after every cell. Cells run in a fixed order
(§3) and the run stops at the first cell whose projected cost would cross the line, with the cells
not run listed as not run. Token counts from the workflow journal are recorded beside the usage
readings, so the next run can plan from a figure rather than a guess (runbook §7).

---

## 1. The question

> *How did the United States decide whether to recognize governments that came to power by force
> in Latin America, and what did it ask of them before recognizing?*

**No dates, on the owner's decision of 2026-10-14.** The question carried "between 1930 and 1965"
in its first draft; the owner removed the boundary so that the agents establish for themselves
which examples fit. That makes §14.1's claim part of what is measured: *the scoping pass is most
of the work*, and a cell that narrows the question to the decades it knows best, or that finds the
nineteenth-century cases only under the period's own words, shows the difference between cells
that a bounded question would have hidden.

**Why this one.** C-0c's rule is that a test question appears in no planning document, so that no
agent can have read an answer; this one does not (the prior questions were the isthmian canal,
sanitary conventions, fishing rights, Cuba talks, wartime materials, Foreign Service reform and
commercial diplomacy). Beyond that, it was chosen because it carries every property the
revisions need to be tested on, and each is checkable:

| Property | Why it matters to the test | Measured basis |
|---|---|---|
| **The scope is the agents' to find, and it has a known shape** | §14.1: the scoping pass is most of the work, and now it is scored | 48 volumes in `manifest.json` are titled for the region or one of its countries, from the 1880s to 1988, 37 of them 1930–1979 and one each in the 1880s, 1890s and 1980s; the general and annual volumes before 1932 hold the rest, which only the period's own vocabulary finds (§14.6). The 1981–1988 subseries has no Latin America volume, so the record ends in January 1981 (the Cuba kit measured this) |
| **All three bottom-line parts are non-trivial** | R5 is the rule under test | Direct: recognition decisions are printed as policy memoranda and instructions. Pointed-at: `external_citations` begins 1910-12-06, so the footnote channel exists for the whole window. Cannot: anything after January 1981; the covert side, under-represented by §10's own rule; and whatever the agents' scoping finds the series prints only as a retrospective gloss |
| **A definitional call the historian must make** | R14 | "By force" admits a coup, a revolution, a military intervention and a contested election; "recognize" admits de jure, de facto and the resumption of relations |
| **A false friend the question itself supplies** | §14.5 | *recognition* is also the recognition of claims, of belligerency, of consuls (exequaturs) and of boundaries; *de facto* is ordinary prose |
| **Variants** | §14.4 | recognize / recognise; "recognition of the new government" / "resumption of relations" / "withhold recognition"; "junta" / "provisional government" |
| **Traps in the archival layer** | §4.4 | the decimal file is renumbered in 1950, so a class prefix is a false friend across 1950-01-01; the Subject-Numeric file begins in 1963; and `external_citations` has no row before 1910-12-06, so the pointed-at channel is empty by construction for the earliest cases |
| **The subject vocabulary tags it thinly** | §7.7 | `Diplomatic Recognition` tags 204 documents and `Coup attempt` 214 in `document-subject-index.json`; the question cannot be answered from tags and must be searched |

**Anchors the refuter may use, labelled as a historian's expectation and not a measurement**:
the non-recognition of Huerta in 1913, the Central American treaties of 1907 and 1923 and the Tobar
and Estrada doctrines, the Brazilian and Argentine cases of 1930, Guatemala in 1954, Peru in 1962,
the Dominican Republic in 1963, Brazil in 1964. A cell that finds none before 1930 has narrowed the
question; a cell that finds them only in a modern editor's gloss has answered a different one
(§14.7). None of these is a required finding; each is a question the refuter can put.

**What the historian is told they will get back** (the deliverable, identical in every cell): a
scope memo, an overview opening with the three-part bottom line, a `.fruscollection` with prose
and excerpts, and the query log, as the review's R1, R2, R5 and R7 specify. One session, no
rounds: the matrix is what is measured, and a round structure would confound it.

---

## 2. The cells

| | `medium` | `high` | `max` |
|---|---|---|---|
| `claude-sonnet-5-5` | S-med | S-high | S-max |
| `claude-opus-5-5` | O-med | O-high | O-max |
| `claude-fable-5-1` | F-med | F-high | F-max |

Effort is set explicitly in every cell: Opus 5.5 defaults to `medium` and the other two to `high`,
so an unset cell would not be the cell its label claims. The workflow's `agent()` takes `model`
and `effort` directly, so a cell is one call with two options and the same prompt
(`workflow-authoring` reference; the prompt is byte-identical across cells, runbook §8).

**Every cell gets the same prompt**: the question; the scratch directory; the read-only database
copy and the bundled resources, by path; the §12 block at v1.28 **plus the READER-FACING OUTPUT
section the guide carries since v1.29**, generated into the script from the guide, which carries the section since v1.29 (runbook
§8, never transcribed); and the deliverable list above. The first tool call of every agent is the
canary command against a known answer (runbook §1).

**Fixed across cells, and not under test**: the scorer, the refuter and the reader judge run on
`claude-fable-5-1` at `max`, one each per cell, blind to the cell (the owner's choice of
2026-10-14: the most capable setting the matrix contains, so no cell is scored by an instrument
weaker than itself). A measuring instrument that changed with the thing measured would measure
nothing. The instruments are the dearest part of a cheap cell, so the calibration in §3 reads
their cost first, before any Fable cell runs.

---

## 3. Order, calibration and the stop rule

0. **Calibrate the instruments on nothing.** Before any cell, score, refute and judge one of the
   2026-08-31 starter kits as if it were a cell (the Cuba kit, whose question is closest to C-3's),
   reading `/usage` before and after. That is the instruments' cost on their own, and the rehearsal
   of their prompts against an output whose errors are already known; a cell's own figure is read
   net of it.
1. **Calibrate on the two corners.** Run **F-max** and **S-med** first, one at a time, reading
   `/usage` before and after each. These bound the per-cell cost. If F-max alone exceeds 8% of the
   weekly allowance, the matrix cannot be completed within the budget and the owner decides
   between the diagonal alone (S-med, O-high, F-max) and a lower effort for the Fable column.
2. **The diagonal next**: O-high.
3. **Then the off-diagonal cells that decide the three recommendations**: S-high and O-med (the
   value candidates), F-high (the quality candidate below F-max).
4. **Then the corners**: O-max, S-max, F-med.
5. **Replication only with budget left**: a second run of whichever three cells lead on the three
   readings, in that order.

After every cell: record the `/usage` delta, the journal's token counts and the wall clock, and
project the next cell from the nearest measured one (a Fable cell from a Fable cell, an effort
step from the same model's neighbour). **Stop before any cell whose projection would carry the
cumulative total past 25%.** The scorer, refuter and judge for a cell run before the next cell is
launched, and their cost is in the cell's figure.

---

## 4. What is measured, per cell

| Measure | Instrument | Records |
|---|---|---|
| **Usage** | `/usage` before and after; the workflow journal | weekly-usage %, input and output tokens, cache reads, wall clock, tool calls, whether the session died (runbook §6) |
| **Compliance** | one blind scorer on Fable at max, C-0c's 24 items unchanged plus O1–O3 (the review §3) | obeyed / violated / not applicable per item, with evidence; compliance = obeyed ÷ (obeyed + violated) |
| **Correctness** | one refuter on Fable at max, told to find the wrong number: re-derive the five headline numbers of the overview from the log, re-retrieve every quotation for its pair (§8's alphanumeric check), confirm every NAID in the bottom line against the artifact | numbers reproduced of five; quotations verified of N; fabrications; mis-citations |
| **Reader quality** | one judge on Fable at max, blind to the cell, reading the **overview and the collection only**, never the memo | five yes/no items: the three-part bottom line present and in order; every number a count of a named set in words; citations as the edition with a link; what cannot be answered stated as a search run; no SQL, column name, id pair or path. Plus one ranked preference over all overviews received so far, with a one-line reason |
| **The historian's deliverable** | `tools/`-style check from the review's R7: the `.fruscollection` opens (the §15.2 checker), carries prose and excerpts, and every document the overview cites is in it | opens / entries by kind / cited-and-present |

**Quality score** = compliance × (numbers reproduced ÷ 5) × (quotations verified ÷ N) × (reader
items ÷ 5), with a fabricated quotation or a collection that does not open setting the cell's
score to zero. The product is deliberately harsh: a cell that is fast and fluent and wrong is the
case the guide exists to prevent.

---

## 5. The three readings, pre-registered

- **Fastest.** The lowest wall clock among cells with compliance at or above C-0c's block-arm level
  (95.2% on the 181-line block, `C0c-Falsifier-2026-09-06.md`; C-0b's was 100% on 143 lines) and
  zero fabrications. A fast
  cell below that floor is not a recommendation; it is a warning, and the guide says so.
- **Best value.** The highest quality score per percentage point of weekly usage.
- **Highest quality.** The highest quality score, ties broken by the refuter's error count, then by
  the reader judge's ranking.

**Expected shape, written down so the result can contradict it:** effort matters more than model
on this task's compliance (the block's rules are procedural), model matters more than effort on
the reader items (the overview is prose), and the Fable column's cost is more than twice the Opus
column's for less than a one-item gain on compliance. If the diagonal shows no ordering at all,
the question is too easy or the measures too coarse, and the run says that rather than ranking
noise.

**The matrix answers for this question only.** The guide's table will say so, carry the date, the
guide version and the index version, and name the question. A second question is the first thing
a later run adds.

---

## 6. The script, in outline

Saved as `Planning/c3-reader-test/workflow.mjs` after the run, with its `RUBRIC.md` (this file's §4
items), the per-cell `memo`, `overview.md`, `collection.fruscollection`, `queries.log`, the three
verdicts, and `usage.md` (the `/usage` readings by hand). The shape, following C-2's:

```js
export const meta = {
  name: 'c3-reader-test',
  description: 'C-3: the reader-facing block section under 9 model × effort cells, one question.',
  phases: [{ title: 'Run' }, { title: 'Score' }, { title: 'Refute' }, { title: 'Judge' }],
}
const CELLS = args.cells   // [{id:'S-med', model:'claude-sonnet-5-5', effort:'medium'}, …] in §3's order
const RUNNER = args.runner // the one prompt, generated from the guide and the review (runbook §8)
const results = await pipeline(
  CELLS,
  (c) => agent(RUNNER.replace('{{CELL}}', c.id), { label: 'run:' + c.id, phase: 'Run', model: c.model, effort: c.effort }),
  (_r, c) => agent(SCORER(c.id), { label: 'score:' + c.id, phase: 'Score', model: 'claude-fable-5-1', effort: 'max', schema: VERDICT }),
  (_r, c) => agent(REFUTER(c.id), { label: 'refute:' + c.id, phase: 'Refute', model: 'claude-fable-5-1', effort: 'max', schema: REFUTATION }),
  (_r, c) => agent(JUDGE(c.id), { label: 'judge:' + c.id, phase: 'Judge', model: 'claude-fable-5-1', effort: 'max', schema: READER }),
)
return { cells: results.filter(Boolean) }
```

The stop rule is outside the script: cells are passed in `args.cells` a few at a time, in §3's
order, and the next invocation resumes from the run id with the cells already measured cached.
`Date.now()` is unavailable in a script, so wall clock comes from the journal's timestamps.

**Before the fleet, one cheap agent** on the exact runner prompt against the canary (runbook §1):
a wrong path or flag shipped to nine cells is nine wasted cells, and one of them is the most
expensive thing in the plan.

---

## 7. Recording (guide §13)

Beside the results: the date, the app build and index version, the `.backup` date of the copy, the
indexed-volume list (all 553 expected), the guide version and the review commit the block section
was generated from, `sqlite3 --version`, the harness version, every prompt as pasted, and the
`/usage` readings with their times. Two agents given different texts are two instruments.

## 8. Known limitations, recorded before the result

1. **n = 1 per cell** unless replication fits the budget. One cell's bad luck is a cell.
2. **One question, and an open one.** A model × effort ordering on one question is evidence about one
   question, and a question whose scope the agents set is answered over scopes that differ by
   cell: the scorer's first row records each cell's scope (volumes and date span) so the readings
   compare answers of the same question and not answers of nine.
3. **The instruments share a model with one cell.** A judge on Fable 5.1 may prefer Fable 5.1's
   prose, and F-max is scored by its own twin. The reader items are yes/no on checkable properties
   for that reason, the refuter's work is re-derivation and re-retrieval rather than opinion, and
   the ranking is the tie-breaker, never the score. If F-max leads on the reader items alone and
   on nothing else, say so as a possible instrument effect rather than a finding.
3a. **The instruments cost more than some cells.** Fable at max scoring a Sonnet-at-medium cell may
   spend more than the cell did. The budget counts it (§3), the calibration step 0 measures it
   before any cell, and the value reading divides quality by the cell's own usage, instruments
   included, so a cheap cell is not made to look cheaper than it was.
4. **Weekly usage is a plan's meter, not a price.** It is the right constraint for the owner and
   the wrong unit for the guide's readers, so the guide's table carries tokens and wall clock
   beside it, and names the plan the percentage was read on.
5. **Blinding is partial**, as in every run before: an overview may name its model.

## 9. What the guide carries afterwards

A new §3a, *Choosing a model and an effort*, of one table and five sentences: the three
recommendations with their measured compliance, errors, reader items, wall clock and usage; the
question, the date and the versions; and the sentence that the fastest cell below the compliance
floor is not recommended at any price.
