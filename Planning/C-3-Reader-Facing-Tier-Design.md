# C-3, the reader-facing tier — R1's wording under research, and R7, R8 and R10 measured without the rest of arm B, Opus 5.5 at `medium` and Sonnet 5.5 at `high`

**Status:** DRAFT, 2026-10-30, with all five of its choices answered by the owner the same evening
(below). Nothing has run and nothing below is built. The design rests on two decisions of the
owner's of 2026-10-30:
- **"Skip the full pass."** The revised R1, R2's template and J3's rewording go to the next full
  tier, which tests the wording while the agent also does the research
  (`Agentic-Guide-Reader-Facing-Style-Review-2026-10-30.md` §8).
- **"Follow the rule."** The steering tier's rule owes R7, R8 and R10 a measurement without the
  rest of its arm B (`C-3-Steering-Tier-Results-2026-10-30.md` §4).

Successor to `C-3-Steering-Tier-Design.md` (R16), whose harness, instruments and record format it
reuses. Working folder `~/frus-analysis/c3f/`; record `c3-reader-facing-tier/`. **The question is
not printed here** (§1).

**The owner's answers of 2026-10-30, and what each changes below.**
1. *"Bullet in W, no card"*: R6's vocabulary bullet goes in arm W, at the end of the addendum
   (§2.2). The vectors card does not go. Its spot check is designed and measured (§5.2), for the
   tier that carries the card.
2. *"Three arms, 12 runs"*: A, W and K, two runs of each per cell (§2). The alternative was two
   arms and eight runs, about a third cheaper, with one treatment carrying every part under one
   guard, as R16's did.
3. *"One-item tolerance"*: a treatment arm loses at most one more of the 35 items than A, and no
   run of it loses two (§8).
4. **The question:** the owner chose one of the four unused candidates and gave its text in chat.
   It is in no file (§1).
5. *"Set as recommended"*: the lines are the starting reading plus 32 points of the weekly
   all-models meter and plus 54 of the weekly Fable meter, and the tier starts after the meters
   reset on 2026-11-04 (§7).

**Numbering.** R1 to R3 are the style review's (§4). R6 to R10 are the steering review's
(`Agentic-Guide-Steering-Review-2026-10-27.md` §3). The two documents number independently, and
no other label of either is used below.

**Why this tier.** Two measurements are owed, and the style review's §5 puts them in one tier on
one of the owner's unused questions.
- **R1 while the agent does the research.** The pilot rewrote four finished memos' overviews under
  R1, and the judge preferred R1 in 4 of 4 pairs. It could not show whether R1 holds while the
  agent also searches, reads and resolves archives under the whole block. R1's numbers bullet was
  revised after the pilot, so the text this tier carries has not been measured at all.
- **R7, R8 and R10.** R16's arm B lost one more of the 35 items than A, on O2, a rule B did not
  touch, so none of B was adopted. By its rule these three are measured again as a smaller
  treatment.

Two harness fixes come first (§5): V4 exempts `frus1977-80v09Ed2`, and O2' is checked by a
script, with an agent reading only what the script flags.

---

## 1. The question

**Not printed in any planning document before the run.** This is C-0c's rule, so that no agent can
have read an answer (`C-3-Reader-Test-Design.md` §1). The owner chose one of four unused
candidates on 2026-10-30 and gave its text in chat. It is written into no file until the owner
sets the run. Then the session that runs the tier takes it from the owner into
`~/frus-analysis/c3f/question.txt`, the generator pastes it from there, and the record prints it
afterwards.

**The properties.** They are R16's (its design's §1), with three added for what this tier
measures. The session that runs the tier checks the question against them before the first cell,
from the index copy read-only. Its files stay in its scratchpad and are deleted before the first
cell, and a property that fails goes to the owner before any cell runs. What the question should
give each reading goes into `~/frus-analysis/c3f/expectations.md` before the first cell, so that
the result can contradict it.

| property | why it matters here | how it is assessed, from the index copy read-only |
|---|---|---|
| **Not one of the ten questions already used**, and printed nowhere in the repository | C-0c's rule | the list (`C-3-Reader-Test-Design.md` §1, then recognition in Latin America, Cuba since the 1870s and corruption); a grep of `Planning/` and `Docs/` for its terms |
| **At least three eras with material** | each era needs its own anchors and its own words | the scope's documents by era |
| **Words that change over time, with stems shorter than their common forms** | R8 needs occasions: a `term*` written past its stem, or a stem cut by hand, reaches nothing | the main terms and their variants by decade; their stems in `frus_documents_vocab` |
| **All three parts of the bottom line non-trivial, with series in both channels** | R2 turns part 2 into two lists, and R1 bounds part 1 | documents that answer directly; `document_sources` and `external_citations` rows in the scope; a part FRUS cannot answer |
| **Absences to report, and material before 1940** (added) | R10 needs zeros to set beside a relaxed query, and R7's pre-war roadmap figure needs a pre-war scope | the part FRUS cannot answer; the scope's documents before 1940 |
| **A scope a session can read in 20 to 30 minutes** | the cells' wall clock is a reading | the scope's size |
| **Room for the vectors** (preferred) | every arm hands over the artifacts, and V8 needs vector work to keep out of the historian's text | R16's test: for two or three anchors per era, the share of their 25 nearest neighbours outside the heading scope and without the subject's words |

R16's first property, documents spread under other subjects' headings, is preferred and not
required: it served the reach reading, and this tier decides nothing on reach.

## 2. The arms and the runs

The cells are C-3's two recommended ones: **O-med** (`claude-opus-5-5`, `medium`) and **S-high**
(`claude-sonnet-5-5`, `high`). Three arms, two runs of each per cell: twelve runs.

| arm | what it carries | what it measures |
|---|---|---|
| **A** | the guide as it stands, v1.38: R16's arm A, byte for byte in every guide text a prompt carries | the control |
| **W** | A, with R1 in place of READER-FACING OUTPUT, R2's skeleton in the deliverable, and R6's vocabulary bullet at the end of the addendum | R1, R2 and the bullet while the agent does the research |
| **K** | A, with R7, R8 and R10 in the block as R16's arm B carried them | the three rules, without the rest of arm B |

The runs go in four blocks, one cell and one replicate each. The order within a block rotates, so
that no arm always runs first:

| block | cell | runs, in order |
|---|---|---|
| 1 | O-med (1) | A, W, K |
| 2 | S-high (1) | W, K, A |
| 3 | O-med (2) | K, A, W |
| 4 | S-high (2) | A, W, K |

Each run has the scorer and the refuter on `claude-fable-5-1` at `max`. Each block has one judge on
the same model after its third run (§4.2). All are blind to the arm through opaque labels
(`f1`–`f12`) and a keymap.

### 2.1 Arm A, the control: the guide as it stands

A is cut from `v2` at `848f3781`, which carries guide v1.38. Three texts in it are byte-identical to
R16's arm A, which was cut from v1.37 (checked 2026-10-30):
- the §12 block: 205 lines, SHA-256 `c2f5511d…`, the block C-3 measured;
- §A.8's addendum: 15 lines, `e8117cb8…`, pasted at the block's end as §3a says;
- Appendix A, whole: 346 lines, `4e11cc17…`.

v1.38 changed §3a, §14.16, §14.17 and the version history, and a prompt carries none of them. The
rest of A's prompt is R16's arm A: RESOURCES items 1 to 4, the HARD CONSTRAINTS, the tooling notes
with the corrected numpy line, and the deliverable with its five-operation VECTORS sentence.

So A is R16's control on a new question. Its four runs can be set beside R16's four A runs: one
text read on a second question, which is not a replication.

### 2.2 Arm W, the reader-facing wording

W is written as the guide's own text, a v1.39 candidate on a local branch of its own
(`claude/c3-reader-facing-arm-w`, from `848f3781`), merged only if §8 adopts it. It carries:
- **R1:** the READER-FACING OUTPUT section replaced by the style review's §4 text, as `v2` holds it
  at `848f3781`. That is 30 lines, SHA-256 `d08e51eb…`, against the present section's 17
  (`8fbf4c7a…`). It is the revised text: its numbers bullet now says not to count the overview's
  or the collection's own parts and to say nothing of the memo, which the pilot did not measure.
  The block grows from 205 lines to 218.
- **R2:** the overview template of §14.16 and the deliverable's skeleton:
  - part 1 of the bottom line, one paragraph of about 150 words;
  - part 2, two bulleted lists, one series to a line;
  - a `## Documents cited` heading after *Read next*, every cited document once, in full as the
    printed edition, then its history.state.gov URL, in the order first cited;
  - in the text, a document cited by year, volume and document number.

  In the prompt these are the four replacements the pilot's `generate_r.py` made to R16's
  skeleton, made the same way.
- **R6's vocabulary bullet:** the last bullet of R16's SEMANTIC VECTORS section, appended to §A.8's
  addendum, which grows from 15 lines to 18:

  ```text
  - None of this vocabulary reaches the overview or the collection: no Hamming, cosine, cluster
    number, "vector" or "neighbour at N". Say "found by its similarity to [the document], by no word
    search, and read before it was cited".
  ```

  R16 measured it inside the section: V8 obeyed in 4 of 4 B runs and in none of A's. Here it is
  measured in the addendum, the only vector text a v1.38 prompt pastes.
- **R3:** nothing changes in the collection's format.

J3's rewording is not W's: the judge is an instrument, so the rewording applies to every arm
(§4.2). W's pasted rules come to 236 lines against A's 220, and the skeleton adds two more.

### 2.3 Arm K, the three rules

K is the v1.39 candidate on `claude/c3-reader-facing-arm-k`, from `848f3781`. Its three edits are
R16's `make_arm_b.py` replacements, unchanged:
- **R8:** KNOWN TRAPS gains, after the stemming bullet, three lines: a `term*` prefix is matched
  against stems (`normaliz*` cannot reach `normalization`, and `communis*` misses `communism`);
  look the stem up in `frus_documents_vocab` and write the prefix no longer than it.
- **R10:** REPORTING's zero bullet becomes: if a query returns no rows, say so, and print beside it
  the relaxed form of the same query, on the same surface, that did return rows, with its count; a
  zero with no such query beside it is an assertion, not a measurement.
- **R7:** ARCHIVAL SCOPE's "11 of 695 bundled series" becomes the guide's measurement ("about one
  bundled series in sixty starting before 1940"), to be re-derived from `series-facts-index.json`
  before one is printed. REPORTING gains the rule that a figure taken from these rules or from the
  guide is the guide's measurement at its date: re-derive it or attribute it, and never present it
  as a result of the session.

The block grows from 205 lines to 212. R5's clause on the Ed2 line does not go, because it names
the SEMANTIC VECTORS section, which K does not carry. K keeps A's Appendix A and A's deliverable.

### 2.4 Not carried

- The vectors card (the owner's answer 1), R6's SEMANTIC VECTORS section other than its last
  bullet, and R5's clause.
- The steering review's R1 and R3 deliverable sentence: every arm keeps the vectors tier's
  five-operation sentence (limitation 6).
- R9, R11 and R13, which R1 folds in.
- A run without artifacts: R16's run 9 measured that branch, and no arm here has a conditional
  section.
- A free-text arm, as in the two tiers before it.

## 3. What is measured, per run

Everything R16 measured (its §3), plus:
- **The writing**, by `style_measure.py`, the pilot's measures on every overview:
  - words, the median prose sentence and the share over 40 words, with citations stripped;
  - the words of part 1 and of the bottom line, and the list lines in part 2;
  - whether a Documents cited list is present, and how many of the text's short citations
    resolve to an entry in it;
  - full citations and links, numerals and number-words, tool words, and first person.
- **The numbers:** O2' from the script and the scorer's reading of its flags, with each run's
  untraced numerals counted (§5.3).
- **R8's occasions** (`match_check.py`, §5.4): every full-text term the session's logged commands
  and scripts ran, bare, phrase or `term*`, that returns no document in the copy, with the nearest
  form that does; and for each prefix, whether the log looked its stem up in
  `frus_documents_vocab` before its first use.
- **R10's occasions** (the refuter's zeros step): each zero the memo or the overview reports, and
  what stands beside it. That is the relaxed form of the same query with its count, another query
  shown to return rows on that surface, or nothing.
- **R7's occasions** (`figures_check.py` and the refuter's step on the house rules' figures):
  where the memo and the overview print a figure the house rules print, and whether each is
  re-derived, attributed, or presented as the session's own finding.
- **The judge's block ranking**, and per overview J1–J5, one citation form, and the tool words.

The quality score is over the 35 items, as before. The V and O items are reported beside it.

The occasions are there. In the 25 runs of the three tiers:
- MATCH prefixes appear in the logs or scripts of 18.
- The block's "11 of 695" is printed in the memo or the overview of three of R16's four A runs.
  One attributes it (s8, "per the house rules"); two give it as their own (s5, s7), and R16's
  scorer faulted neither, so P6 does not measure R7.
- R16's one T1 loss (s6) was a bare `MATCH 'misappropriat'`, a stem cut by hand, not a prefix. So
  the script tests bare terms too.

## 4. The instruments

### 4.1 The rubric: R16's 44 items, two of them reworded

The scorer scores the same 44 items: C-3's 35, V1–V6, V8, O4 and O2'. V7 stays the refuter's.
Two texts change, the same for every arm:

| id | as R16 scored it | as this tier scores it | why |
|---|---|---|---|
| V4 | Suppressed edition twins on every neighbour surface (the Ed2 volumes, cosine 1.0 to their first editions) | the same, for the Ed2 volumes whose first editions are in the corpus, `frus1951-54IranEd2` and `frus1969-76ve15p2Ed2`; `frus1977-80v09Ed2` has none, the block says never to fold it, and its documents in a list are not a violation | R16 results §5 item 10: s3 lost V4 for `frus1977-80v09Ed2/d198` in a neighbour list |
| O1 | The overview contains no SQL, column or table name, id pair or file path | the same, with "no id pair outside a history.state.gov URL" | the citation form requires the URL, whose path is the pair; O4 and J5 already except it |

O2' is scored from the script (§5.3) rather than from the scorer's own list. So V4, O1 and O2' do
not compare with R16's item for item. Within the tier one instrument scores every arm.

### 4.2 The judge: one a block, three overviews at a time

R16's judge ranked every overview judged so far, so its last one read nine; with twelve, it would
read twelve. Here each block's judge runs after the block's third run. It reads that block's three
overviews and collections, labelled X, Y and Z in a seeded order, and returns for each:
- J1–J5, with J3 and J5 as the pilot worded them (below);
- **citations:** yes if one citation form is used throughout and every cited document can be found
  in full with its link;
- **tool words:** every word of the research machinery a historian would not know, and every
  technical term left unexplained, each with where it appears, or "none".

Then it ranks the three, best to worst for the historian, with a reason. Within a block the cell,
the replicate and the question are the same, so the ranking sets the arms side by side on equal
terms.

J3 and J5 are the pilot's wording, for every arm:
- **J3:** every document the overview cites is cited in full as the printed edition (Foreign
  Relations of the United States, years, volume, part, document number) with a history.state.gov
  link, *in the text or in a list of the documents cited*; "no" if any is cited by a bare id pair,
  or by title, date or correspondent alone with no full citation anywhere.
- **J5:** no SQL, no table or column name, no `volume_id/document_id` string *outside a link*, and
  no file path.

### 4.3 The refuter: R16's seven steps and three more

R16's steps 1 to 7 stand. Step 3 resolves a short citation through the overview's Documents cited
list where there is one. Three steps are added:
8. **Zeros.** List every result the memo or the overview reports as zero, none, absent or not
   found. For each, say what the memo prints beside it: the relaxed form of the same query on the
   same surface with its count, another query shown to return rows on that surface, or nothing.
9. **The house rules' figures.** `figures_check.py` lists where the memo and the overview print a
   figure the house rules print. For each, say whether the session re-derived it (its query or
   script shown, with the output), attributed it to the guide or the rules, or presented it as its
   own finding.
10. **Terms that reach nothing.** `match_check.py` lists every full-text term the session ran that
    returns no document. For each, say whether the memo or the overview reports a count or an
    absence from it, and whether the session noticed: said the term reaches nothing, or replaced it.

The scorer may read the same list for T1.

## 5. Harness fixes

### 5.1 V4 exempts `frus1977-80v09Ed2`

As §4.1's table. `frus1977-80v09`, its would-be first edition, is in neither the vector index nor
the copy, which holds the Ed2 volume's 418 documents alone. Appendix A's code, which A, W and K all
carry, needs no change.

### 5.2 The card's spot check, designed for the tier that carries the card

The card does not go in this tier (the owner's answer 1). Its fix is recorded here, measured, so
that the tier which carries it starts from it.

Two of R16's four B runs lost V2: the card carries no known answer to check a decode against.
Appendix A §A.5 prints `frus1861/d111`'s ten neighbours, but the card prints no figure, because
every distance is one generation's. This check needs none.

It uses one letter printed twice: Mr. Blaine to Mr. Comly, `frus1881/d405`, reprinted as
`frus1894app2/d394`. The copy holds them at 14,627 and 14,625 characters. Each is the other's
nearest neighbour. `frus1894app2` holds `d2a` at its third row, so an id derived from a row's
ordinal puts `d394` on the row of `d393`, another letter between the same two men, and the check
fails.

Measured 2026-10-30 at digest `89481b18…`, read-only:
- the stored decode puts them at rows 18290 and 28290, at Hamming 4;
- the next neighbour of either is at 75 or 77;
- the ordinal-derived row for `d394` is 28289, `frus1894app2/d393`, at 85 from `d405`.

42 of the 553 volumes hold an id that a decode from ordinals mis-keys. `frus1861` is not one, so
`frus1861/d111` checks a decode's offsets and not its handling of a suffix.

The card would gain, after its neighbours block:

```python
# Spot check: one letter printed twice, in 1881 and in the 1894 appendix. frus1894app2 holds d2a
# at its third row, so an id derived from a row's ordinal puts d394 on d393's row, another letter
# between the same two men, and this check fails.
a, b = ("frus1881", "d405"), ("frus1894app2", "d394")
assert nearest(a, 1)[0][1] == b and nearest(b, 1)[0][1] == a, "the decode mis-keys a row"
print("spot check:", a, row_of[a], b, row_of[b], "each the other's nearest neighbour")
```

That tier's canary runs it twice: with the card's decode it must print rows 18290 and 28290, and
with ids derived from ordinals it must fail. V2's `obeyed` text then names both known answers.

### 5.3 O2' by a script, with the scorer reading only what it flags

The pilot's O2' scorer, on Fable at `max`, took 352K of the first two pairs' 764K output tokens.
R16's scorers listed every numeral themselves and drew the line in different places: s7's set
aside the archival identifiers and the pronoun "one", and s9's listed every NAID, entry and lot. A
script gives every arm one list.

`o2p_check.py <run directory>` does four things:
1. **Lists the overview's numbers.** These are numerals, number-words, fractions and multiples
   ("half", "twice"), ratios ("one in a hundred"), and ordinals that rank a quantity
   ("second-largest"). It leaves out what the rubric excepts: years and dates; document, volume
   and part numbers; numbers inside a citation or a link; and the Documents cited list. List
   markers ("First, …", "the first finding") are left out too. Archival identifiers stay in, since
   the rubric excepts none; a row that covers them as a group traces them.
2. **Finds the trace table.** That is the first table after a heading that names it, as in all nine
   of R16's memos. Its first column is the overview's side.
3. **Classes each number:**
   - **traced**, when a row's first column holds the same value followed by the same word;
   - **weak**, when some row holds the value without that word;
   - **untraced**, when no row holds the value.
4. **Writes and prints.** It writes `o2p_flags.json`, and prints the weak and untraced numbers with
   their sentences.

The scorer runs it and reads only the weak and untraced numbers. It decides each one: traced,
naming the row that holds it in another form; not a number, for a "one" that is a pronoun ("no
one", "one of them"); or untraced. O2' is violated if any number is untraced. The scorer does not
list the overview's numbers itself.

**Calibration** (§6, step 0) runs the script on R16's nine runs and the pilot's eight rewrites, at
no agent cost. Every miss their scorers named must come back weak or untraced, apart from list
markers, which the script leaves out by rule. The count of flags is the reading load, recorded per
run.

### 5.4 Scripts for R7's and R8's occasions

- **`match_check.py <run directory>`** reads `queries.log` and the run directory's `.sql`, `.py`
  and `.sh` files, and takes the terms of every MATCH expression. It counts each term alone
  against the copy, read-only. A term that returns no document is listed with the line that ran
  it and the nearest form that does. For a prefix, that form is the prefix shortened letter by
  letter; for a bare term, the term as a prefix, then shortened. For each prefix the script also
  says whether a `frus_documents_vocab` lookup of its stem comes before its first use.
  - Known answer: s6's `MATCH 'misappropriat'` returns 0, where `misappropriation` returns 93.
- **`figures_check.py <run directory>`** lists each occurrence, in `memo.md` and `overview.md`, of
  the measurement figures the arm's block prints, with its sentence. The generator cuts the list
  from each arm's block: "11 of 695", or in K "one bundled series in sixty"; 74,043; 5,798; 14%;
  4–10%; 56%; 718; 701; 35,125; 36,615; 1910-12-06. 553 is left out, since every run re-derives it
  with its coverage query.
  - Known answer: the vectors tier's v2 printed "11 of 695 bundled series" as its own finding, and
    lost P6 for it.

### 5.5 The rest of the harness, from R16's

- **`generate_f.py`**, from `generate_s.py`: the three arms from pinned commits, the instruments,
  the block judges, the scripts' paths, the keymap and `pins.json`.
- **The workflow:** for each run, the run, then the scorer and the refuter in parallel; after a
  block's third run, its judge. One step at a time, with the meters read between steps.
- **`results_f.py`**, from `results_s.py`: the table, the writing table and §8's readings.
- **`tally.py`, `save_verdicts.py` and `summ.py`** as they are, with the arms read from the
  keymap.

## 6. Order, calibration, canary and the stop rule

0. **Calibrate the new and changed instruments on known answers.** An instrument that misses any
   of these is broken.
   - **The three scripts, at no agent cost:**
     - `o2p_check.py` over R16's nine overviews and the pilot's eight (§5.3);
     - `match_check.py` on s6, which must list `misappropriat`;
     - `figures_check.py` on the vectors tier's v2, which must list "11 of 695".
   - **The scorer**, with the reworded items and the flags, on R16's s1 and s3:
     - s1's O2' misses must come back: "five ways", "two departing officers", "four threats",
       "five groups", "three things" and the rest R16's scorer named;
     - so must s3's: "three ways", "five word families", "two second editions", "Eight months
       later", "five findings" and the rest;
     - s3's V4 must come back obeyed under the exemption;
     - every other item must come back as R16 recorded it, O1 aside. A difference elsewhere is
       recorded and read, as R16's calibration read the three items it found stricter.
   - **The refuter's three new steps, alone:**
     - on the vectors tier's v2, whose "11 of 695" is a finding of its own;
     - on C-3's r3, which lost R3 for an empty query with nothing beside it that returns rows.
   - About 2 weekly points and 4 Fable points.
1. **The canary.** One O-med agent on the arms' exact RESOURCES text must:
   - run the CANARY command and the read-only proof;
   - decode 553 of 553 volumes with Appendix A §A.3's code;
   - reproduce `frus1861/d111`'s ten neighbours as `vectors_check.py` holds them.

   A failure ends the tier before it costs a cell.
2. **Blocks 1 to 4**, in §2's order, with the meters read before and after every step.

**Stop rule:** C-3's. Before any step whose projection crosses a line, stop and ask the owner
rather than end.

## 7. Budget

**What was measured.**
- **R16:** its nine runs with their instruments moved the weekly all-models meter 1 to 3 points a
  run (mean 2.0) and the weekly Fable meter 3 to 5 (mean 3.4). Calibration and the canary moved
  them 1 and 3. In all: 19 weekly points and 34 Fable, 5 h 42 m elapsed
  (`c3-steering-tier/usage.md`).
- **The pilot:** 5 weekly points and 8 Fable, where its review had estimated 1 to 2 and 3 to 5. The
  O2' scorer took nearly half of it (`reader-facing-style/pilot/usage.md`).

**What changes.** The block judges, four reading three overviews each where R16 had nine reading a
growing list, and O2' by script both make the instruments cheaper. The refuter's three steps make
them dearer. A run with its instruments is taken at R16's figures.

| | weekly points | Fable points |
|---|---|---|
| twelve runs with their instruments | 22 to 26 | 38 to 44 |
| with calibration and the canary | 24 to 28 | 42 to 48 |
| **the lines** (the owner's answer 5), above the starting reading | **plus 32** | **plus 54** |

**When.**
- **The meters now.** At about 23:20 on 2026-10-30 they read 29% weekly and 44% Fable, both
  resetting on 2026-11-04 at 15:59 UTC (10:59 local, the clocks having gone back).
- **Before the reset**, the tier would take the Fable meter to about 90%. So it starts after the
  reset (the owner's answer 5), when the lines sit near 32% and 54%.
- **Elapsed:** R16's runs took 26 to 45 minutes each with their instruments, so twelve take about
  seven to eight hours from the calibration to the last judge. Start in the morning.

## 8. The readings, pre-registered

**Arm W, against A on the same cells and replicates:**
1. **The reader.** The judge ranks W above A in at least 3 of the 4 blocks, and W's J1–J5, summed
   over its four runs, are no fewer than A's.
2. **The form.** In 4 of 4 W runs: one citation form throughout (the judge's citations item); a
   Documents cited list to which every short citation in the text resolves (`style_measure.py`);
   and part 2 of the bottom line as two lists.
3. **The length.** Pooled over W's four overviews, the median prose sentence is 22 words or fewer
   and at most one sentence in ten is over 40; part 1 is 200 words or fewer in at least 3 of 4.
   A's figures are reported beside them.
4. **The numbers.** O2' holds in at least 3 of 4 W runs, and O2 in 4 of 4. W's untraced numerals,
   summed, are fewer than A's.
5. **The cost.** W meets the guard on the 35 items (below).
6. **The vocabulary.** V8 holds in 4 of 4 W runs.
7. **The price**, reported: W's mean session minutes against A's. R1 adds a check of every numeral
   before the agent finishes.
8. **The voice**, reported: first person per 1,000 words, W against A. The pilot saw it rise under
   R1, from 54 uses to 130.

**Arm K, against A:**
9. **R8, the stems.** No K run reports a count or an absence from a term that reaches nothing
   without saying so: T1 holds in 4 of 4. In every K run that writes a prefix, the log looks the
   stem up in `frus_documents_vocab` before the prefix's first use.
10. **R10, the zeros.** Every zero a K memo or overview reports has the relaxed form of the same
    query beside it, with its count, in 4 of 4 runs; R3 holds in 4 of 4.
11. **R7, the guide's figures.** No K memo or overview presents a figure the house rules print as
    its own finding: each is re-derived or attributed, in 4 of 4. P6 is reported beside it.
12. **The cost.** K meets the guard on the 35 items.
13. **The price**, reported: K's mean session minutes against A's.

A reading on occasions counts only the runs that had one. If fewer than two K runs had an occasion
for 9, 10 or 11, that reading decides nothing, and its rule waits for another measurement.

**The guard on the 35 items** (the owner's answer 3): **the arm loses at most one more of the 35
than A, and no run of it loses two**, which is the same as no run falling below C-3's 0.952 floor.
R16's guard was "loses no more of the 35 than A". The reason for the change is arithmetic. Suppose
a treatment arm is exactly as good as A, and each arm loses items at random across its four runs:

| lost items expected in four runs | R16's guard fails such an arm | this guard does | either of two such arms fails R16's guard |
|---|---|---|---|
| 0.5 | 27% of the time | 6% | 44% |
| 1 | 35% | 13% | 52% |
| 2 | 40% | 22% | 56% |

The table takes each arm's losses as a Poisson count. In the same two cells, arms of four runs
lost between none and four of the 35: none in C-3, four in the vectors tier, one and two in R16.
Under this guard R16's arm B, two losses against one with no run losing two, would have passed its
reading 4. That tier's verdict stands: its rule was set before it ran.

**Adoption.**
- **W** goes into the guide as its text if (1), (2), (5) and (6) hold. That means R1 in the block,
  R2 in §14.16's template, and the bullet in §A.8's addendum. J3's and J5's wording become the
  harness's.
  - (3) and (4) decide wording, not adoption. A miss on either sends the bullet it concerns, on
    sentences or on numbers, back for revision before another tier.
- **R7, R8 and R10** each go into the block if (12) holds and the edit's own reading holds: R8 on
  (9), R10 on (10), R7 on (11).
- **One arm's result does not change the other's.** If both are adopted, the guide takes both: a
  block of 225 lines, 10% over the 205 measured, which no run here measures. C-0c measured 27% at
  no cost in attention, and §3a would say so.

## 9. Known limitations, recorded before the result

1. **n = 2 per arm per cell.** Each treatment's readings rest on four runs.
2. **W and K are each measured against A.** Their combination is not run (§8, adoption).
3. **The judge's blinding is partial.** W's Documents cited list and short citations show its arm,
   as in the pilot.
4. **The occasion readings need occasions.** A run with no prefix, no zero or no house-rules figure
   gives that reading nothing, and the readings count only the runs that had one.
5. **Three items do not compare with R16's.** O2' comes from a script now, and V4 and O1 are
   reworded. A against W and K holds, since one instrument scores all three arms.
6. **Every arm's deliverable keeps the vectors tier's VECTORS sentence, which names five
   operations, where the guide's §14.16 now names three.** It is harness text, and changing it in
   every arm would move the control off R16's arm A.
7. **The revised R1 is measured for the first time.** The pilot measured its 28-line predecessor.
8. **One question.** A's runs beside R16's give one text on two questions, not a replication.
9. **The judges rank within blocks**, so no ranking spans the tier, and none compares with R16's
   ranking of nine.

## 10. What setting this plan confirms

**Answered on 2026-10-30** (at the head): R6's bullet in W and no card; three arms; the one-item
guard; the question, given in chat; and the lines and the date, as recommended (§7).

**Setting the plan also confirms these:**
- A is v1.38's text, which is R16's arm A (§2.1);
- W and K are written as guide candidates on local branches (§2.2, §2.3);
- R1 is the revised 30-line text the style review holds at `848f3781` (§2.2);
- J3 and J5 are reworded for every arm, as are V4 and O1 (§4);
- O2' is scored by the script and the scorer's reading of its flags (§5.3);
- one judge for each block replaces R16's growing ranking (§4.2);
- the tier uses C-3's index copy (version 71) and the shards beside it, as R16 did;
- the question goes into `question.txt` when the run is set, and into the repository only with
  the record.

## 11. What the harness needs built, and nothing else

- **The two candidates on their branches**, each committed before any prompt is generated, and
  each with a version-history entry that marks it a candidate:
  - `make_arm_w.py`: once-only replacements of the guide at `848f3781`. R1 is cut from the style
    review's §4 block, the skeleton is changed as in the pilot's `generate_r.py`, and R6's bullet
    is taken from `make_arm_b.py`'s section;
  - `make_arm_k.py`: `make_arm_b.py`'s three replacements for R7, R8 and R10.
- **`generate_f.py`**, from `generate_s.py` (§5.5):
  - the three pinned commits;
  - the arms' prompts;
  - the rubric with §4.1's two texts;
  - the scorer's O2' step;
  - the refuter's three steps;
  - the block judges with the pilot's J3 and J5;
  - the canary's known answers, from `vectors_check.py`.
- **The scripts:** `o2p_check.py`, `match_check.py`, `figures_check.py`, `style_measure.py` and
  `results_f.py`, with `tally.py`, `save_verdicts.py` and `summ.py` as they are.
- **The working folder** `~/frus-analysis/c3f/`, with C-3's index copy and shards read in place.
- **The record** in `Planning/c3-reader-facing-tier/`, in the earlier tiers' layout. After it:
  - a results file;
  - `Agentic-Harness-Runbook.md` §7's cost table, which stops at the vectors tier, gains rows for
    R16, the pilot and this tier;
  - then §3a, the version history and anything adopted. The §15.1 block is unchanged
    (`CollectionTests.publishedExampleMatchesTheGuide` pins it). If R1 is adopted, §12's *Which
    surface answers which block* records the block's new measured length.
