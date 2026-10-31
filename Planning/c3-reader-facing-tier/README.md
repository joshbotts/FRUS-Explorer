# C-3 reader-facing tier — the record of the run of 2026-10-31

Design: `../C-3-Reader-Facing-Tier-Design.md`, with its as-built notes at its head. Results:
`../C-3-Reader-Facing-Tier-Results-2026-10-31.md`. The tiers whose harness this reuses:
`../c3-steering-tier/` and `../reader-facing-style/pilot/`.

**The scripts:**
- `make_arm_w.py` and `make_arm_k.py` write the two guide candidates from the guide at `848f3781`
  (v1.38) by once-only replacements. They are committed on the local branches
  `claude/c3-reader-facing-arm-w` (`b40d2da6`) and `claude/c3-reader-facing-arm-k` (`5e8bd1bd`), not
  merged and not pushed.
- `generate_f.py` cuts the three arms from their pinned commits and writes `workflow.mjs`,
  `cal.mjs`, `canary.mjs`, `RUBRIC.md`, `check_collection.py`, `keymap.json`, `pins.json` and
  `prompts/`.
- The harness's checks, run on each run directory after its session ended (`after_run.sh`), write
  into its `checks/`: `o2p_check.py` (O2'), `match_check.py` (terms that reach nothing, prefixes and
  lookups), `figures_check.py` (the house rules' figures) and `style_measure.py` (the writing).
  `o2p_calibrate.py` holds the O2' script to the misses R16's and the pilot's scorers named.
- `save_f.py`, `summ_f.py`, `tally.py` and `results_f.py` save the verdicts, summarise a run, tally
  the agents and print `results.md`.

**The inputs:** `question.txt` is the owner's question. `expectations.md` was written before the
first cell and is left as written.

**The runs:** `keymap.json` maps each run to its label (`f1`–`f12`), block and arm, and each block's
judge to its slots.
- `runs/<label>/`: the session's files, `checks/`, `verdicts.json` and `tally.md`.
- `runs/canary/`: the environment proof.
- `runs/cal-*/`: only the calibration's verdicts and checks. The runs it scored are R16's s1 and s3,
  the vectors tier's v2 and C-3's r8, in their own records.
- `judges/`: each block's judgement.

**Left out:** files over a megabyte and Python pickles, listed in `PRUNED.txt`. The full folders are
at `~/frus-analysis/c3f/runs/`.

**The ledger:** `usage.md` holds the meters before and after every step.
