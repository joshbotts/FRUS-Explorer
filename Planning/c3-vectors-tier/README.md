# C-3 vectors tier — the record of the run of 2026-10-26/27

Design: `../C-3-Vectors-Tier-Design.md` (the owner's four decisions at its head). Results:
`../C-3-Vectors-Tier-Results-2026-10-27.md`. C-3's record, whose harness this reuses: `../c3-reader-test/`.

- `generate_v.py` — C-3's generator with the tier's three additions, all cut from the guide by marker:
  Appendix A whole (328 lines at v1.35), the vector artifacts as RESOURCES item 4, a VECTORS section in
  the memo; V1–V6 appended to the rubric; the refuter's vector-use and reach steps; the question read
  from `question.txt`. Writes `workflow.mjs`, `canary.mjs`, `RUBRIC.md`, `check_collection.py`,
  `keymap.json`, `prompts/`.
- `vectors_check.py` — runbook §1: reproduces the neighbour list, the decode and every digest the canary
  checks, from the shipped files, before any agent ran. `appendix_recheck.py` / `appendix_recheck.json` —
  the re-take of Appendix A's worked figures at the shipped digest (guide v1.35).
- `keymap.json` — cell → opaque label; `calv` is C-3's r5 scored with the 41 items (calibration).
- `runs/<label>/` — each run's `memo.md`, `overview.md`, `collection.fruscollection`, `queries.log`,
  its scripts and small outputs, the refuter's scratch, `verdicts.json`, `tally.md`; `runs/canary/`
  and `runs/calv/`. Document dumps and files over a megabyte are left out (`PRUNED.txt`); the full
  folders are at `~/frus-analysis/c3v/runs/`, the index copy and the shards at `~/frus-analysis/c3/`.
- `usage.md` — the meter before and after every step; `facts.md` — the guide-§13 record;
  `results_v.py` / `results.md` — the table and the five readings of the design's §6.
