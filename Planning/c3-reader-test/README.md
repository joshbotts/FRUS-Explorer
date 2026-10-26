# C-3 — the record of the run of 2026-10-25/26

Design: `../C-3-Reader-Test-Design.md`. Results: `../C-3-Results-2026-10-26.md`. Harness facts:
`../Agentic-Harness-Runbook.md`.

- `generate.py` — reads the guide (§12 block, §15.1a example, §15.2 checker), the C-0c rubric and
  the review's O1–O3, and writes `workflow.mjs`, `RUBRIC.md`, `check_collection.py`,
  `keymap.json` and `prompts/`. Nothing in a prompt was transcribed by hand.
- `workflow.mjs` — the script run once per cell with `args: {cells: [{label, model, effort}],
  previous: [labels already judged]}`; `canary.mjs` — the environment proof that ran first.
- `keymap.json` — cell → opaque label (the instruments saw the label only); `cal` is the Cuba kit.
- `runs/<label>/` — the cell's `memo.md`, `overview.md`, `collection.fruscollection`,
  `queries.log`, its scripts and small outputs, the refuter's scratch, `verdicts.json` (the
  scorer's, refuter's and judge's structured returns) and `tally.md` (per agent: model, tokens by
  kind, tool calls, wall clock). Document dumps and files over a megabyte are left out
  (`PRUNED.txt`); the full folders are beside the index copy at `~/frus-analysis/c3/runs/`.
- `usage.md` — the Max plan's meter before and after every step, with each step's figures.
- `facts.md` — the guide-§13 record: build, index version, the copy, the surfaces, versions.
- `results.py` / `results.md` — the table and the three pre-registered readings.
- `tally.py`, `save_verdicts.py` — the two helpers run after each workflow.
- `calibration/cubatalksagentkit.md` — the 2026-08-31 starter kit the instruments were calibrated on.
