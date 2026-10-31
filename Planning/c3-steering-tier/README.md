# C-3 steering tier (R16) — the record of the run of 2026-10-30

Design: `../C-3-Steering-Tier-Design.md`, with the owner's answers and its as-built notes at its
head. Results: `../C-3-Steering-Tier-Results-2026-10-30.md`. The two tiers' records whose harness
this reuses: `../c3-reader-test/` and `../c3-vectors-tier/`.

**The scripts:**
- `make_arm_b.py` and `card.md` write arm B, the guide's v1.38 candidate, by once-only replacements
  of the guide at v1.37. The candidate is committed on the local branch `claude/c3-steering-arm-b`
  (`84bf7e50`); it is not merged.
- `generate_s.py` cuts both arms from their pinned commits and writes the generated files:
  - arm A from `4fbf75f1`: the §12 block, whose SHA-256 is `c2f5511d…` (C-3's), §A.8's addendum
    pasted at its end, and Appendix A whole;
  - arm B from the branch: its block and §A.9's card;
  - run 9's prompt, which is B with no artifacts;
  - `workflow.mjs`, `canary.mjs`, `RUBRIC.md` (the vectors tier's 41 items plus V8, O4 and O2'),
    `check_collection.py`, `keymap.json`, `pins.json` and `prompts/` (one rendered copy of each).

  It also writes `cal.mjs`, which is `workflow.mjs` with the Cuba question v3 answered.
- `results_s.py` prints `results.md`, the table and the seven readings of the design's §6.
- `summ.py`, `save_verdicts.py` and `tally.py` give the one-screen summary, the verdicts and the
  per-agent usage of each run.

**The inputs:** `question.txt` is the owner's question. `expectations.md` was written before the
first cell and is left as written. Four of its statements are wrong or stronger than measured,
and the results file's §6 corrects them.

**The runs:** `keymap.json` maps each run to its opaque label (`s1`–`s9`) and arm.
- `runs/<label>/`: each run's `memo.md`, `overview.md`, `collection.fruscollection`, `queries.log`,
  its scripts and outputs, the refuter's scratch, `verdicts.json` and `tally.md`.
- `runs/canary/`: the environment proof of the card's code.
- `runs/cal/`: only the calibration's verdicts and the refuter's scratch. The run it scored is the
  vectors tier's v3, at `../c3-vectors-tier/runs/v3/`.

**Left out:** files over a megabyte and three Python pickles, listed in `PRUNED.txt`. The full
folders are at `~/frus-analysis/c3s/runs/`, and the index copy and the shards at
`~/frus-analysis/c3/`.

**The ledger:** `usage.md` holds the meters before and after every step.
