# C-3 vectors tier — results: Sonnet 5.5 at `high` and Opus 5.5 at `medium` with Appendix A and the vector artifacts, two runs each

**Status:** RUN 2026-10-26 23:07 (the shards copied; the first agent at 23:13) to 2026-10-27 01:59
(the last verdict), 2 h 46 m, on the owner's Mac, under the owner's
four decisions of 2026-10-26 (`C-3-Vectors-Tier-Design.md`, head): no embedder; now, under a line
at 92% of the weekly meter; the owner's own question, so no control arm; the shards copied beside
the index copy. The record is `c3-vectors-tier/`. Nothing here is a figure the record does not hold.

**The three questions, answered.**

1. **The agents used the vectors, and used them as the appendix says.** All four runs ran all
   five of §A.5's operations — nearest neighbours of a document, a semantic join into the
   database, centroid similarity, the map and near-duplicates — compared the provenance digests
   first, decoded identity from the index's segments, and calibrated distances against both
   baselines; one opened a Tier-2 shard. The rubric's new items V1 to V5 were obeyed 19 times in
   20. The one rule every run missed (V6) is the last paragraph of §A.7: a cosine the reader sees
   goes through the index's calibration offsets, or is labelled raw. Nobody did either.
2. **The historian got a little more, in two runs of four.** The refuter, told to re-run every
   full-text and heading query the session logged, found one cited and quoted document in each of
   S-high+V (1) and O-med+V (2) that no logged query returns and that the session reached through a
   neighbour list: a Dulles memorandum of March 1959 that never names Cuba, and Fish's instruction to
   Cushing of February 1874. In the other two runs every cited document was also reachable by
   full-text search; the sessions' own claims of vector-reached documents (two more) were documents
   inside their chapter-heading scope, which the refuters discounted.
3. **The appendix cost about one compliance item a run, and no time or usage.** On C-3's 35 items
   the four runs scored 0.941, 0.971, 0.971 and 1.000 (mean 0.971) where the same two cells were
   perfect four times in C-3 on a different question; one run, O-med+V (1), fell below the 0.952
   floor. Wall clock was unchanged for Opus (18.8 minutes a run in both tiers) and shorter for
   Sonnet (23 against 31); the weekly meter moved the same 1 to 2 points a run; the collections were
   smaller (16 to 23 documents against 19 to 56), which the question explains as well as the
   appendix could.

---

## 1. What was run

- **Question** (the owner's, verbatim): *how have u.s. policymakers' thinking about cuba's impact
  on national security and prosperity changed since the 1870s?* Weighed against a second
  candidate on legitimacy, which has no seed set and no scope for a document-to-document run.
- **Cells**: O-med+V and S-high+V, two runs each, in the order O-med, S-high, O-med, S-high. Each
  run's prompt is C-3's plus Appendix A whole (328 lines, from the guide at v1.35), the artifacts
  by path, and a VECTORS section in the memo. No embedder; no helper script.
- **Instruments**: C-3's scorer, refuter and judge on `claude-fable-5-1` at `max`, blind to the
  cell; the scorer on 41 items (C-3's 35 plus V1–V6), the refuter with two added steps (vector
  use; reach), the judge ranking this tier's overviews alone.
- **Before any cell**: Appendix A's worked figures re-taken at the shipped digest and the guide
  corrected (v1.35; §3 below); `vectors_check.py` reproduced the neighbour list, the decode and
  the digests from the files; the calibration (C-3's r5 scored with the 41 items: V1–V6 all
  `not_applicable`, the 35 unchanged); the canary (Opus at `medium` read the digests, decoded 553 of
  553 volumes and printed the ten neighbours exactly as the check holds them, in 44 seconds).
- **Budget**: 8 points of the weekly all-models meter (80% → 88%), 16 of the Fable window (62% →
  78%), for calibration, canary and four runs; inside the 92% line; nothing left unrun.
- **Environment**: C-3's index copy (version 71, 553 volumes), the app's TEI files, build
  1.0 (1776)'s bundle; the shards copied from the app's container (553, 156 MB); all four
  provenance digests `89481b18…`; sqlite3 3.54.0; Python 3.9.6.

## 2. The table

Compliance (35) is on C-3's items, the scale the two tiers share; all 40 adds V1–V6 (E3 was
`not_applicable` in every run). Quality is C-3's formula over the 35 items. Vector-reached = cited
documents no logged full-text or heading query returns, reached through a vector operation, as the
refuter counted them (quoted = of those, quoted in the overview). Run min is the cell's own agent
from its transcript's timestamps; cell min sums the four agents' minutes, and since the three
instruments ran in parallel a cell's elapsed time was 33 to 40 minutes (v2 39.8, v3 37.1, v4 32.8,
v1 40.1).

| run | compliance (35) | all 40 | V1–V6 | violated | numbers | quotes | identifiers | docs | reader | quality | vector-reached (quoted) | run min | cell min | run tool calls | weekly pts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S-high+V (2) | 1.000 | 0.975 | ✓✓✓✓✓✗ | V6 | 5/5 | 64/64 | 20/20 | 22 | 5/5 | 1.000 | 0 of 22 | 25.2 | 57.5 | 121 | 2 |
| S-high+V (1) | 0.971 | 0.950 | ✓✓✓✓✓✗ | P5, V6 | 5/5 | 64/64 | 20/20 | 23 | 5/5 | 0.971 | 1 (1) of 23 | 21.2 | 53.5 | 106 | 2 |
| O-med+V (1) | 0.941 | 0.925 | ✓✓✓✓✓✗ | T1, P6, V6 | 5/5 | 44/44 | 22/22 | 16 | 5/5 | 0.941 | 0 of 16 | 23.3 | 60.2 | 87 | 2 |
| O-med+V (2) | 0.971 | 0.925 | ✓✓✓✓✗✗ | P5, V5, V6 | 4/5 | 38/38 | 30/32 | 16 | 5/5 | 0.776 | 1 (1) of 16 | 14.2 | 50.3 | 55 | 1 |

No run fabricated; every quotation (210 of 210) was found in its document; one headline number
and two archival identifiers were not reproduced, all in O-med+V (2). The judge's final ranking:
S-high+V (2), S-high+V (1), O-med+V (2), O-med+V (1).

**C-3's same cells, on the recognition question, for reference and not as controls**: O-med 1.000
and 1.000 compliance, 18.2 and 19.4 minutes, 1 and 2 points, 19 and 26 documents; S-high 1.000 and
1.000, 30.5 and 32.4 minutes, 2 and 2 points, 56 and 56 documents; every reader item 5 of 5.

## 3. Appendix A at the shipped generation (found before the run)

`appendix_recheck.py` re-took §A.5's worked figures from the shipped files and found every one to
be the 300m generation's: the ten neighbours of `frus1861/d111` began at Hamming 87 in the
appendix and begin at 57 in the shipped binary (three of the ten in common); random pairs
averaged 193 in the appendix and 167 now (sd 15, 1st percentile 132, minimum 95); the 25th
neighbour's median 124 against 108; a random pattern's minimum 215 against 200 to 206; the
centroid cosines 0.976/0.967/0.957 against 0.989/0.986/0.984; the map example `frus1929v03/d17`
unclustered in the 2026-10-15 layout; 88,059 of 314,616 placements unclustered (28.0%), with the
era dependence the appendix stated reversed (24.8% of 1861–1899 documents against 26.9% of
1945–1964). The appendix's own rule, that a regeneration moves every list and the baselines are
recomputed after one, had not been applied to its examples when B4 moved the generation. The
guide was corrected at v1.35 before the prompts were generated, and one tooling fact added:
`int.bit_count()` in §A.5's loop needs Python 3.10, and the Mac's 3.9 has `bin(x).count("1")`.

## 4. The five readings (design §6, pre-registered)

- **Use**: 4 of 4 runs ran a vector operation; 4 of 4 ran all five; 4 of 4 compared the digests.
  Expected: four of four scan, fewer join, none map. Found: more than expected. The appendix is a
  working front door for both models at these efforts, without a helper script.
- **Reach**: 0, 1, 1, 0 vector-reached documents (each quoted). Expected one to five a run, mostly
  before 1913 or in Spanish, with a quotation in the Sonnet runs. Found: fewer, one each in a
  Sonnet run and an Opus run, one of them from 1874, neither in Spanish. The sessions claimed two
  more, which sat inside their own heading scope.
- **The appendix's cost**: compliance on the 35 items 0.941 and 0.971 for Opus against 1.000 twice,
  0.971 and 1.000 for Sonnet against 1.000 twice; one item lost in three runs of four, two in one.
  Expected: none lost for Opus, at most one for Sonnet. Found: the reverse ordering, and under the
  pre-registered threshold ("two or more lost in both cells") the appendix stays in the prompt.
- **The reader**: 5 of 5 in all four, as expected; the ranking puts both Sonnet runs above both
  Opus runs, which matches C-3's quality tie-break for the same two cells.
- **The price**: wall clock 23.3 and 14.2 minutes for Opus against 18.2 and 19.4; 21.2 and 25.2 for
  Sonnet against 30.5 and 32.4. Expected +30 to +50 percent; found none. A full Hamming scan in
  Python 3.9 is seconds, and the sessions spent the time they saved on reading fewer documents.

**The recommendation this changes** (design §6). The +V runs reached documents the full-text
scope did not, in two runs of four, and carried a quotation from each; compliance was not held in
three of four runs, by one item, and the reader ranking is not comparable across questions. So
the guide's §3a gains a short paragraph rather than a row: on a question whose vocabulary drifts,
hand the two recommended cells the artifacts and Appendix A; expect every operation to be run
correctly, about one cited document in twenty to be reachable no other way, one compliance item
lost to the longer prompt, and no cost in time or usage; and paste §A.8's SEMANTIC VECTORS
addendum into the §12 block, since the one rule all four runs missed is the one the addendum
does not state, the calibration offsets, which the next guide edit adds to it.

## 5. Limitations, as recorded before the result and as found

1. **n = 2 per cell.** Enough to say "used them" and "one item lost"; not enough to rank the two
   cells against each other on reach (one hit each).
2. **No control arm.** The owner chose a new question, so C-3's figures for these cells are a
   reference on a different question, labelled as such throughout. The compliance loss is the
   best-supported comparison, since the items are procedural; the document counts and the
   ranking are not comparable.
3. **The appendix and the prompt length are one treatment.** The item losses (T1, P5, P6, V5)
   cannot be attributed to the vector work rather than to 328 more lines; two of them, T1 and P5,
   are rules the block states and the vectors do not touch.
4. **No free-text queries**, by decision 1; the reach reading counts only what a document-to-document
   operation found.
5. **The reach count is the refuter's rule**: a cited document is vector-reached only when no
   logged full-text or heading query returns it. A session that finds a document by a neighbour
   list and then confirms it by a search it logs is counted as full-text-reached, which
   understates the vectors' part in the discovery; the sessions' own claims (two more documents)
   are the upper bound.
6. **Appendix A was corrected the same day it was handed to the agents.** The cells read v1.35;
   a run on v1.34 would have given them a neighbour list that no decode reproduces.

## 6. What a later run adds

The free-text arm (decision 1's alternative), with the pinned prompt and a parity check against
the app's encoder; a question in which the vectors should matter more than they did here (a
subject whose documents are filed under other countries' headings); and the V6 rule moved into
the block before it is measured again.
