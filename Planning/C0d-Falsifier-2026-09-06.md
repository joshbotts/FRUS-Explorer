# C-0d: does the revised log rule get obeyed?

Run 2026-09-06, hours after C-0c. **Single-arm, four cells, one question.** Design and rubric frozen
before launch; three readings pre-registered.

## 1. What this tests, and why it is not another A/B

C-0c measured v1.20's rewrite of the SQL/log rule at **0 of 4 under the block — and 0 of 4 in the
control too**. There is no control-arm difference left to detect on that item, so a second 8-cell
A/B would have spent sixteen agents re-measuring something already known. C-0d runs **the block arm
only**: 2 fresh questions × 2 runs, 4 blind scorers, all 32 items scored.

**The stated cost:** with one arm, blinding no longer does the work it did in C-0b and C-0c. This is
a before/after against C-0c's block arm on the same rubric, **not a controlled comparison**.

**The change under test.** v1.21 replaces the blanket don't-overclaim clause with a positive
obligation: *do not claim your log is complete — declare what you left out*, as an `ELIDED:` line,
and **a completeness header is a violation even when accurate, because it is unverifiable**.

**THE HARNESS PROMPT WAS DELIBERATELY LEFT UNCHANGED.** C-0c's runner asked for *"EVERY command you
ran that touched a surface, one per line, verbatim, in order"* — the sentence all four block agents
restated as their log header before eliding anyway. That line is byte-identical here, verified by
diffing the generated prompts: the runner is C-0c's with **only** the block, the question and the
scratch path swapped. If the rule can beat the same invitation, the rule is doing the work.

**Two fresh questions**, by the standard the series keeps — *international postal conventions* (99
documents on the exact phrase) and *maritime neutrality in wartime* (22), preserving C-0's rich/thin
pairing. Neither anchor phrase appears anywhere in `Docs/` or `Planning/`.

## 2. The result

**BLOCK 124 of 125 = 99.2%.** (Three items scored `not_applicable` and are excluded.)

| | block arm |
|---|---|
| C-0b, 143 lines | 116/116 = **100%** |
| C-0c, 181 lines | 120/126 = **95.2%** |
| **C-0d, 184 lines** | **124/125 = 99.2%** |

## 3. The pre-registered readings, applied

- **1 — P6 ≥ 3 of 4 → MET, decisively. 0 of 4 became 4 of 4.** All four agents wrote a real
  `ELIDED:` declaration naming what they had shortened: *"the following were shortened above, and
  each is named at the point it occurs"* (d1); *"In sections 18, 24 and 26 I wrote `<… full body
  elided …>` in place of six…"* (d2). **Asking for the exception rather than the guarantee moved a
  rule that two rewrites of the prohibition had not.**
- **2 — no item carried from C-0c loses a run → NOT MET.** A6 lost one run, in d2. See below; I do
  not explain it away.
- **3 — P5 ≥ 3 of 4 → MET. 2 of 4 became 4 of 4.** Its rule is unchanged, so C-0c's 2 was either
  noise at n=4 or a property of that question pair. The literal-share split does not have a problem
  of its own.

## 4. The reading that failed, without an excuse

A6 — the archival item — is **3 of 4**, violated in d2. The scorer's evidence: the memo names lot
and record-group numbers straight from source notes and resolves none to a NAID, declining outright:
*"Neither is in this app's offline stack, so I cannot resolve either to a series NAID from here."*

**The honest reading is that n=4 cannot separate the candidate explanations.** Two are available and
this run does not choose between them. (a) It is the question: d2 named **3** distinct NAIDs against
8, 9 and 10 in the other cells, and the postal question's archival units may simply not be in the
bundled stack — the agent said so and disclosed it, which is the block working, not failing. (b) It
is the three added lines. **The registered reading says a carried item must not lose a run, and one
did.** That is recorded as not met.

What can be said without hedging: the violation is **not** on the rule under test, the block arm's
overall compliance **rose** from 95.2% to 99.2%, and no other carried item lost anything.

## 5. Cost

8 agents (4 scoping passes, 4 scorers), **1,477,139 subagent tokens**, 275 tool calls, **27.0
minutes**. No agent errored, none returned empty. Roughly half C-0c for a targeted question — which
is the argument for the single-arm design.

## 6. Reproducing this

- Block under test: `Planning/c0d-falsifier/house-rules-block-v1.21.txt` (184 lines, sha256
  `201fcd6ec52e5bb7…`).
- Rubric: `Planning/c0d-falsifier/RUBRIC.md` — C-0c's 32 items with **only P6 rewritten** to score
  the new rule.
- Memos and query logs: `Planning/c0d-falsifier/memos/`. Verdicts: `verdicts.json`. Arm key:
  `keymap.json` (every cell is a block cell; frozen before launch).
