# C-3 run record (guide §13, design §7)

- Date: 2026-10-25. Started on the owner's word ("start C-3 now with build 1776"), before the
  App Store submission; plan of record decision 91 had it after submission.
- App build: 1.0 (1776), the TestFlight pass, installed at /Applications/FRUS Explorer.app;
  its commit is `f0479037`, tag `build-51`; index version 71 (`currentDateIndexVersion`).
- The copy: `~/frus-analysis/c3/frus-copy-2026-10-25.db`, `.backup` of the live index
  (3,743,547,392 bytes, live file dated 2026-10-22 20:59) taken 2026-10-25 13:44 with the Mac app
  not running; both rank-1 integrity checks passed; journal mode set to DELETE on the copy so a
  read-only open needs no -shm file. It is a hand-made copy: no `research_provenance` table, no
  `research_*` views, and the owner's writing is NOT stripped (counts in verify2.log); the §12
  block forbids the agents to read those columns.
- TEI: the app's own downloaded volumes,
  `~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes/`
  (553 .xml).
- Bundled JSON: `/Applications/FRUS Explorer.app/Contents/Resources/` (38 .json, build 1776).
- Guide: v1.33 (2026-10-21) at `f0479037`; the §12 block is extracted from it by `generate.py`,
  READER-FACING OUTPUT section included (in the block since v1.29).
- sqlite3 3.54.0 (2026-04-09); Python 3.9.6; macOS 27.0 (Darwin 27.0.0).
- Rubric: C-0c's file carried whole (its 24 main items and P1–P6, 30 scored items) plus O1–O3
  from the review's §3: 33 items. The design says "24 items" and names the C-0c rubric; the file
  it names scores 30, and dropping P1–P6 would change the instrument, so all 30 are kept.
- Harness: the Workflow tool in this Claude Code session (desktop app), cells pinned by `model`
  and `effort` per the design's §2; instruments on claude-fable-5-1 at max.
- Blinding: cells get opaque labels (keymap.json); instruments see the label only.
- §12 block as extracted: 205 lines, SHA-256 (first 16) c2f5511d8c976c35. Prompt lengths: runner
  26,804 characters, scorer 2,931, refuter 4,802, judge 2,449; none prints `-uri` outside its warning.
- Rubric file: 35 scored items (the C-0c main table holds 26, not the 24 its header says; P1–P6;
  O1–O3). Keymap: S-med r3, S-high r5, S-max r1, O-med r4, O-high r6, O-max r2, F-med r8,
  F-high r9, F-max r7 (random.Random(20261025) shuffle); cal = the Cuba kit.
- Run directories: `~/frus-analysis/c3/runs/<label>/` (not the session scratchpad, which is wiped on
  reboot); the workflow scripts are run from a copy in the scratchpad because the tool reads only
  there, the originals stay in `~/frus-analysis/c3/`.
- The owner's writing in the copy: 6,558 summary_text, 8 note_text, 111 user_tag_ids rows, 21 user_tags;
  not stripped (as every earlier run's copy); no agent is permitted to read those columns (E2).
- Canary: wf_43088a83-103, sonnet at medium (the S-med pin), on the runner's RESOURCES text.
- Stop line: 69% (25 points over the 44% baseline) until 2026-10-25 21:4x, then 75% on the owner's word
  while F-med ran. Every cell before the change was run under the 69% line.
