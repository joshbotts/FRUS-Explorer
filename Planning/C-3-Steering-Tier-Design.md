# C-3, the steering tier (R16) — the revised block and the vectors card against the guide as it stands, Opus 5.5 at `medium` and Sonnet 5.5 at `high`

**Status:** RUN 2026-10-30, 09:50 to 15:32, as set by the owner that morning. Results:
**`C-3-Steering-Tier-Results-2026-10-30.md`**; record `c3-steering-tier/`. By the rule in §6, arm B
is not adopted: reading 4 failed by one item. The owner followed the rule ("Follow the rule"), and
the guide records the measurement at v1.38. Drafted the same morning on the owner's
answers of 2026-10-30 to `Agentic-Guide-Steering-Review-2026-10-27.md` §9, the last of which says to
start today once this plan is set. The design is that review's R16 (§7) with the answers applied
and its figures checked against the records and the guide at v1.37. Successor to
`C-3-Vectors-Tier-Design.md`, whose harness, instruments and record format it reuses. Working folder
`~/frus-analysis/c3s/`; record `c3-steering-tier/`. **The question is not printed here** (§1).

**Set by the owner on 2026-10-30 ("Plan is set"), and built the same morning.** The owner chose
the corruption question from five candidates. These things differ from the text below as written:
- **Sizes.** The card came to 149 lines, not about 110, and arm B's block to 247 lines. Arm B's
  prompt is 584 lines against arm A's 749: 165 shorter, not 210.
- **R8's lookup.** The stems are looked up in `frus_documents_vocab`. The review named the `terms`
  table, which is the volumes' glossaries. `communis*` also turns out to return every `communist`
  while it misses `communism`, so the trap stays silent.
- **V7 is the refuter's.** The scorer scores 44 items, and the refuter reports V7 from its re-run.
- **The canary's tenth neighbour is a three-way tie** at 79 (`frus1862/d72`, `d118` and `d457`).
  The card breaks ties by row and Appendix A's printed list keeps `d118`, so the canary checks the
  nine nearest exactly and the tenth by its distance.
- **The pins.** Arm A is cut from `4fbf75f1`, and its block's SHA-256 is `c2f5511d…`, the block C-3
  measured. Arm B is cut from `84bf7e50` on `claude/c3-steering-arm-b`, a local branch.

**The owner's answers of 2026-10-30, and what each changes below.**

1. *"inside"*: R6's SEMANTIC VECTORS section goes inside the §12 block in arm B (§2.2). The review's
   case was that the runs show the agent reads the section's condition, but both arms hand over the
   artifacts, so no run of R16 as written reaches the other branch. Run 9 does (§2.3).
2. *"drop it"*: centroid similarity leaves the list of operations, where the review kept it
   optional. Arm B's section and its memo sentence name three operations, not five (§2.2). The
   guide's §14.16 and §14.17, outside the measured text, say the same from v1.37.
3. *"how about if i provide five candidate questions that you assess"*: the owner proposes five, the
   session assesses each against §1's properties, and the owner chooses one.
4. *"latest reader-facing output is ok in substance and scope but could use additional work on
   style and language. how does that affect next steps? could that be an independent pass using
   the raw outputs of the measurement runs?"*: READER-FACING OUTPUT is adopted in substance and
   scope, and its style and language get a pass of their own over the runs' raw outputs (§8). So
   R9, R11 and R13, which rewrite that section, leave arm B for the pass, and both arms are scored
   on the items that give the pass its baseline (§4). Moving the three is this plan's proposal, for
   the owner to confirm (§9).
5. *"budget sounds good. start today after plan is set"*: the stop lines are the starting reading
   plus 25 points of the weekly all-models meter and plus 40 of the weekly Fable meter (§5). The
   tier runs today, which sets aside the review's "after build 52 ships" (the owner's condition of
   2026-10-27). Build 52 has not shipped, so the index users have is still version 71, the one
   C-3's copy holds.

**Why this tier.** The vectors tier's four sessions used the vectors because the harness's
deliverable named the operations. The guide never told them to. v1.37 put that instruction in the
guide's prose (§14.17), which no prompt carries. This tier measures the review's treatment against
the guide as it stands, on a question chosen so the vectors can matter:
- the instruction inside the block;
- a card of about 110 lines in place of Appendix A's 345;
- three block rules the C-3 runs broke.

---

## 1. The question

**Not printed in any planning document before the run.** This is C-0c's rule, so that no agent can
have read an answer (`C-3-Reader-Test-Design.md` §1). The generator pastes the question from
`~/frus-analysis/c3s/question.txt`, and the record prints it afterwards.

**The properties**, from the review's §7 and §9 and C-3's design table. The session that chooses
checks each candidate against them:

| property | why it matters here | how it is assessed, from the index copy read-only |
|---|---|---|
| **No chapter of its own**: the documents sit under the countries involved | Cuba's chapters swallowed the neighbours: three of the five documents the sessions claimed were inside their own Cuba chapters, and the session whose scope was every mention (12,256 documents) counted none | the share of a full-text scope's documents whose chapter heading names the subject; how many distinct headings hold the rest |
| **At least three eras with material** | each era needs an anchor of its own (§14.17 step 2) | the scope's documents by era |
| **Its words change over time** (§14.6) | vocabulary drift is the case the vectors exist for | the subject's main terms and their variants, by decade |
| **All three parts of the bottom line non-trivial** | O3 is scored, and the judge reads it | documents that answer directly; `document_sources` or `external_citations` rows in the scope; a part FRUS cannot answer |
| **Not one of the nine questions already used**, and printed nowhere in the repository | C-0c's rule | the list (`C-3-Reader-Test-Design.md` §1, then recognition in Latin America and Cuba since the 1870s); a grep of `Planning/` and `Docs/` for each candidate's terms |
| **A scope a session can read in 20 to 30 minutes** | the cells' wall clock is a reading | the scope's size |
| **Room for the vectors** | the reach reading needs something to reach | for two or three anchors per era, the share of their 25 nearest neighbours outside the heading scope and without the subject's words |

The last row runs the operation this tier measures, once, in the choosing session and not by an
agent under test. The assessment's files stay in that session's scratchpad, and they are deleted
before the first cell. Nothing about the candidates goes into the repository before the record.
What the vectors should add on the chosen question goes into `~/frus-analysis/c3s/expectations.md`
before the first cell, so the result can contradict it, and the record prints it afterwards.

## 2. The arms and the runs

The cells are C-3's two recommended ones: **O-med** (`claude-opus-5-5`, `medium`) and **S-high**
(`claude-sonnet-5-5`, `high`). There are two runs per arm in each cell, interleaved so that drift in
the meters or the machine falls on both arms, and one more run:

| # | run | cell | arm |
|---|---|---|---|
| 1 | O-med A (1) | O-med | A |
| 2 | O-med B (1) | O-med | B |
| 3 | S-high A (1) | S-high | A |
| 4 | S-high B (1) | S-high | B |
| 5 | O-med A (2) | O-med | A |
| 6 | O-med B (2) | O-med | B |
| 7 | S-high A (2) | S-high | A |
| 8 | S-high B (2) | S-high | B |
| 9 | O-med B, no artifacts | O-med | B, with RESOURCES item 4, the card and the guide copy removed |

Each run has C-3's three instruments (scorer, refuter, reader judge) on `claude-fable-5-1` at `max`,
blind to the cell and the arm through opaque labels and a keymap.

### 2.1 Arm A, the control: the guide as it stands

Arm A is what v1.37's §3a tells a user to do, generated from the guide at the commit that carries
v1.37 and pinned by the SHA-256 of each part extracted:
- the §12 block (205 lines between its fences), with §A.8's addendum pasted at its end, as §3a says;
- Appendix A whole, from its heading to the Glossary, where the vectors tier placed it;
- the vectors tier's RESOURCES items 1 to 4, HARD CONSTRAINTS and tooling notes (one corrected, §7);
- the deliverable with the vectors tier's VECTORS sentence, which names five operations as equals.

It differs from the vectors tier's prompt only by the guide's own changes since then:
- R14's figures in the appendix: every share N of M, and no previous generation's figure;
- the addendum's line on cosines (v1.36);
- the addendum pasted inside the block too (v1.36's §3a).

The review's control was "the v1.36 prompt as run". v1.36's appendix still printed the bare
"28.0%" that `v4` copied and lost P5 on, and v1.37 replaced it. A v1.36 control would credit arm B
with a fix the guide already has.

### 2.2 Arm B, the treatment

Arm B is written as the guide's own text, a v1.38 candidate on a branch of its own, never merged
unless §6 adopts it. That way "B goes into the guide as its text" is literal, and its prompt is
generated from that commit as A's is from v1.37. It carries:

- **R6**: the SEMANTIC VECTORS section, inside the block after ARCHIVAL SCOPE and in place of the
  pasted addendum. It is the review's text with two changes:
  - the sentence "Centroid similarity is optional." is cut (answer 2);
  - the near-duplicate bullet reads: *REQUIRED: before any count over a set you built, each
    member's nearest-neighbour distance in the set. Read both documents of every pair closer than
    the random-pair mean less eight sd at this digest, and count a pair as one document printed
    twice only when the two texts agree. Cite one copy, say which, and count it once.*

  The review's line was nine sd. At this digest that is 34 (167.1 less 9 × 14.8), and the
  2026-10-29 sample behind §14.9 found copies up to 39: a pair at 36 whose opening 3,000
  characters agree at a difflib ratio of 0.98, and one at 39 at 0.94. Eight sd is 48.7, so every
  copy the sample found is read.
- **R5's clause** on the block's Ed2 line: *with the artifacts in hand, the SEMANTIC VECTORS
  section's near-duplicate check finds the reprints the ids do not.*
- **R7**: ARCHIVAL SCOPE's "11 of 695 bundled series" becomes the guide's measurement at its date,
  re-derived from `series-facts-index.json` when B is written, with the REPORTING rule that a figure
  taken from the guide is attributed or re-derived, never presented as the session's finding.
- **R8**: the prefix-on-stem trap, with its two stems (`normal`, `commun`) checked against the
  copy's `terms` table when B is written.
- **R10**: a zero is printed beside the relaxed form of the same query that returned rows.
- **R15**: the operating card, §A.9 of the candidate (about 110 lines), in the prompt in place of
  Appendix A. It holds:
  - §A.2's rule, in two lines;
  - §A.3's decode, as code;
  - §A.4's layout table;
  - §A.5's loop and both baselines' recipe, with the seed and the Python note;
  - the three-flag join, as code;
  - the near-duplicate check, as code.

  RESOURCES gains the candidate guide as a file to consult, copied to
  `~/frus-analysis/c3s/guide/Agentic-Analysis-Guide.md`, because the HARD CONSTRAINTS forbid the
  repository tree. The canary runs the card's own code (§5).
- **R1 and R3**: the deliverable's VECTORS sentence names the two required operations (the nearest
  neighbours of an anchor, joined into the database and flagged; near-duplicates before any count)
  and the conditional one (the map, as §14.10's label test). Each is given as run, with its anchor,
  its file, its baseline and its result, or as not run and why. The sentence also asks which cited
  documents were vector-reached under each reading, the provenance digest with the index's
  `generated` stamp, or the words "VECTORS: none".
- **§3a and §A.8** of the candidate: "the block's SEMANTIC VECTORS section applies" in place of
  "paste §A.8's addendum", and §A.8 keeps a one-line pointer to the block.

Not in B: R9, R11 and R13, which go to the pass (§8). R6's last bullet, which keeps the vectors'
vocabulary out of the overview and the collection, stays: it lives in the vectors section.

**Sizes.** Arm B's block comes to about 244 lines: 205, plus R6's 33, plus 6 for R5, R7, R8 and
R10. With the card, B's rules and vector text come to about 354 lines. A's come to about 566: the
block with the pasted addendum, 220, and the appendix, about 346. So B's prompt is about 210 lines
shorter.

### 2.3 Run 9: arm B with no artifacts

Run 9 is arm B's prompt with RESOURCES item 4, the card and the guide copy removed. The brief hands
over no artifacts, so the section's first line says to run none of it. It tests the branch no other
run reaches, and what the 35 items lose when the section sits in the block unused.

## 3. What is measured, per run

Everything the vectors tier measured (its §3), plus:
- the four new items (§4);
- the refuter's reach step under both of §14.17's readings: strict, no logged full-text or heading
  query returns the document, re-run; and practical, the document was in no result set the session
  had read when the neighbour list surfaced it;
- in arm B, which sections of the guide copy the session opened, from its log;
- in run 9, whether the memo says "VECTORS: none" and whether the log opens any vector file.

The quality score is over the 35 items, as before. The V and O items are reported beside it.

## 4. The rubric: the vectors tier's 41 items plus four

| id | block | item | `obeyed` requires |
|---|---|---|---|
| V7 | VECTORS | Every document the memo calls vector-reached is so under the strict reading. | The refuter's re-run of the logged queries returns none of them. `not_applicable` when the memo claims none. |
| V8 | VECTORS | No vector vocabulary where the historian reads: no Hamming, cosine, bit count, cluster number, "vector" or "neighbour at N" in the overview or in the collection's introduction, prose or notes. | None found. Arm A has no such rule, so its result is the baseline. |
| O4 | READER | The collection's introduction, prose and notes carry no SQL, table or column name, id pair outside a history.state.gov URL, or file path. | None found, in both arms: the pass's baseline, since no text in either arm binds the collection's prose (R11 is the pass's). |
| O2' | READER | Every numeral and number-word in the overview has a row in the memo's trace table. | The scorer's own count of the overview's numerals against the table, in both arms: the pass's baseline for O2. |

The review's O4 is split in two because its two halves measure different things.
- **The vocabulary half (V8)** is what arm B's section bars. A scan of the 16 earlier collections
  finds it in all four of the vectors tier's: `v3`'s note on the Dulles memorandum reads "Reached
  only through vector similarity (106 bits from the Mallory memo…)".
- **The SQL, id and path half (O4)** binds no text in either arm. The same scan finds none of it in
  any of the 16 collections: every id pair it matched sits inside a history.state.gov URL after an
  edition citation, which is allowed.

Run 9 scores V1 to V8 `not_applicable`.

## 5. Order, calibration, canary and the stop rule

0. **Calibrate the new items and the refuter's two readings on `v3`** (the vectors tier's S-high+V
   (1)), whose answers are known. Two instruments, the scorer with the 45-item rubric and the
   refuter with both readings, about one weekly point and three of the Fable window. A scorer or
   refuter that misses any of these is a broken instrument:
   - **V7 violated**: `v3` claimed `frus1961-63v10-12mSupp/d729`, inside its heading scope, beside
     `frus1958-60v05/d112`;
   - **V8 violated**: six of its collection's strings carry the vocabulary;
   - **O4 obeyed**;
   - **the strict reading `{frus1958-60v05/d112}`**;
   - **the other 41 as `v3`'s verdicts recorded them.**
1. **The canary.** One O-med agent on arm B's exact RESOURCES and card must:
   - decode 553 of 553 volumes with the card's code;
   - print the three digests equal;
   - reproduce `frus1861/d111`'s ten neighbours exactly as `vectors_check.py` holds them;
   - run the card's three-flag join on that anchor.

   A failure ends the tier before it costs a cell.
2. **Runs 1 to 8**, in §2's order, with the meters read before and after each.
3. **Run 9.**

**Budget.** In the vectors tier each run moved the weekly all-models meter 1 to 2 points and the
Fable meter 3 to 4, its instruments included (`c3-vectors-tier/usage.md`).
- **Nine runs:** about 15 to 18 weekly points and 30 to 34 Fable points.
- **With calibration and the canary:** about 17 to 20 and 33 to 37.
- **Lines:** the starting reading plus 25 weekly points and plus 40 Fable points. At 08:33 on
  2026-10-30 the meters read 4% and 2%, resetting 2026-11-04, so a start then would put the lines
  at 29% and 42%.
- **Stop rule:** C-3's. Before any step whose projection crosses a line, stop and ask the owner
  rather than end.
- **Elapsed:** about 35 to 40 minutes a run in the vectors tier, so six to seven hours from the
  calibration to the last verdict.

## 6. The readings, pre-registered

These are the review's readings with the owner's answers applied.

1. **Use.** B runs both required operations in 4 of 4, and names any other operation it runs with
   its reason. A's operations are reported; expected: all five, as in the vectors tier.
2. **V6.** A measures whether the addendum's cosine line, now inside the block as well, moved the
   vectors tier's 0 of 4. B: obeyed or `not_applicable` in 4 of 4. With centroid similarity cut,
   no step B is given produces a cosine. Only a session that opens a Tier-2 shard, or computes a
   centroid cosine anyway, has one to label.
3. **Reach.** B's strict count is at or above A's on the same question, and V7 holds in 4 of 4 of B.
4. **The cost.** B loses no more of the 35 items than A. A B run that loses two is read against A's
   runs on the same cell.
5. **The reader.** V8 holds in 4 of 4 of B, and the judge ranks B's overview at or above A's in at
   least two of the four cell-matched pairs. O4 and O2' are reported for both arms as the pass's
   baseline and decide nothing here.
6. **The price.** B's wall clock is within A's, on a prompt about 210 lines shorter.
7. **Run 9.** The memo says "VECTORS: none", the log opens no vector file, and the 35 items score
   at or above the 0.952 floor.

**Adoption.**
- B goes into the guide as its text if (1), (2), (4) and (7) hold. (3) and (5) decide the wording
  of §3a's paragraph.
- A B that fails (4) keeps the appendix and the addendum, and R7, R8 and R10 are measured again
  alone.
- A run 9 that fails (7) moves the section out of the block, into a text pasted when the artifacts
  are in hand. That reverses answer 1 by measurement, and the owner decides it.

## 7. Known limitations, recorded before the result

1. **n = 2** per arm per cell; run 9 is n = 1.
2. **One treatment.** The arms differ by the whole revision, which is what a user who follows it
   pays. No single edit is attributable (the review's own limitation).
3. **B can read the whole guide; A cannot.** That is R15's design: the card in the prompt, the
   guide as a file. B's log shows which sections it opened.
4. **A's appendix points to §14.17**, which A's prompt does not carry. A user who pastes the
   appendix gets the same pointer.
5. **No free-text arm.** The tier is document-to-document only, as the vectors tier was (its
   decision 1).
6. **Run 9 has no same-question control without the section.** Its 35 items are read against the
   0.952 floor and C-3's O-med runs on another question.
7. **The machine has changed.** numpy 2.0.2 now imports from the user's site packages, where the
   vectors tier's tooling note said numpy was not installed. Both arms get the corrected note, so
   a faster scan is shared.

## 8. The reader-facing pass (the owner's answer 4)

READER-FACING OUTPUT is adopted in substance and scope. Its style and language get a pass that
needs no research run:

1. **The inputs** are the overviews, collections and memos of C-3's 12 runs, the vectors tier's 4
   and this tier's 9, with each run's judge verdict: 25 runs, all in the repository's records.
2. **A style review**, in the form of the 2026-10-14 and 2026-10-27 reviews, of what the overviews
   do in register, sentence length, citation form, how numbers read, and tool talk. R9, R11 and R13
   are among its starting points.
3. **The section's wording is revised, and tested on the same memos.** Each overview is rewritten
   from its own memo under the old wording and the new, and the reader judge compares the pairs
   blind. Nothing is searched again, so a sample costs a writer and a judge, not a session.
4. **What it cannot show** is whether the new wording holds while the agent is also doing the
   research under the whole block. The next full tier checks that.

Its budget is set when it is designed. It is not part of this tier's.

## 9. What setting this plan confirms

The owner's five answers are above. Setting the plan also confirms these, which the answers did not
settle:
- arm A is v1.37's text, not v1.36's (§2.1);
- arm B is written as the guide's own text, on a branch of its own (§2.2);
- R9, R11 and R13 leave arm B for the reader-facing pass (§8), and the review's O4 is split into
  V8 and O4 (§4);
- the near-duplicate line in B is eight sd, not nine (§2.2);
- run 9 (§2.3);
- no free-text arm (§7);
- C-3's index copy (version 71) and the shards beside it, as the vectors tier used;
- the question goes from the owner's five candidates into `question.txt`, and into the repository
  only with the record.

## 10. What the harness needs built, and nothing else

- **The arm B candidate on its branch:** the block's sections, the card as §A.9, §3a and §A.8, and a
  version-history entry that marks it a candidate. It is committed before any prompt is generated.
- **`generate_s.py`**, from `generate_v.py`, with:
  - two pinned guide commits;
  - the two arms' prompts and run 9's;
  - the RESOURCES item for the guide copy;
  - the corrected tooling note;
  - the four new rubric rows;
  - the refuter's two readings;
  - the judge's four cell-matched pairs;
  - the canary's known answer, taken from `vectors_check.py`.
- **`tally.py`, `save_verdicts.py` and `results.py`** as they are, with the arms read from the
  keymap.
- **The working folder** `~/frus-analysis/c3s/`, with C-3's index copy and shards read in place.
- **The record** in `Planning/c3-steering-tier/`, in the two earlier tiers' layout. Then a results
  file, then §3a and the version history, with the §15.1 block unchanged
  (`CollectionTests.publishedExampleMatchesTheGuide` pins it).
