# Agentic Analysis Guide — the reader-facing text's style and language: a review of 25 measured runs

**Status:** REVIEW, 2026-10-30, written on the owner's word ("Start the review"). It is step 1 of
the reader-facing pass in `C-3-Steering-Tier-Design.md` §8. Recommendations only: nothing in the
guide changes because of this document, and the test in §5 decides. **Its pilot ran the same day
(§8):** the judge preferred R1 in 4 of 4 pairs, and the reading on traced numbers failed, so R1's
numbers bullet is revised before the full pass. **Measured under research on 2026-10-31**
(`C-3-Reader-Facing-Tier-Results-2026-10-31.md`): R1 and R2's writing held in every run, but the
reader ranking and the cost readings failed, so by that tier's rule they are not adopted, and the
owner followed it (guide v1.39). **Scope:** the style and
language of the §12 block's READER-FACING OUTPUT section and of what it governs, the overview and
the collection's introduction, prose and notes. The section's substance and scope were adopted
on 2026-10-30 and are not reopened here.

**Sources.**
- The 25 runs the three C-3 tiers measured, all in the repository: C-3's twelve
  (`c3-reader-test/runs/r1`–`r12`), the vectors tier's four (`c3-vectors-tier/runs/v1`–`v4`) and
  the steering tier's nine (`c3-steering-tier/runs/s1`–`s9`).
- Their `overview.md` and `collection.fruscollection`, and their scorers' and judges' verdicts.
- Two scripts in `reader-facing-style/`, which read those files and nothing else:
  - `style_metrics.py` writes `metrics.json` and the per-run table `metrics.txt`;
  - `sentence_lengths.py` measures prose sentences with the required citation parentheticals
    stripped first, so the measure is of the writing and not of the citation form.

Nothing below is a figure those files do not hold.

---

## 0. Verdict

The section gets its substance in nearly every run. The three-part bottom line held in all 25
runs; every quotation checked was found in its document; no overview printed SQL or a file path.
The judges passed all five of their items in 22 of 25 runs. What the outputs do badly is
readability, and the section does not ask for it:

1. **Long sentences.** With the required citations taken out, the median prose sentence is 32
   words in C-3, 34 in the vectors tier and 24 in the steering tier. One sentence in three is over
   40 words in the first two tiers, and one in five in the third.
2. **A bottom line three to five times longer than its skeleton implies.** The skeleton asks for
   "one paragraph" for each of three parts. The bottom lines run 787 to 1,640 words (median
   1,083), and the second part is a run-on catalogue of series identifiers lettered (a) to (g).
3. **Citations that are either too heavy or too short.** The full form with its link sits inside
   the sentence: 746 such parentheticals across the 25 overviews, about 14 words each before the
   link. Where runs shortened them, every shortcut differed. The judges faulted citation form in
   16 of their 25 ranking reasons, more than any other fault.
4. **More numbers than the argument needs, and untraced ones.** The median overview carries 150
   numerals besides years and 43 number-words. O2', which asks that every one have a trace-table
   row, failed in all nine of the steering tier's runs. The misses are mostly structure words:
   "five ways", "four governments", "three places".
5. **Tool talk and unexplained terms.** Across the 25: "the index" 53 times, "indexed" 26,
   "corpus" 23, "returned" 16, "full-text" 10, "hits" 8. Seven overviews name "TEI" and none
   explains it.
6. **No rule on voice.** First person runs from 2 to 31 uses an overview. In some runs it carries
   findings ("I found that …") as well as method.

The section's six rules can each say how as well as what, in about thirteen more lines. §4 gives
the text, and §5 a test that needs no research run.

---

## 1. What was measured

| | C-3 (12) | vectors tier (4) | steering tier (9) | all 25 |
|---|---|---|---|---|
| overview words, median (range) | 3,565 (2,562–4,865) | 2,537 (2,462–3,169) | 2,910 (1,953–4,026) | 3,123 |
| prose sentence, median / 90th percentile (words) | 32 / 68 | 34 / 62 | 24 / 50 | — |
| sentences over 40 words | 367 of 1,024 (36%) | 88 of 259 (34%) | 164 of 816 (20%) | — |
| bottom line words, median (range) | 1,251 (877–1,640) | 915 (787–1,083) | 956 (802–1,232) | 1,083 |
| citation parentheticals (count; median words) | 468; 14 | 48; 17 | 230; 13 | 746 |
| numerals other than years, median (range) | 216 (113–255) | 124 (107–135) | 150 (97–217) | 150 |
| number-words, median | 51 | 50 | 37 | 43 |
| quotations, median (range) | 38 (26–57) | 33 (29–44) | 25 (19–69) | 29 |
| first person "I", median (range) | 12 (2–31) | 14 (8–16) | 16 (2–30) | 14 |
| collection notes, median per collection; words a note | 44; 32 | 19; 30 | 28; 31 | 30; 31 |
| judge: all five items | 10 of 12 | 4 of 4 | 8 of 9 | 22 of 25 |

The steering tier's sentences are shorter than C-3's: a median of 24 words against 32. Nothing in
its text asked for that. Its question and its cells differ from C-3's, so this is a difference
between tiers and not an effect of either arm.

## 2. What the judges said about the writing

Each tier's last judge ranked every overview in the tier with a one-line reason. The reasons
about writing, as opposed to evidence, group like this:

- **Citation form**, faulted in 16 of 25 reasons:
  - **Repeat citations shortened** to "(Document 109, link)" after another volume's citation,
    which is misleading in print (`r7`), and repeat citations that drop the series name (`r9`,
    `r10`).
  - **Other short forms:** "the short form 'Foreign Relations, 1913'" (`r4`), block-quote
    attributions "(1877, Document 222)" with no series or link (`r6`), and "abbreviated citations"
    (`s3`).
  - **Citations by correspondent and date** in place of the document number (`r3`, `v3`, `s4`).
  - **Grouped bottom-line citations with no link** (`r8`, `v2`, `s9`). By script, 6 of the 25
    bottom lines cite more document numbers than they link.
  - **"Inline italic citations make the findings hard to read"** (`s5`), and **"the findings dump
    citation-then-quote strings at paragraph ends"** (`s1`).
  - **One citation with no link at all** (`r1`), and documents cited without links (`s8`).
- **Density**, in 4 reasons: "dense but exact" (`r2`), "the densest read" (`v3`), "paragraphs and
  method section dense enough to slow a reader" (`s6`), "and it is long" (`r1`).
- **Order**, in 2: "a preamble sits before the bottom line" (`s5`), and "the bottom line defers
  all its cites to the findings" (`v3`).
- **What the judges praised in the writing:** "plainest prose and glossed terms" (`r5`), "jargon
  glossed" (`r12`), "the sharpest decisions list (each with its consequence stated)" (`v1`), and
  "a bottom line a historian can use on its own" (`v1`).

A worked example of the heavy form, from the overview the steering tier's judge ranked first
(`s9`): part 1 of its bottom line is one paragraph carrying six full citations inside it, three of
them with their links. Part 2 is a single paragraph of twelve lettered entries, (a) to (g) and (a)
to (e), each series with its record group, entry, lot, identifier, dates and restriction. The
judge ranked it first for its evidence and called "the bottom line's unlinked grouped citations"
its only blemish. Both parts are what the section asks for; neither is easy to read.

## 3. The six rules, read for how as well as what

| rule (as it stands) | what the runs did | what the rule leaves unsaid |
|---|---|---|
| plain prose, no SQL, ids, paths | held: O1 failed once in 25 runs; O4 held in 9 of 9 | the collection's prose and notes, which carried vector words in all 4 of the vectors tier's runs, and tool words ("the index", "hits", "returned") |
| the three-part bottom line | held: O3 held in 25 of 25 | how long; that part 2's "two lists" may be real lists; that nothing comes first |
| cite as the printed edition, then the URL | held in form (J3 failed once), with a heavy or varying apparatus | where a citation goes; one short form for running text; never repeat one a paragraph gave |
| every number a count of a named set, in words | O2 failed in 7 of 25; O2' in 9 of 9 | that structure words are numbers; that fewer numbers read better; the check that finds the misses |
| quotations verified; cited documents collected | held: no fabrication in 25 runs | — |
| explain a technical term or do not use it | "TEI" unexplained in 7 overviews; "the index" 53 times | the common tool words and their plain substitutes |

The steering review's R9, R11 and R13 address three of these gaps: the numerals check and the URL
exception, the collection's prose and notes, and the overview read without the memo. They came to
this pass when the owner adopted the section's substance and scope. §4 folds them in.

## 4. Proposed wording

**R1. The section, revised for style and language.** This replaces the §12 block's
READER-FACING OUTPUT section: 17 lines as it stands, 30 as proposed. The numbers bullet was
revised after the pilot (§8); the 28-line text the pilot measured is in
`reader-facing-style/pilot/prompts/`. Every requirement of the present text survives; the
additions say how. They come from §3's gaps and the steering review's R9, R11 and R13.

```text
READER-FACING OUTPUT — the overview and the collection are for a historian, not for me
- Write the overview, and the collection's introduction, prose and notes, in plain prose for a
  reader who never sees the memo. No SQL, no table or column name, no volume_id/document_id
  string, no file path, no issue number. Those belong in the memo, which keeps every one.
- Nothing comes before the bottom line but the title. Its three parts, in this order, before
  any finding: (1) what FRUS answers directly, in one paragraph of about 150 words, citing the
  documents it rests on; (2) where FRUS points for the rest, as two bulleted lists, one series
  to a line, by title, record group and entry, NARA identifier, dates and access: the series the
  documents came from, then the series the footnotes cite unprinted; (3) what this request
  cannot get from FRUS, each as a search you ran, with its terms, volumes and controls, and the
  shelf if one exists.
- In the text, cite a document by year, volume and number: "(1948, Volume VII, Document 506)".
  End with a list headed "Documents cited", each cited once in full as the printed edition —
  "Foreign Relations of the United States, 1958–1960, Volume VII, Part 1, Document 12" — then
  the history.state.gov URL. Never cite by title, date or correspondent alone.
- Give every number as a count of a named set in words ("about one document in seven among the
  43 volumes indexed"), rounded to what the comparison needs, and only the numbers the argument
  needs. "Three ways" and "four governments" are numbers too. Do not count the overview's or the
  collection's own parts ("the collection's sections", not "its six sections"), and say nothing
  of the memo. Before you finish, list every numeral and number-word in the overview and find
  each in the memo's trace table.
- One claim to a sentence, and few sentences over 30 words. Put a quotation in its sentence or as
  a block quote with the short citation, and do not repeat a citation the paragraph gave.
- Write "I" for what you did and decided; let the documents' own actors carry what the record
  shows.
- Every quotation in the overview is one the memo verified against its document; every document
  the overview cites is in the collection. Check both before you finish, and say you did.
- Explain a technical term the first time it appears, in the sentence, or do not use it: "the
  search treats 'clearing agreement' and 'clear agreement' as the same words", not "stem";
  "found", not "returned" or "hits"; "the volumes' source files", not "TEI".
```

**Its cost.** The block grows from 205 lines to about 218. That is 6%; C-0c measured 27% at no
attention cost, and the steering tier's longer arm B lost one more item than the block as it
stands.

**R2. The overview template follows it** (guide §14.16, and the harness's deliverable skeleton):
- a `## Documents cited` heading after *Read next*;
- part 2 of the bottom line as two lists.

The judge's J3 is reworded to accept a full citation in that list ("cited in full, with its link,
in the text or in the Documents cited list"). Without the rewording, J3 would read a short form in
the text as a fault.

**R3. Nothing changes in the collection's format.** §15.1a's attribution line, its excerpts and
its prose blocks stand. R1's first bullet only names the collection's text as reader-facing, as
the section's heading already does.

## 5. The test: the same memos, written twice

The pass needs no research run, because the writing can be tested on what the research already
produced. Each run's memo is fixed, and so are its verified quotations, its trace table and its
collection. Two writers turn the same memo into an overview: one under the section as it stands,
one under R1. A blind judge compares the pair.

- **The writer:** the run's own model and effort, so that within a pair only the wording differs.
  It is handed:
  - the memo, the collection file and the question;
  - the skeleton (R2's form for the new wording);
  - one of the two section texts;
  - the rule that every quotation and figure comes from the memo.

  It writes `overview.md` alone. The collection's notes are a second step, once the overview
  passes.
- **The instruments:**
  - **`style_metrics.py` and `sentence_lengths.py`** on every rewrite;
  - **the reader judge on Fable 5.1 at `max`**, blind to the wording (a seeded A/B order with a
    keymap), on J1–J5 with J3 as R2 rewords it, citation consistency, tool words, and a preference
    with its reason;
  - **a scorer for O2'**, every numeral and number-word against the memo's trace table.
- **The pilot: four runs, one from each source and both model families.**
  - `r12`, which C-3's judge ranked first;
  - `r8`, Fable at `medium`, whose bottom line carries no links;
  - `v3`, the vectors tier's "densest read";
  - `s3`, which the steering tier's judge ranked last.
- **Readings, written first.** In the pilot, under R1 against the section as it stands:
  1. the median prose sentence is 22 words or fewer, and at most one in ten is over 40;
  2. part 1 of the bottom line is 200 words or fewer;
  3. O2' holds in at least 3 of 4;
  4. J1–J5 are no worse;
  5. the citation form is consistent in 4 of 4;
  6. the judge prefers R1's overview in at least 3 of the 4 pairs.

  If they hold, all 25 runs are rewritten the same way and read on the same six. If they do not,
  R1 is revised before anything else is spent.
- **The cost, to be set by the owner before the pilot.** A writer reads a memo and writes about
  3,000 words, which is far less than a research session. A judge reads two overviews, about what
  the steering tier's judges took (3 to 8 minutes each). Guessed from those figures, and to be read
  off the meter after the pilot:
  - **the pilot:** eight writers, four judges and four O2' scorers, about 1 to 2 weekly points and
    3 to 5 Fable points;
  - **all 25:** about 5 to 8 weekly points and 15 to 25 Fable points.
- **What it cannot show.** Whether R1 holds while the agent is also doing the research under the
  whole block. The next full tier checks that. By the steering tier's rule it also owes a
  measurement of R7, R8 and R10 alone, and the two belong in one tier on one of the owner's
  unused questions.

## 6. What not to change

- **The three-part bottom line, the decisions list and the collection contract.** They held in
  every run. `v1`'s decisions list, each with its consequence, is the model the judges praised.
- **The citation's content.** Every document is still cited in full as the printed edition with
  its link. R1 moves the full citation, and the short form in the text points to it.
- **The quotation and collection checks**, which no run broke.

## 7. Open to the owner

1. Whether R1, with R2's template and J3 change, is the wording to test.
2. The pilot's lines on the weekly and Fable meters, and when it runs.
3. Whether the collection's notes are rewritten in the full pass, or only the overview.

## 8. The pilot, run 2026-10-30

Run on the owner's word ("Run the pilot"), with the lines raised once ("Raise the lines") after the
first two pairs cost more than §5 estimated. The record is `reader-facing-style/pilot/`:
- `generate_r.py`, which cuts both section texts and both skeletons by marker, with their SHA-256
  in `pins.json`;
- the prompts, the keymap (seed 20261030; the A/B order differs by pair), `results.json` and
  `pilot_results.md`;
- every rewrite with its trace table, and the meters before and after each step in `usage.md`.

The writers were each source run's own cell: Sonnet 5.5 at `high` for `r12` and `v3`, Fable 5.1
at `medium` for `r8`, and Opus 5.5 at `medium` for `s3`. The judge and the O2' scorer ran on Fable
5.1 at `max`. In each cell below, the current section's figure comes first, then R1's.

| pair | source | median sentence | over 40 words | part 1 words | bottom line words | untraced numbers | judge items | one citation form | judge prefers |
|---|---|---|---|---|---|---|---|---|---|
| P1 | `r12` | 29 → 16 | 30% → 4% | 394 → 163 | 1,476 → 1,021 | 16 of 132 → 1 of 92 | 4 → 5 | no → yes | R1 |
| P2 | `r8` | 42 → 23 | 52% → 18% | 387 → 211 | 1,280 → 1,230 | 6 of 66 → 2 of 58 | 5 → 5 | yes → yes | R1 |
| P3 | `v3` | 34 → 20 | 35% → 2% | 390 → 162 | 1,570 → 880 | 2 of 112 → 1 of 71 | 5 → 5 | yes → yes | R1 |
| P4 | `s3` | 29 → 18 | 26% → 2% | 333 → 176 | 1,219 → 837 | 5 of 62 → 1 of 42 | 5 → 5 | yes → yes | R1 |

Pooled over the four rewrites of each wording, the median sentence fell from 33 words to 18.5,
and sentences over 40 words fell from 111 of 311 (36%) to 35 of 538 (7%). R1's rewrites carry
263 counted numbers against 372, and 5 untraced against 29. They also carry far fewer tool
words: 11 against 41.

**The six readings:**
1. **Sentence length holds pooled**, and in 3 of 4 rewrites: `r8`'s, by Fable at `medium`, has a
   median of 23 and 18% over 40.
2. **Part 1 within 200 words holds in 3 of 4:** `r8`'s ran to 211.
3. **Every number traced fails: 0 of 4**, under the current section as under R1. Every one of R1's
   five misses is a count of the overview's or the collection's own parts ("six sections", "two
   channels"), or a sentence about the memo ("the one case where the memo records …"). None is
   a historical figure. The scorer called "six sections" "a fact about the collection that the
   memo cannot hold".
4. **J1–J5 no worse: holds.** R1 scored five of five in 4 of 4; the current section in 3 of 4.
5. **One citation form: holds in 4 of 4**, against 3 of 4.
6. **The judge preferred R1 in 4 of 4.**
   - P1: "A reads as an essay: its short keyed citations … are resolved by a full 'Documents
     cited' list".
   - P4: "it reads as an argument first and a dossier second".

**What §5's rule makes of it.** Reading 3 failed, so R1 is revised before anything else is spent.
The revision the misses point to is one sentence in the numbers bullet, now in §4's text:
- a count of the overview's own parts, or the collection's, is written without its numeral ("the
  collection's sections", "the two channels" becoming "the channels");
- a sentence about the memo has no place in a text the historian reads without it.

`r8`'s near misses on readings 1 and 2 were Fable at `medium`, a cell §3a does not recommend. The
two recommended cells met both readings in 3 of 3.

**Two things the pilot found beside the readings.**
- **First person rose under R1:** 130 uses of "I" against 54. The judge did not fault it; the
  next measurement should watch it.
- **The cost:** 5 weekly points and 8 Fable points, against §5's 1 to 2 and 3 to 5. The O2'
  scorer on Fable at `max` took nearly half of it (352K of the first two pairs' 764K output
  tokens). At this rate the full pass over 25 runs would cost about six times the pilot.
  Before it runs, the scorer should be a script that lists each overview's numerals and checks
  them against its trace table, with an agent reading only the ones the script flags.

**The owner's decision, 2026-10-30: the full rewrite pass is skipped** ("Skip the full pass"). The
pilot's six readings answered what the pass was for. The revised R1, with R2's template and J3
wording, goes to the next full tier instead, which tests the wording while the agent also does the
research. That tier also carries the re-measurement of R7, R8 and R10 that the steering tier's rule
owes, on one of the owner's unused questions.
