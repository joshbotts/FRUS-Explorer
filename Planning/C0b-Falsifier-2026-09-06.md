# C-0b: the revised house-rules block, re-measured (#1208)

Run 2026-09-06. Design frozen before launch; rubric frozen before launch; scorers blind to arm.

## 1. What was measured, and what had moved since C-0

C-0 and C-2 scored the §12 block **as it stood at guide v1.10 — 110 lines**. v1.11 added 24 (134),
and this session's #1204 and #1203 added 9 more while #1208 sat open. **The block measured here is
143 lines**, not the 134 the issue names, and the guide's own caveat said "134 now". None of the 33
added lines had been measured.

Design, unchanged from C-0 so the two compare directly: two questions × (block pasted | no rules) ×
2 runs, one blind scorer per memo, hard-marking instructions identical.

Three things #1208 required that C-0 did not have:

- **Two FRESH questions.** C-0's two are printed in the planning documents and are contaminated.
  Used here: *international civil aviation — landing rights, air routes, the competitive position
  of American carriers*, and *United States policy toward refugees and displaced persons*. Neither
  appears in any planning document, and neither was touched by the session that revised the block.
- **A per-agent `queries.log`.** Two of the new rules are checkable only from the log; C-0 kept
  memos only. **Required identically in BOTH arms**, so the new instruction cannot itself be the
  treatment. Logs run 61–182 lines.
- **The cost, recorded.** §4.

**A harness defect was found and fixed before launch.** Every C-0 runner and scorer prompt told the
agent to open the database with `sqlite3 "file:…?mode=ro" -uri`, and this sqlite3 build **rejects
`-uri`** — *"unknown option"*. Both C-0 arms carried it equally, so C-0's comparison stands, but
every one of its eight runs spent its first query on a broken command. C-0b tells agents
`sqlite3 "file:…?mode=ro"` or `sqlite3 -readonly <path>`, both verified against the 3.4 GB copy.

## 2. The result

**BLOCK 116 of 116 = 100%. CONTROL 90 of 116 = 77.6%.** (4 items scored `not_applicable` in each
arm and are excluded from both denominators.)

C-0, adjudicated, was BLOCK 99% / CONTROL 84%. The block arm did not decay with 33 added lines; it
went from one violation to none.

Where the arms differ — 19 of the 30 items are at 4/4 in **both**:

| Item | BLOCK | CONTROL |
|---|---|---|
| **S5** | 4/4 | 0/4 |
| **A2** | 4/4 | 0/4 |
| **A6** | 4/4 | 0/4 |
| **E1** | 4/4 | 1/4 |
| **P3** | 4/4 | 1/4 |
| **R1** | 4/4 | 2/4 |
| **P4** | 4/4 | 2/4 |
| **I1** | 4/4 | 3/4 |
| **T1** | 4/4 | 3/4 |
| **S2** | 4/4 | 3/4 |
| **S4** | 4/4 | 3/4 |
| *the other 19 items* | 4/4 | 4/4 |

**All four P-items — the ones added to score v1.11's REPORTING and SCOPING lines — are 4/4 under
the block.** P3 (quotations attributed to retrieved rows) and P4 (the reading count) discriminate:
1/4 and 2/4 in the control. P1 (literal share) and P2 (change-claims backed both sides) are 4/4 in
both, so those two lines earned nothing measurable here — they are not harmful, but nothing in this
run argues they are load-bearing.

**The post-hoc measurement that matters more than any rubric row**, computed exactly as C-0
computed it — distinct NARA catalogue identifiers named per memo:

| | NAIDs resolved |
|---|---|
| BLOCK | b6 **10**, b4 **5**, b8 **5**, b2 **1** — every run, 21 distinct |
| CONTROL | b1 **0**, b3 **0**, b5 **0**, b7 **0** — **not one, in any run** |

C-0 measured 4/4 and 14 distinct against 0/4. Reproduced on two fresh questions, with a block a
third longer.

## 3. The pre-registered reading, applied

#1208 registered three readings before launch:

- *compliance holds at C-0's level (≥ 95%, A6 at 8/8)* → **met.** 100% ≥ 95%; A6 is 4/4 in the four
  block runs and 0/4 in the four control runs.
- *a drop on any item the new lines introduced* → **none.** Every P-item is 4/4.
- *a drop on a v1.10 item, meaning the added length is costing attention* → **none.** No v1.10 item
  lost a single run under the block.

**So the revised block is declared the instrument**, and the guide's version history says so
instead of deferring it. The one honest qualification: this measures 143 lines against 110 at
*C-0 length* — 30–60 tool calls in fresh context. It does not re-measure survival across a doubled
session; that was C-2's question, and C-2 was run on the 110-line block. A C-2b is not owed by
#1208's own terms, but the length claim now rests on a longer block than the session that tested it.

## 4. Cost

16 agents (8 scoping passes, 8 blind scorers), **3,174,913 subagent tokens**, 701 tool calls,
**35.2 minutes** wall clock. No agent errored, none returned empty. For comparison this is the first
figure any run in this series has recorded — C-0's and C-2's files carry none.

## 5. Reproducing this

- Harness: `Planning/c0b-falsifier/workflow.mjs` (generated; the block is interpolated, not
  hand-transcribed).
- Block under test: `Planning/c0b-falsifier/house-rules-block-v1.17.txt` (143 lines).
- Rubric: `Planning/c0b-falsifier/RUBRIC.md` — C-2's 26 items verbatim plus P1–P4.
- Memos and query logs: `Planning/c0b-falsifier/memos/`.
- Verdicts: `Planning/c0b-falsifier/verdicts.json`. Arm key: `keymap.json`, written after scoring.
