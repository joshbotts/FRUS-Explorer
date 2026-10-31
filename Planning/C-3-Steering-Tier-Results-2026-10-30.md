# C-3 steering tier (R16) — results: the revised block and the vectors card against the guide as it stands, on the owner's corruption question

**Status:** RUN 2026-10-30, 09:50 to 15:32 (local), on the owner's Mac. It followed the design the
owner set that morning, `C-3-Steering-Tier-Design.md`, with its as-built notes at its head. The
record is `c3-steering-tier/`. Nothing here is a figure the record does not hold.

**The answer.** By the rule written before the run, arm B is not adopted as a whole. Reading 4
fails by one item: B's four runs lost two of the 35 carried items and A's lost one. Readings 1, 2,
5, 6 and 7 hold. Reading 3 holds on reach, and its V7 part does not: one B run claimed a strict
document the refuter did not confirm.

The parts read separately:

- **R6's vocabulary bullet works.** No vector word reached the historian's text in any of B's four
  runs, and it reached the text in all four of A's (V8: 4 of 4 against 0 of 4).
- **R8 works.** B looked stems up before writing prefixes in all four runs. One A run fell into
  the exact trap R8 names: `misappropriat` returned 0 where `misappropriation` returns 93, and the
  run did not notice. That run lost T1.
- **V6 needed no new text.** A obeyed it in 4 of 4, with v1.36's line on cosines pasted into the
  block as §3a says. The vectors tier had scored 0 of 4.
- **The required operations ran in 4 of 4 B runs.** No B run ran centroid similarity, which B
  dropped; A ran it in three of four.
- **Reach came out even.** Each arm found two strict vector-reached documents, one in each cell,
  and each arm quoted one of its two. B's operations did not find more, as the expectations said
  they would.
- **B's lost items are both O2:** numbers in the overview with no memo line, in both Sonnet runs.
  B0, the same block with no artifacts, lost it too. B's text does not touch that rule; the
  reader-facing pass is about it. Every one of the nine runs failed O2', the stricter numerals
  check, so the weakness is in every arm.
- **One gap is in the card itself.** It carries no worked list of neighbours to check a decode
  against, and two of B's four runs lost V2 for want of a spot check on a known document.
- **Run 9 holds.** It wrote "VECTORS: none", opened no vector file, and scored 0.971 on the 35
  items. The judge ranked its overview first of all nine.

---

## 1. What was run

- **The question** (the owner's, chosen 2026-10-30 from five candidates the session assessed):
  *How has corruption, or allegations of corruption, affected U.S. foreign policy decisions or the
  conduct of diplomacy?*
- **Arm A**, the guide as it stands (v1.37, `4fbf75f1`): a 749-line prompt.
  - The §12 block, 205 lines with SHA-256 `c2f5511d…`, the block C-3 measured.
  - §A.8's addendum pasted at its end, as §3a says.
  - Appendix A whole, 346 lines.
  - The vectors tier's resources and its five-operation VECTORS sentence.
- **Arm B**, the v1.38 candidate (`84bf7e50`, branch `claude/c3-steering-arm-b`): a 584-line
  prompt.
  - The block at 247 lines, with the SEMANTIC VECTORS section, R5's Ed2 clause, R7, R8 and R10.
  - §A.9's card, 149 lines.
  - The guide copy as a file.
  - The three-operation VECTORS sentence.
- **Run 9:** arm B with no artifacts, a 411-line prompt.
- **The runs**, one at a time:
  - O-med A (1), O-med B (1), S-high A (1), S-high B (1);
  - O-med A (2), O-med B (2), S-high A (2), S-high B (2);
  - O-med B with no artifacts.

  O-med is `claude-opus-5-5` at `medium`, and S-high is `claude-sonnet-5-5` at `high`.
- **The instruments**, on `claude-fable-5-1` at `max` and blind to the arm (opaque labels
  `s1`–`s9`):
  - the scorer, on 44 items: the vectors tier's 41 plus V8, O4 and O2';
  - the refuter, with the reach step in both readings and V7;
  - the reader judge, which ranked every overview judged so far at each step.
- **The calibration**, on the vectors tier's v3, which answered the Cuba question. Its new items'
  known answers all came back right:
  - V7 and V8 violated;
  - O4 obeyed;
  - the strict reading `{frus1958-60v05/d112}`.

  Three of the 41 carried items came back stricter than the vectors tier scored the same files
  (V2, P6 and O2). In each, the earlier scorer had written the same fault as a caveat and still
  scored the item obeyed. The scorer is the same instrument for both arms, so A against B holds;
  item counts against the earlier tiers do not (§5).
- **The canary**, on B's card, passed in 45 seconds:
  - six digests equal;
  - 553 of 553 volumes decoded;
  - the nine nearest neighbours of `frus1861/d111` exactly, and the tenth one of the three tied
    at 79;
  - both baselines (167.1, 14.8, 132; the 25th-neighbour median 107);
  - the 1881/1894 reprint at 4.
- **The cost:**
  - **Meters:** the weekly all-models meter went from 5% to 24% (19 points), and the weekly Fable
    meter from 2% to 36% (34). Both stayed inside the owner's lines of 30 and 42.
  - **Time:** 5 h 42 m elapsed.
  - **Tokens:** 8.10 M output tokens across the nine runs, their instruments and the calibration.
  - **Plan:** the usage card named the plan Ultra from run 6 on, where it had said Max.
- **The environment:**
  - C-3's index copy (version 71, 553 volumes) and the 553 shards beside it;
  - build 1.0 (1776)'s bundle;
  - numpy 2.0.2, which imports from the user's site packages and was not installed for the
    vectors tier.

## 2. The table

Per run. "The 35" is obeyed of applicable over C-3's 35 items; E3 is `not_applicable` in every
run. Numbers is the overview's first five quantitative claims re-derived by the refuter.
Strict and practical are §14.17's two readings of vector-reached; strict counts are followed by
how many the overview quotes. Judge is the reader judge's five items. Run min is the session
alone, without its instruments.

| # | run | label | arm | the 35 | lost of the 35 | V1–V6, V8 lost | O4 | O2' | numbers | quotes | ids | docs | strict (quoted) | practical | V7 | judge | run min |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | O-med A (1) | s7 | A | 34/34 | — | V8 | obeyed | violated | 5/5 | 29/29 | 26/27 | 11 | 1 (1) | 1 | obeyed | 5/5 | 12.1 |
| 2 | O-med B (1) | s2 | B | 34/34 | — | V2 | obeyed | violated | 5/5 | 39/39 | 22/22 | 19 | 1 (1) | 1 | obeyed | 5/5 | 14.2 |
| 3 | S-high A (1) | s6 | A | 33/34 | T1 | V4, V5, V8 | obeyed | violated | 5/5 | 38/38 | 28/29 | 30 | 0 (0) | 2 | violated | 5/5 | 21.6 |
| 4 | S-high B (1) | s1 | B | 33/34 | O2 | V2, V5 | obeyed | violated | 5/5 | 35/35 | 14/14 | 29 | 0 (0) | 1 | n/a | 5/5 | 22.4 |
| 5 | O-med A (2) | s8 | A | 34/34 | — | V8 | obeyed | violated | 5/5 | 55/55 | 18/18 | 28 | 0 (0) | 0 | n/a | 4/5 | 15.4 |
| 6 | O-med B (2) | s3 | B | 34/34 | — | V4 | obeyed | violated | 5/5 | 27/27 | 22/23 | 12 | 0 (0) | 1 | violated | 5/5 | 13.1 |
| 7 | S-high A (2) | s5 | A | 34/34 | — | V8 | obeyed | violated | 5/5 | 44/44 | 17/19 | 38 | 1 (0) | 1 | obeyed | 5/5 | 28.3 |
| 8 | S-high B (2) | s4 | B | 33/34 | O2 | — | obeyed | violated | 5/5 | 81/81 | 23/24 | 35 | 1 (1) | 1 | obeyed | 5/5 | 27.5 |
| 9 | O-med B, no artifacts | s9 | B0 | 33/34 | O2 | n/a | obeyed | violated | 5/5 | 41/41 | 20/21 | 21 | — | — | n/a | 5/5 | 14.7 |

No fabrication and no mis-citation in nine runs: 389 of 389 quotations verified, 45 of 45 headline
numbers reproduced, every collection opens. The four strict vector-reached documents:

| run | document |
|---|---|
| s7 (A) and s2 (B) | `frus1961-63v22/d204`: Rostow to President Kennedy, 15 March 1961 |
| s5 (A) | `frus1922v01/d836`: Crowder to the Secretary of State from Havana, 5 April 1922 |
| s4 (B) | `frus1922v01/d872`: the Acting Secretary to the Cuban chargé, 4 November 1922 |

**The judge's last ranking, over all nine:** s9, s6, s4, s2, s5, s1, s7, s8, s3. That puts B0
first, and A and B each at a mean place of 5.5.

## 3. The seven readings, pre-registered (design §6)

1. **Use. Holds.** B ran the flagged neighbour join and the near-duplicate check in 4 of 4, and
   named in its memo the operations it did not run. One B run also ran the map (s1).
   A ran the neighbours and the join in 4 of 4; centroid similarity and the map in 3 of 4 (s6,
   s8, s5); and a Tier-2 rerank once (s8).
2. **V6. Holds.** B obeyed in 3 runs and was `not_applicable` in one: no cosine reached its
   reader. A obeyed in 4 of 4, where the vectors tier scored 0 of 4: v1.36's line, pasted into
   the block, did it.
3. **Reach. Holds on reach; V7 does not.**
   - **Reach:** B's strict count is 2, and A's is 2, in the same cells (O-med (1) and S-high (2)).
   - **V7 in B:** obeyed in s2 and s4, `not_applicable` in s1, and violated in s3. s3's claimed
     document was returned by three full-text queries the session logged after the neighbour list
     surfaced it: practical, not strict.
   - **V7 in A:** violated once (s6, whose two claims both failed the re-run).
4. **The cost. Fails by one item.** B lost O2 twice (s1, s4), and A lost T1 once (s6). No single
   run lost two, so the design's per-run note does not arise.
5. **The reader. Holds.** V8 was obeyed in 4 of 4 of B and violated in 4 of 4 of A. The judge's
   last ranking puts B above A in two of the four cell-matched pairs: O-med (1) and S-high (2).
6. **The price. Holds.**
   - **Wall clock:** B's sessions averaged 19.3 minutes and A's 19.4.
   - **Prompt length:** B's prompt was 165 lines shorter. That is not the design's 210, because
     the card came to 149 lines.
7. **Run 9. Holds.** The memo's section reads "VECTORS: none"; no logged command and no script
   names a vector file. It scored 33 of 34 on the 35 (0.971, losing O2), above the 0.952 floor.

## 4. Adoption, by the rule

The design's rule:
- B goes into the guide as its text only if readings 1, 2, 4 and 7 hold;
- a B that fails reading 4 keeps the appendix and the addendum, and R7, R8 and R10 are measured
  again alone.

Reading 4 failed, so B is not adopted. The guide stays at v1.37's block, addendum and appendix,
and the branch `claude/c3-steering-arm-b` stays unmerged.

**The owner followed the rule, 2026-10-30** ("Follow the rule"). Nothing from B is adopted. The
guide's §3a and its version history (v1.38) record the measurement. The next measurement of R7, R8
and R10 alone is owed, and it may carry R6's vocabulary bullet and the card with a spot check.

Four things bear on what the owner does next, and none of them changes the rule's verdict:
- **The margin is one item, on a rule B does not touch.** O2 sits in READER-FACING OUTPUT, which
  both arms carried unchanged. The owner set its wording aside for a pass of its own.
- **Two of B's parts show effects that do not depend on that margin.** The vocabulary bullet
  scored V8 4 of 4 against 0 of 4, and R8 scored T1 4 of 4 against 3 of 4. Under the rule they are
  measured again, with R7 and R10, as a smaller treatment.
- **B0 lost O2 as well**, so three of the five runs under B's block lost it, against none of A's
  four. That is too few runs to separate the block's length from chance, but it is the pattern
  the rule guards against.
- **The card needs a spot check of a known document** before it is measured again. Two of B's
  four runs lost V2 for want of one.

## 5. Limitations, as recorded before the result and as found

1. **n = 2 per arm per cell**, and run 9 is n = 1. One item decided reading 4.
2. **One treatment.** The arms differ by the whole revision, so no single edit is attributable by
   design. §4's part-by-part reading is of items that only one part of B addresses.
3. **B could read the whole guide, and A could not.** None of B's four runs opened the guide copy.
4. **A's appendix points to §14.17**, which A's prompt did not carry.
5. **No free-text arm.**
6. **Run 9 has no same-question control** without the section.
7. **numpy now imports**, for both arms.
8. **The scorer was stricter than the vectors tier's** on three borderline items in the
   calibration. Item counts here do not compare with the earlier tiers'; A against B does, since
   one scorer scored both.
9. **O2' was violated in all nine runs.** It is the strictest reader item, and O2 may be read more
   strictly beside it: the calibration's O2 flip was on number-words.
10. **V4 conflicts with the block's own Ed2 line.** s3 lost V4 for an Ed2 volume with no first
    edition (`frus1977-80v09Ed2`) in a neighbour list. The block says never to fold that volume,
    and the card's code follows the block. The rubric's V4 should exempt it before it is used
    again.
11. **The strict reading counts queries logged after the neighbour list** (s3). The memo was
    right about the order, and the practical reading recorded the document. §14.17's definition
    is the one V7 scored.

## 6. The expectations, against the result

`c3-steering-tier/expectations.md` was written before the first cell.

| expectation | result |
|---|---|
| One to four strict documents in each B run, more in B than in A | Two of four B runs found none. B and A tied at two each, in the same cells |
| At most one cross-era document a run | Held: no run found more than one strict document |
| B cites one copy of each reprint and counts it once | Held: B ran the check in 4 of 4 |
| V8 violated in most A runs, obeyed in all four B runs | Held exactly: 4 of 4 and 4 of 4 |
| Run 9 writes "VECTORS: none" and opens no vector file | Held |

Two of the three conditions it named as contradictions were met: A at or above B on reach in both
cells, and B losing more of the 35 than A.

**Corrections to `expectations.md`.** The file is left as written before the first cell. Against
the choosing session's own counts, four of its statements are wrong or stronger than measured:
- *Peculation* is not gone by the 1930s. It occurs in the 1930s, and in 4 documents after 1946
  (39 in all, 23 of them before 1900).
- *Nepotism* appears from the 1930s, with 10 documents in 1900–45 and 2 before 1900. *Kickback*
  has one document before 1946.
- 37 of 2,866 is about one in 77, not one in 75.
- "The rest sit under country chapters" generalizes from the six largest chapters the assessment
  listed, which were mostly countries'. The other chapters were not classified.

## 7. What follows

- **The guide's text stays v1.37's.** By the rule, the next measurement of R7, R8 and R10 alone is
  owed. The owner decides whether it also carries R6's vocabulary bullet, and the card with a
  spot check.
- **The reader-facing pass** (design §8) now has 25 runs of raw outputs.
  - Its baseline: O2' failed in 9 of 9, O4 held in 9 of 9, O2 failed in 3 of 9.
  - The judge's five items held in 44 of 45: J3 missed once (s8).
- **§3a and the version history record the measurement and adopt nothing** (guide v1.38), on the
  owner's word of 2026-10-30.
- **The corruption question is now used.** With its text, the assessment's figures and nine full
  answers in the repository, a later tier may not use it, by the rule that a test question
  appears in no planning document before its run (`C-3-Reader-Test-Design.md` §1). It joins the
  nine listed in this tier's design (§1). The owner's other four candidates are named in no
  planning document, so any of them can still be used.

## 8. Record

`c3-steering-tier/`, described in its README:
- the generator and the scripts;
- the prompts and the rubric;
- `keymap.json` and `pins.json`;
- `usage.md`, with the meters before and after every step;
- `results.md`, the table and the readings as `results_s.py` prints them;
- `runs/<label>/` for each of the nine runs, with `runs/canary/` and `runs/cal/`.
