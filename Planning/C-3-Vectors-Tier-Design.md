# C-3, the vectors tier — Sonnet 5.5 at `high` and Opus 5.5 at `medium` with Appendix A and the vector artifacts added

**Status:** RUN 2026-10-26/27 under the four decisions below; results in
**`C-3-Vectors-Tier-Results-2026-10-27.md`**, record in `c3-vectors-tier/`. Written 2026-10-26 on the
owner's instruction ("Plan but do not start a follow-up tier for Sonnet high and Opus medium that
adds in Appendix A and the vector artifacts"). The figures quoted below are C-3's
(`C-3-Results-2026-10-26.md`) or the guide's. Successor to
`C-3-Reader-Test-Design.md`, whose harness, instruments and record format it reuses; the record goes
in `c3-vectors-tier/`.

**The owner's four decisions, 2026-10-26 evening (§8), and what they change below.**

1. **No embedder**: document-to-document only, as §2 proposes.
2. **Run now, under a line at 92% of the weekly meter**, which read 80% when the decisions were
   taken (resets 2026-10-28 16:00): 12 points for a tier projected at 8 to 10. C-3's stop rule, and
   the owner is asked before the run stops at the line.
3. **The owner's second question, not C-3's.** So there is **no control arm**: §1's comparability
   argument is set aside, and §3's "cost of the appendix" and §6's "reader" readings compare the
   four runs with C-3's figures for the same two cells on a different question, labelled as such,
   not as controls. The judge ranks the four +V overviews alone. The reach reading, the V items and
   the compliance floor stand as written. The question's text is the owner's, pasted into the
   prompt from `question.txt` by the generator and printed in the record.
4. **The shards are copied beside the index copy**, as §2 proposes.

The text below is the design as written before the decisions, unchanged.

**Why this tier.** C-3's twelve runs never opened a vector artifact: the prompt handed each cell the
index copy, the TEI files and the bundle's JSON folder, and nothing pointed at the vector binary,
the shards, the map or the guide's Appendix A (the only mentions in any log are two greps that
matched file names in passing). So C-3 says nothing about whether the build 51 vectors help an
agent answer a historian. This tier asks that, for the two cells C-3 recommends, and asks it the
way C-3 asked its question: the same prompt in every run, instruments blind to the cell, the
readings written down first.

**Three questions, one run.**

1. **Do the agents use the vectors when the appendix is in front of them, and for what?** An
   artifact nobody reaches for is a cost without a return; Appendix A is the only door, and this is
   its first test on an agent that was not told to walk through it.
2. **Does the historian get more?** Documents the full-text scope could not reach — vocabulary
   drift across 165 years, the Spanish and French enclosures porter stemming mangles (§A.5) — and
   whether the overview, the collection and the judge show it.
3. **What does it cost?** A prompt 318 lines longer (the appendix) on a block whose length C-0c
   measured as an attention cost; and wall clock, tokens and usage against C-3's pair.

---

## 1. The question

**The same question as C-3**, unchanged: *How did the United States decide whether to recognize
governments that came to power by force in Latin America, and what did it ask of them before
recognizing?* Holding it fixed makes C-3's four runs of these two cells the control arm, at n = 2
each, already scored by the same instruments: S-high (31.4 min, 56 documents both runs, perfect
compliance twice) and O-med (18.8 min, 19 and 26 documents, perfect twice). A new question would
confound the vectors with the question. C-0c's rule that a test question appears in no planning
document no longer holds for this one (`C-3-Results-2026-10-26.md` prints it); the agents are
forbidden the repository tree as before, and no model's training reaches 2026-10-25, so the rule's
reason — that no agent can have read an answer — still holds for this run and will not for a run
a year from now. The owner's second question (design §5 of C-3) is a separate tier, not this one.

**What the vectors should add on this question, written down so the result can contradict it:**
the nineteenth-century cases (Seward on Maximilian, Chile 1891, Venezuela 1899) and the Spanish
enclosures where "reconocimiento" and "gobierno de hecho" are the words, which C-3's cells reached
only through the editors' chapter headings; a neighbour set around Hay's 1899 test and Wilson's
1913 terms that crosses decades; and near-duplicate suppression where a circular was printed in
two volumes. If the vectors add nothing on this question, the reading says so.

## 2. The cells

| | `medium` | `high` |
|---|---|---|
| `claude-opus-5-5` | **O-med+V**, two runs | — |
| `claude-sonnet-5-5` | — | **S-high+V**, two runs |

Four runs, each with C-3's three instruments on `claude-fable-5-1` at `max`, blind to the cell
(opaque labels, as C-3's keymap). The controls are C-3's r4 and r11 (O-med) and r5 and r12
(S-high), which the judge is handed as earlier overviews so its ranking covers all eight.

**Every run gets C-3's prompt plus three additions, generated, never transcribed** (runbook §8):

1. **Appendix A, whole**, extracted from the guide between its heading and the Glossary (318 lines
   at v1.34), placed after the §12 block and before THE QUESTION, under a heading that says what it
   is: the guide's account of the vector artifacts, their layouts, what an agent can do with no
   model, and what the vectors cannot tell you. Not a rule block: the §12 block stays the rules.
2. **The vector artifacts, by path, read-only**, as the RESOURCES section's item 4:
   - the bundle's `semantic-vectors-binary.bin` (20,476,048 bytes, 314,616 documents, 512 sign bits
     and int8 rows, the volume and subseries centroids), `semantic-vectors-index.json` (the
     run-length-encoded ids of §A.3, the provenance with its digest `89481b18…`, the query prefix,
     `retrieval.scoreCalibration`), `semantic-map.bin` with `semantic-map-index.json`, and
     `semantic-shards-manifest.json`, all under `/Applications/FRUS Explorer.app/Contents/Resources/`;
   - the 553 per-volume Tier-2 shards (`<volume>.vec`, 156 MB, the same digest), **copied** from the
     container's `SemanticVectors/` folder to `~/frus-analysis/c3/SemanticVectors/` before the run,
     with the folder's `.generation` file, so no agent reads inside the app's container (§8, decision 4).
3. **One sentence in the deliverable**: the memo records which vector operations were run (by
   §A.5's names: nearest neighbours of a document, semantic join, centroid similarity, the map,
   near-duplicates), each with its anchor, its baseline and its result, or says "none" — so a run
   that chose not to use them is distinguishable from one that could not.

**No embedder, in this arm.** No llama.cpp binary or Python binding is installed on the Mac, and
the app's query encoder is reachable only inside the app; a free-text query would need a harness
addition whose parity with the app's encoder (prompt `task: search result | query: `, chunking,
pooling, truncation to 512, the quantization rules of §A.4) nobody has measured. §A.5 says the
shipped artifacts are complete for document-to-document work with no model at all, and that is the
claim this tier tests. A free-text arm is §8's decision 1 and a tier of its own if the owner wants
it; the pinned GGUF is on the Mac (`SemanticModel/embeddinggemma-2-Q8_0.gguf`, 296 MB).

**No helper script, in this arm.** The appendix gives the id decode (§A.3) and the core loop
(§A.5) in Python; whether an agent can turn them into a working neighbour query in a session is
part of question 1. The pre-registered fallback: if 0 of the first two runs produce a neighbour
list, the tier pauses and the owner chooses between a second arm with a tested `vectors.py`
(`row_of`/`doc_of`, neighbours, centroid cosine, cluster lookup) in the resources and stopping.

## 3. What is measured, per run

Everything C-3 measured (its §4: usage, the 35-item compliance scorer, the refuter's five numbers
and every quotation and identifier, the reader judge's five items and ranking, the collection
check), unchanged, plus:

| Measure | Instrument | Records |
|---|---|---|
| **Vector use** | the memo's vector sentence, checked by the refuter against the log and the scripts | which §A.5 operations ran; anchors; whether a Hamming scan was over the bundle's binary, a shard, or both |
| **Reach** | the refuter: for every document the overview cites, whether any full-text query in the log returned it; a document returned by none and reached through a neighbour list, a cluster or a centroid is **vector-reached** | vector-reached documents, of the overview's cited set; the same over the collection |
| **Appendix A's own rules** | six new scorer items, V1–V6 (§4), same vocabulary as the rest | obeyed / violated / not applicable, with evidence |
| **The cost of the appendix** | compliance on the original 35 items against the cell's two C-3 runs | items lost or gained, by id |
| **Time and usage** | as C-3 | run wall clock and weekly points against the cell's C-3 mean (S-high 31.4 min, 2.0 points; O-med 18.8 min, 1.5 points) |

**Quality score** as C-3's, over the 35 original items, so the two arms are on one scale; the V
items are reported beside it and do not enter it, since the control arm had no vectors to obey
rules about. A fabricated quotation or a collection that does not open still zeroes the run.

## 4. The rubric: C-3's 35 items plus V1–V6

Added for this tier, each a rule Appendix A states and an agent can break without noticing:

| id | block | item | `obeyed` requires |
|---|---|---|---|
| V1 | VECTORS | Checked the provenance pin before using any vector: the index's `provenanceDigest` against the shards manifest's and the shard folder's `.generation`, and said so (§A.2, "the one family rule"). | The three digests named as equal, or a refusal to use a shard that disagreed. |
| V2 | VECTORS | Took document identity from the index's run-length segments (§A.3) and never from a shard's position in the XML or `d{ordinal+1}`. | A decode shown, and a spot check of at least one known pair (the appendix's `frus1861/d111` is row-addressable). |
| V3 | VECTORS | Calibrated before reading any Hamming distance, against both baselines (§A.5): random pairs and the k-th-neighbour distribution, recomputed on this digest. | Both figures reported before the first neighbour is interpreted. A neighbour called "close" with neither is `violated`. |
| V4 | VECTORS | Suppressed edition twins on every neighbour surface (the Ed2 volumes, cosine 1.0 to their first editions). | The suppression stated and visible in the lists, or no Ed2 volume in any list. |
| V5 | VECTORS | Reported any cluster-based figure with the set's unclustered share against an era-matched baseline, never the corpus figure alone (§A.5). | The share and its baseline, or no cluster figure. |
| V6 | VECTORS | Gave every cosine the reader sees through the index's `scoreCalibration` offsets, or as a raw cosine labelled raw (§A.7's last paragraph). | The offset named, or the word raw. |

A run that used no vectors scores V1–V6 `not_applicable` and is read under question 1, not
question 2.

## 5. Order, calibration and the stop rule

0. **Calibrate the new items on a run that used no vectors.** Score C-3's r5 (S-high, first run)
   with the extended rubric: V1–V6 must come back `not_applicable` six times and the other 35
   unchanged (34 obeyed, 1 not applicable). A scorer that finds a vector rule obeyed in a run that
   opened no vector file is a broken instrument. One scorer, Fable at `max`, about one third of a
   point.
1. **The canary** (runbook §1), before any cell: one cheap agent on the exact RESOURCES text,
   pinned as O-med is, must reproduce §A.5's verified list — the ten nearest neighbours of
   `frus1861/d111`, `frus1862/d130` and `frus1862/d455` at Hamming 87 first — from the bundle's
   binary, after decoding the ids by §A.3, and must print the three digests equal. A list that
   differs is a changed artifact or a wrong decode, and either ends the run before it costs a cell.
2. **O-med+V (1)**, then **S-high+V (1)**: the cheaper cell first, the meter read before and after
   each. After these two the fallback of §2 is decided.
3. **O-med+V (2)**, then **S-high+V (2)**.

**Budget.** Projected from C-3: O-med 1 to 2 points a run, S-high 2, plus about one point of the
instruments' own cost already inside those figures; the appendix adds about 25,000 characters of
prompt and the vector work adds reading, so allow one more point per run. **About 8 to 10 points of
the weekly all-models meter and about 16 of the Fable window** for the four runs, the calibration
and the canary. The meter stood at 74% at 01:00 on 2026-10-26 and resets at 16:00 on 2026-10-28;
the tier does not fit before the reset under any line the owner has set, so it runs after it or
the owner names a new line (§8, decision 2). The stop rule is C-3's: stop before any step whose
projection crosses the line, and ask the owner rather than end.

## 6. The readings, pre-registered

- **Use.** How many of the four runs ran a vector operation, and which operations. Expected: four
  of four run a nearest-neighbour scan; fewer than four run a semantic join; none runs the map.
  Zero of four is a finding about the appendix as a front door, not about the vectors.
- **Reach.** Vector-reached documents in each overview, of its cited set, and whether any of them
  carries a finding (a quotation the overview rests on) or only context. Expected: one to five a
  run, mostly before 1913 or in Spanish, and at least one carrying a quotation in the Sonnet runs.
- **The appendix's cost.** Compliance on the 35 items against the cell's C-3 runs. Expected: no
  item lost in Opus at `medium` (perfect twice, with the shortest sessions); at most one lost in
  Sonnet at `high`. Two or more lost in both cells, and the appendix goes into a separate resource
  the agent is pointed at rather than the prompt.
- **The reader.** The judge's five items (expected: five of five in all four, as the controls) and
  its ranking over the eight overviews. If the +V runs rank above their controls in three of four
  pairings, the historian got more; if they rank below, the vector work displaced reading.
- **The price.** Wall clock and usage against the cell's C-3 mean. Expected: +30 to +50 percent of
  wall clock, +1 point a run; a run that doubles is reading what it found, which the reach reading
  will show, or lost in the decode, which the log will show.

**The recommendation this changes.** If the +V runs reach documents the controls did not, carry a
quotation from one, hold compliance and rank at or above their controls, the guide's §3a gains a
sentence saying to hand these two cells the vector artifacts and Appendix A, and §12 gains a
one-line pointer. If they do not, §3a says the artifacts added nothing on this question at this
cost, and the free-text arm is where the next measurement lies.

## 7. Known limitations, recorded before the result

1. **n = 2 per cell**, matched to the control arm's n = 2. Enough to distinguish "used them" from
   "did not" and a lost item from noise; not enough for a small difference in wall clock.
2. **One question, one the controls already answered.** The vectors are tested where the full-text
   scope was already good (every control run perfect on compliance, 19 to 56 documents). A
   question whose words drift more would show more; this one was chosen for comparability.
3. **The appendix is a treatment and a prompt-length change at once.** A lost item cannot be
   attributed to the vectors rather than to 318 more lines; the "appendix's cost" reading measures
   the sum, by design, because that is what a user who pastes the appendix pays.
4. **No free-text queries.** The tier measures document-to-document work only; the appendix's own
   caveat stands that text-query retrieval is judged on 25 queries for the previous model and on
   none for this one.
5. **The instruments share a model with no cell** in this tier, which removes C-3's §8 item 3; the
   judge's ranking still includes C-3's Fable overviews only if the owner wants the full twelve,
   which is not proposed here (eight is the comparison).
6. **The shards are the app's own copies**, at the same digest as the bundle; a shard the app has
   refused or not fetched would be missing from the folder, and the canary's digest check covers
   only what is there. 553 were present on 2026-10-25.

## 8. Decisions the owner makes before the first cell

1. **The embedder.** This design: none; document-to-document only (§2). The alternative: a tested
   free-text harness, as a tier of its own after this one.
2. **The line and the date.** The tier needs about 8 to 10 points; the meter resets 2026-10-28 16:00.
   Run after the reset under a stated line, or name a line now.
3. **The question.** This design: C-3's, for the control arm. The alternative, the owner's second
   question, is the next tier and would have no control.
4. **Where the shards are read.** This design: copied beside the index copy. The alternative, the
   container's folder read in place, saves 156 MB and puts twelve agents inside the app's container.

## 9. What the harness needs built, and nothing else

- `generate.py`: an APPENDIX constant cut from the guide between `## Appendix A` and `## Glossary`,
  a RESOURCES item 4, the vector sentence in the deliverable, V1–V6 appended to the rubric file,
  the canary's known answer (`frus1861/d111`'s ten neighbours and the digest), and a `controls`
  argument so the judge's previous-overviews list can name C-3's four runs by their labels. The
  refuter's prompt gains the reach check (every cited pair against every full-text query in the
  log, which the refuter already parses for the headline numbers).
- `tally.py`, `save_verdicts.py`, `results.py` as they are, with the control arm read from
  `c3-reader-test/runs/{r4,r11,r5,r12}/`.
- A copy of the shards folder and the `.generation` file beside the index copy, 156 MB; the index
  copy itself is C-3's unless the live index has moved past version 71 by then, in which case a
  new `.backup` and a new canary row.
- Record: `Planning/c3-vectors-tier/`, the same layout as `c3-reader-test/`.
