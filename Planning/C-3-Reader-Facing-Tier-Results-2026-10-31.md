# C-3 reader-facing tier — results: R1's wording under research, and R7, R8 and R10 without the rest of arm B, on the owner's soft-power question

**Status:** RUN 2026-10-31, 00:16 to 04:46 (local), on the owner's Mac, on the owner's word of
2026-10-30 ("Build and run", after "change start date to now"). It followed
`C-3-Reader-Facing-Tier-Design.md`, with its as-built notes at its head. The record is
`c3-reader-facing-tier/`. Nothing here is a figure the record does not hold.

**The answer.** By the rules written before the run, nothing is adopted from either arm.
- **W (R1, R2 and R6's vocabulary bullet)** fails reading 1, the reader: the judge ranked W above A
  in one block of four, where adoption needs three. It also fails reading 5, the cost: W lost six of
  the 35 items against A's four, and two of its runs lost two or more.
- **K (R7, R8 and R10)** fails reading 12, the cost, on the per-run clause: one K run lost two
  items. K's arm total (four, the same as A's) is inside the guard. Its own readings fail or decide
  nothing.

The parts, read separately:
- **R1 and R2 change the writing, under research as in the pilot.** W's pooled median prose sentence
  was 19 words against A's 23, and 8% of its sentences ran over 40 words against A's 20.5%. Every W
  part 1 ran 152 to 165 words; A's ran 223 to 344. All four W overviews had one citation form, a
  Documents cited list that resolves every short citation, and part 2 as two lists. No A or K
  overview had a Documents cited list.
- **The judges preferred the writing but ranked on the evidence.** They called W's overview "the
  clearest writing" (block 2) and "the cleanest read" (block 3) and still ranked it second and
  third, on the breadth of the evidence. In block 2 the judge counted R2's short citations against
  it, because the historian has to look each one up in the closing list.
- **R6's vocabulary bullet works in the addendum.** V8 held in 4 of 4 W runs, against 2 of 4 in A
  and in K.
- **O2' failed in all twelve runs**, in every arm. R1's revised numbers bullet did not change that.
- **R10 moved one zero a run.** Every K run put a relaxed query beside its "soft power" zero; K did
  so for 5 of its 61 reported zeros in all, and A for 1 of 55.
- **R8 had almost nothing to act on.** One K run wrote `term*` prefixes (it looked up 4 of 7 stems
  first); no A run wrote any. The reading decides nothing.
- **R7 did not stop a house-rules figure being stated as the session's own.** Three K runs did so,
  mostly with the pointed-at channel's 1910-12-06 start; one K run re-derived the pre-war series
  figure from the bundle, as R7 asks.

---

## 1. What was run

- **The question** (the owner's, chosen 2026-10-30 from four unused candidates): *How did
  policymakers assess American soft power in the east Asia and Pacific region? What messaging
  strategies did they use and how effective did they think they were? What beliefs about the
  regional audience contributed to those strategies?*
- **Arm A**, the guide as it stands (v1.38, `848f3781`): R16's arm A byte for byte, apart from the
  question and the folder paths. The block is `c2f5511d…` (205 lines), with the addendum pasted and
  Appendix A whole.
- **Arm W**, candidate v1.39-W (`b40d2da6`, local branch `claude/c3-reader-facing-arm-w`): R1's
  30-line section (block 218 lines), R2's skeleton in the deliverable, and R6's vocabulary bullet in
  the addendum.
- **Arm K**, candidate v1.39-K (`5e8bd1bd`, local branch `claude/c3-reader-facing-arm-k`): R16's arm
  B texts of R7, R8 and R10 (block 212 lines).
- **The runs:** four blocks, one cell and replicate each, the arms rotated: O-med (1) A W K; S-high
  (1) W K A; O-med (2) K A W; S-high (2) A W K. O-med is `claude-opus-5-5` at `medium`; S-high is
  `claude-sonnet-5-5` at `high`. Opaque labels `f1`–`f12`.
- **The instruments**, on `claude-fable-5-1` at `max`: the scorer (R16's 44 items, V4 and O1
  reworded, O2' read from `o2p_check.py`'s flags); the refuter (R16's seven steps and three more:
  zeros, the house rules' figures, terms that reach nothing); one judge a block, ranking three
  overviews.
- **The calibration**, before any tier run was scored, came back on every known answer:
  - V4 on R16's s3 obeyed under the `frus1977-80v09Ed2` exemption;
  - v2's "11 of 695" classed as its own finding;
  - r8's unchecked null (C-3, in place of r3, whose zero was never reported) classed NOTHING;
  - R16's named O2' misses on s1 (7 of 8; the eighth called a pronoun) and on s3 all came back.

  It also showed the scorer stricter than R16's on borderline evidence: s3's E1, P6 and O2 came back
  violated where R16 had them obeyed. Two lines of the scorer's O2' text were corrected before any
  tier run was scored (§5 item 4).
- **The canary** passed in 40 seconds: three digests equal, 553 of 553 volumes decoded, the nine
  nearest neighbours of `frus1861/d111` exact and the tenth in the known three-way tie.
- **The cost:** the weekly all-models meter went from 30% to 55% (25 points) and the weekly Fable
  meter from 44% to 87% (43), inside the owner's lines of 62 and 98. About 4 h 30 m elapsed, an hour
  of it a pause (§5 item 6).

## 2. The tables

"The 35" is obeyed of applicable over C-3's 35 items. Numbers are the refuter's five headline
numbers.

| # | run | label | arm | the 35 | lost of the 35 | V lost | O2' | numbers | quotes | docs | strict | V7 | run min |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | O-med A (1) | f12 | A | 34/34 | — | — | violated | 5/5 | 75/75 | 26 | 1 | obeyed | 12.6 |
| 2 | O-med W (1) | f8 | W | 34/34 | — | — | violated | 4/5 | 67/67 | 22 | 0 | n/a | 13.4 |
| 3 | O-med K (1) | f3 | K | 34/34 | — | V5, V8 | violated | 5/5 | 66/66 | 23 | 0 | n/a | 12.5 |
| 4 | S-high W (1) | f6 | W | 33/34 | S3 | V5 | violated | 5/5 | 66/66 | 27 | 3 | obeyed | 20.4 |
| 5 | S-high K (1) | f11 | K | 33/34 | O2 | V8 | violated | 5/5 | 59/59 | 25 | 1 | obeyed | 16.3 |
| 6 | S-high A (1) | f10 | A | 31/34 | S3, P6, O2 | V8 | violated | 5/5 | 82/82 | 30 | 0 | violated | 18.9 |
| 7 | O-med K (2) | f9 | K | 33/34 | O2 | V2, V6 | violated | 5/5 | 73/73 | 25 | 0 | violated | 14.0 |
| 8 | O-med A (2) | f1 | A | 34/34 | — | — | violated | 5/5 | 59/59 | 22 | 0 | n/a | 12.5 |
| 9 | O-med W (2) | f2 | W | 31/34 | S3, P2, P6 | V2 | violated | 5/5 | 53/53 | 15 | 1 | obeyed | 10.5 |
| 10 | S-high A (2) | f7 | A | 33/34 | P6 | V8 | violated | 5/5 | 83/83 | 33 | 0 | violated | 17.0 |
| 11 | S-high W (2) | f4 | W | 32/34 | R3, P6 | V2 | violated | 5/5 | 44/44 | 22 | 0 | violated | 15.6 |
| 12 | S-high K (2) | f5 | K | 32/34 | S5, O2 | — | violated | 5/5 | 69/69 | 31 | 0 | violated | 18.8 |

No fabrication and no mis-citation in twelve runs: 796 of 796 quotations verified, 59 of 60 headline
numbers reproduced, every collection opens.

| arm | pooled median sentence | over 40 words | part 1 words | Documents cited, resolving every citation | part 2 as two lists | I per 1,000 words |
|---|---|---|---|---|---|---|
| A | 23 | 20.5% | 223, 275, 287, 344 | 0 of 4 | 0 of 4 | 5.3 to 7.3 |
| W | 19 | 8% | 152, 159, 158, 165 | 4 of 4 | 4 of 4 | 7.5 to 10.1 |
| K | — | — | 165 to 317 | 0 of 4 | 0 of 4 | 3.8 to 6.3 |

**The judges** (each ranks one block's three overviews; all five reader items in brackets):

| block | cell | first | second | third |
|---|---|---|---|---|
| 1 | O-med (1) | W (5) | K (4) | A (4) |
| 2 | S-high (1) | A (5) | W (5) | K (4) |
| 3 | O-med (2) | K (5) | A (5) | W (5) |
| 4 | S-high (2) | A (5) | W (4) | K (4) |

## 3. The readings, pre-registered (design §8)

**W against A.**
1. **The reader. Fails.** W above A in 1 block of 4 (block 1); J1–J5 summed 19 and 19.
2. **The form. Holds.** One citation form, a Documents cited list resolving every short citation,
   and part 2 as two lists, in 4 of 4 W runs.
3. **The length. Holds.** Pooled median 19 words, 8% over 40; part 1 within 200 words in 4 of 4.
4. **The numbers. Fails.** O2' held in none of the four W runs (nor in any A or K run); O2 held in 4
   of 4 W runs, against 3 of 4 in A. The last clause, W's untraced numerals summed against A's, is
   left unsettled: the scorers report their counts in prose, not uniformly enough to sum by script.
5. **The cost. Fails.** W lost 6 of the 35 against A's 4, more than A plus one, and two W runs lost
   two or more (run 9 three, run 11 two).
6. **The vocabulary. Holds.** V8 in 4 of 4 W runs.
7. **The price**, reported: W's sessions averaged 15.0 minutes, A's 15.2.
8. **The voice**, reported: "I" per 1,000 words 7.5 to 10.1 in W, 5.3 to 7.3 in A.

**K against A.**
9. **R8, the stems. Decides nothing.** One K run wrote prefixes (4 of 7 looked up first); T1 held in
   all 12 runs.
10. **R10, the zeros. Fails.** K put the relaxed query beside 1, 2, 1 and 1 of its zeros (11, 22, 17
    and 11 reported); A beside 0, 0, 0 and 1. R3 held in every A and K run; it failed once, in W's
    run 11.
11. **R7, the guide's figures. Fails.** A house-rules figure stated as the session's own in 3 of 4 K
    runs (A: 3 of 4). P6 held in 4 of 4 K runs.
12. **The cost. Fails** on the per-run clause: run 12 lost two (S5, O2). K's total, 4 against A's 4,
    is inside it.
13. **The price**, reported: K 15.4 minutes against A's 15.2.

## 4. Adoption, by the rule

The design's rule (§8): W goes in if readings 1, 2, 5 and 6 hold; each of R7, R8 and R10 if reading
12 and its own reading hold. Readings 1 and 5 fail, and so does 12. **Nothing from W or K is
adopted.** The guide stays at v1.38, and the two candidate branches stay local and unmerged.

**The owner followed the rule, 2026-10-31** ("Follow the rule"). Nothing from W or K is adopted. The
guide's §3a and its version history (v1.39) record the measurement.

**R1 and R2 adopted, 2026-10-31.** After the rewrite test of R1 and R2 alone
(`C-3-Reader-Facing-Rewrite-Test-2026-10-31.md`), the owner adopted them ("Include in 1819, along
with adopting R1 and R2"): guide v1.40. R6's vocabulary bullet and K's three rules stay unadopted.

Things that bear on that decision, none of which changes the rule's verdict:
- **The guard's per-run clause fails the control too.** A's run 6 lost three items. With this tier's
  scorer, stricter than R16's on borderline evidence (as calibrated), an arm lost about one item a
  run, so "no run loses two" is likely to fail an arm as good as A. On the arm totals alone, K (4
  against 4) passes and W (6 against 4) fails.
- **W's writing effects are real and stable.** Every form and length reading held in both cells.
  What failed is the reader ranking, where each block's judge compared three different research
  sessions and weighed evidence first, and the cost, which the losses (S3, P2, P6, R3) put on
  research procedure, not on writing.
- **R2's short citations cost the reader a lookup.** One judge preferred full citations in the
  sentence.
- **O2' has failed in every run of every arm across two tiers (21 of 21).** Most misses in this tier
  were archival identifiers with no group row and structural number-words.
- **R10 was read as applying to the headline zero.** Every K run did it there and almost nowhere
  else.

## 5. Limitations, as recorded before the result and as found

1. **n = 2 per arm per cell.** Each reading rests on four runs, and each judge on one run per arm.
2. **W and K were each measured against A**; their combination was not run.
3. **The judge's blinding was partial**: W's Documents cited list shows its arm.
4. **Two instrument changes during the tier**, both recorded in `usage.md` and the progress notes:
   - after calibration and before any tier run was scored, the scorer's O2' text gained the design's
     rule that a row covering the archival identifiers as a group traces them, and limited NOT A
     NUMBER to a pronoun "one";
   - after run 4 and before any reading, `style_measure.py`'s resolver accepted a year inside a
     multi-year volume's span ("1953, Volume XII, Part 2" for `frus1952-54v12p2`); W runs 2 and 4
     then resolved fully.
5. **The scorer is stricter than R16's** on borderline evidence (calibration), so item counts do not
   compare with R16's; A against W and K does.
6. **Pipelined and paused.** Each run's instruments ran while the next run worked. At 02:49 the
   5-hour usage window stood at 76% with 71 minutes to its reset, so runs 11 and 12 waited for the
   reset (04:03).
7. **The occasions were few for R8**: one K run, no A run.
8. **One question**, new to the series.

## 6. The expectations, against the result

`c3-reader-facing-tier/expectations.md` was written before the first cell.

| expectation | result |
|---|---|
| W's writing effects hold (sentences, part 1, Documents cited, two lists) | Held, 4 of 4 |
| The judge ranks W above A in at least three blocks | Contradicted: one block |
| O2' in two or three of W's runs | Contradicted: none, in any arm |
| V8 obeyed in 4 of 4 W runs, violated in most A and K runs | W held; A and K violated it in 2 of 4 each |
| An A run writes a dead term and does not notice | Contradicted: no A run wrote a prefix; T1 held in all 12 |
| K prints the relaxed form beside "soft power" in 4 of 4 | Held, and almost nowhere else |
| A restates "11 of 695"; K re-derives or attributes | Mixed: of the two A runs that printed it, one attributed it and one gave it as its own; one K run re-derived its figure |
| Neither treatment loses more than one item beyond A | Contradicted for W (6 against 4); K equal on the totals |

## 7. What follows

- **The guide's text stays v1.38's.** The owner followed the rule, and v1.39 records the measurement
  in §3a and the version history.
- **The owner's choices:**
  - whether W's writing measurements, which held in every run, warrant a smaller test of R1 and R2
    alone, judged on the same research (the pilot's design) rather than across sessions. *Run the
    same day on the owner's word (`C-3-Reader-Facing-Rewrite-Test-2026-10-31.md`): all six readings
    hold, and the blind judge preferred R1 and R2 in 7 of 8 pairs;*
  - whether the guard's per-run clause stays, given that the control breached it.
- **The soft-power question is now used.** It joins the ten used before, by the rule that a test
  question appears in no planning document before its run. Three of the owner's candidates remain
  unused.

## 8. Record

`c3-reader-facing-tier/`:
- the generator, the two candidate makers and the scripts;
- the prompts, the rubric, `keymap.json` and `pins.json`;
- `usage.md`, with the meters before and after every step;
- `results.md`, the tables and readings as `results_f.py` prints them;
- `runs/<label>/` for each run, with its `checks/` (the scripts' outputs), `verdicts.json` and
  `tally.md`; `runs/canary/`, and the calibration's verdicts and checks in `runs/cal-*`;
- `judges/`, each block's judgement;
- `PRUNED.txt`, the six files over a megabyte or pickled that were left out.
