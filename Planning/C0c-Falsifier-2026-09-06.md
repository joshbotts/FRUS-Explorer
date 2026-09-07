# C-0c: the v1.20 house-rules block, re-measured at 181 lines

Run 2026-09-06. Design frozen before launch; rubric frozen before launch; **three readings
pre-registered before launch**; scorers blind to arm.

## 1. What was measured, and why

v1.20 rewrote two §12 rules that had failed in **all eight threads** of a two-round field run, and
the block grew from the **143 lines C-0b measured** to **181** — 27% more text. C-0b's
BLOCK 100% / CONTROL 77.6% does not cover that, and the guide says so in two places. This run
settles it, on C-0b's design so the three experiments compare directly.

**Two fresh questions**, because C-0b's own two are now printed in the planning documents exactly as
C-0's were — *isthmian canal rights* (the FRUS-rich, variant-heavy arm) and *international sanitary
conventions and quarantine practice* (thinner, and carrying a deliberate false friend: `quarantine`
in this corpus is overwhelmingly the 1962 Cuban naval quarantine, not public health). Neither
appears in any planning document; `isthmian` appears nowhere in `Docs/` or `Planning/` at all.

**A defect in C-0b's own rubric is fixed rather than inherited.** That file was C-2's rubric with
P1–P4 appended: it was still titled for the long-session run and still named *that* run's questions
while scoring C-0b's memos. C-0c's rubric describes C-0c.

## 2. The result

**BLOCK 120 of 126 = 95.2%. CONTROL 98 of 126 = 77.8%.** (Two items scored `not_applicable` in each
arm and are excluded from both denominators.)

| | C-0b (143 lines) | C-0c (181 lines) |
|---|---|---|
| BLOCK | 116/116 = **100%** | 120/126 = **95.2%** |
| CONTROL | 90/116 = **77.6%** | 98/126 = **77.8%** |

**The control replicates to within 0.2 points on two entirely different questions**, which is the
strongest evidence in this series that the instrument is stable and the arms mean what they claim.

Where the arms differ — 18 of 32 items are at 4/4 in **both**:

| item | BLOCK | CONTROL | |
|---|---|---|---|
| **S5** | 4/4 | **0/4** | the sharpest single discriminator |
| **E1** | 4/4 | 1/4 | apparatus exclusion |
| **A6** | 4/4 | 1/4 | the archival item C-0b also found decisive |
| A2 | 4/4 | 2/4 | |
| E3 | 4/4 | 2/4 | broken cross-references |
| P3 | 4/4 | 2/4 | quotations attributed |
| R1 | 4/4 | 2/4 | |
| C2, A3, P4, S1, S4 | 4/4 | 3/4 | |
| **P5** | **2/4** | **3/4** | **the control scored HIGHER** |
| **P6** | **0/4** | **0/4** | **no difference at all** |

## 3. The pre-registered readings, applied

- **1 — compliance holds at C-0b's level (≥ 95%, A6 at 4/4 under the block) → MET.** 95.2% ≥ 95%,
  and A6 is 4/4 under the block against 1/4 in the control.
- **2 — no item carried from C-0b loses a run under the block → MET, with nothing to qualify.**
  Every one of the block arm's six violations is on **P5 or P6, the two new items**. Not one of the
  26 items carried from C-0b, nor P1–P4, lost a single run. **The added 38 lines are not costing
  attention** — which was the entire risk of a longer prompt, and it did not materialise.
- **3 — P5 and P6, the two rewritten rules, score at the block arm's general level → FAILED.**
  P6 is **0 of 4**. P5 is **2 of 4**, and *worse than the control's 3 of 4*.

**So the caveat is discharged for length and NOT discharged for the rewrite**, and the guide says so
rather than quoting the 95.2% as a clean pass.

## 4. Why P6 failed, which the evidence makes unusually clear

All four block cells did the same thing: they headed `queries.log` with the strongest possible
completeness claim and then elided command bodies. b2: *"every command that touched a surface, one
per line, verbatim … Nothing is elided"* — with bodies elided at eight separate lines. b4: *"Nothing
in this log is elided"* — 37 lines carry `…`, about twenty of them eliding a command body outright.
b8: *"Nothing elided"* above at least eight placeholder bodies.

**Part of this is the harness's fault, not the guidance's, and the distinction matters.** The
runner's own DELIVERABLE line — identical in both arms — asks for *"EVERY command you ran that
touched a surface, one per line, verbatim, in order."* The agents restated that instruction as a
header and then met reality: a `python3 -u -c "…"` body a hundred characters wide does not fit "one
per line," so it was elided. The rule then correctly detected a false completeness claim that the
harness had invited.

**But the finding stands.** Agents elide, and they claim they do not. The rewrite made the rule
*satisfiable* (it now admits the script route) without making it *satisfied*, because it still asks
for a blanket claim. **The next revision should require the log to declare what it elided rather
than to assert that it elided nothing** — and the harness should stop asking for "EVERY command,
verbatim" in the same breath. Neither change is made here: C-0c measured the v1.20 text and this
record is that measurement, not a new instrument.

**P5's inversion is reported and not explained.** The control scored 3/4 where the block scored 2/4.
With n=4 per arm this is one run's difference and may be noise; it is recorded rather than
interpreted, and it is the one place in three runs where the control has beaten the block on an item.

## 5. The archival discriminator did NOT reproduce cleanly

C-0b measured distinct NARA identifiers per memo at **BLOCK 4/4 (21 distinct) against CONTROL 0/4**.
Here:

| | NAIDs named |
|---|---|
| BLOCK | b2 **11**, b4 **13**, b6 **19**, b8 **17** — every run |
| CONTROL | b1 **0**, b3 **21**, b5 **19**, b7 **0** — **two of four** |

The block arm is again 4/4. But two control runs resolved archival identifiers unprompted, and one
of them named more than any block run. **On this pair of questions the archival gap is a difference
of reliability, not of possibility**, and C-0b's clean 4/4-versus-0/4 should not be quoted as a
general property of the block.

## 6. Cost

16 agents (8 scoping passes, 8 blind scorers), **3,094,207 subagent tokens**, 726 tool calls,
**45.5 minutes** wall clock. No agent errored, none returned empty. C-0b was 16 agents / 3.17 M /
35.2 min, so a 27% longer block cost about 10 minutes and slightly fewer tokens.

## 7. Reproducing this

- Harness: generated, with the block interpolated rather than transcribed (runbook §8). **The arms
  were verified before launch by parsing the generated script back**: 4 cells carry the block and 4
  do not, same-question prompts are byte-identical apart from it, no prompt printed the broken
  `-uri` invocation, and `queries.log` is required in **both** arms so the logging instruction cannot
  itself be the treatment.
- Block under test: `Planning/c0c-falsifier/house-rules-block-v1.20.txt` (181 lines, sha256
  `d605353072f8aeb7a0bc5da1f5b35823fb3cc447cafd39c80ea69ad3a92d9ee7`).
- Rubric: `Planning/c0c-falsifier/RUBRIC.md` — C-0b's 30 items verbatim plus P5 and P6.
- Memos and query logs: `Planning/c0c-falsifier/memos/`. Verdicts:
  `Planning/c0c-falsifier/verdicts.json`. Arm key: `keymap.json`, frozen before launch.
