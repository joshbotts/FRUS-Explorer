# Evidence for the #234 reframe assessment delta (2026-09-13)

The assessment is `Planning/234-Early-Era-People-Reframe-Assessment-2026-09-13.md`. Every evidence path it cites is relative to this folder.

## Layout

| path | what it holds |
|---|---|
| `reframe/prior-assessments.md` | The two in-session answers the delta re-reads, verbatim, with the questions that prompted them: whether a Sonnet or Opus pass could beat the free detectors, and whether Source Explorer's chapter context helps pre-1900 correspondents. |
| `reframe/read-feasibility/`, `reframe/read-app/`, `reframe/read-claude/` | The three reader agents' scripts and outputs. |
| `reframe/measure-*/` | The five offline measurements: Source Explorer against POCOM after #1292, the detector-agreement census, Claude job sizing, the offset mapping, and the identity silver set. |
| `reframe/verify-measure-*/` | An independent reproduction of each measurement, with its own scripts. |
| `reframe/journal-results.json` | Every agent's structured return value from the measurement workflow. |
| `reframe/critique/` | The critic's review (`critique.json`) and its one measurement (`era_reach.py`, `era_reach.json`). |
| `reframe/synthesis/` | The first draft (`reframe-delta.md`), the corrected text the Planning file is made from (`reframe-delta-v2.md`), its change log, the rewrite check's scripts, and the residual-fix script. |
| `llm-pass/` | The evidence behind the Claude-pass answer: cost model, fixability, identity cases, program fit. |
| `chapter-context/` | The evidence behind the Source Explorer answer: harness sources, coverage, fit, label validation, skeptic. |
| `geo-fix/after/source-sha256.txt` | The stale hash record named in erratum 6. |

## Not copied

32 files over 1 MB were left out. Each is a per-row intermediate or a packed artifact, regenerable from the script beside it against the stores.

| file | size |
|---|---|
| `reframe/measure-silver/links.jsonl` | 495.7 MB |
| `reframe/verify-measure-silver/v-fromto.jsonl` | 70.8 MB |
| `reframe/measure-se-pocom/classified/head-docs.jsonl` | 65.5 MB |
| `chapter-context/harness/frus-pre1906-classified.jsonl` | 65.4 MB |
| `reframe/measure-silver/fromto.jsonl` | 61.9 MB |
| `chapter-context/label-validation/classified-list-volumes.jsonl` | 59.7 MB |
| `reframe/measure-se-pocom/classified/head-listvols-docs.jsonl` | 45.9 MB |
| `chapter-context/label-validation/scored-mentions.jsonl` | 30.5 MB |
| `reframe/measure-silver/silver-rows.jsonl` | 14.5 MB |
| `chapter-context/harness/export.jsonl` | 9.7 MB |
| `llm-pass/cost-scale/docs.tsv` | 9.2 MB |
| `reframe/verify-measure-agreement/artifact-agreement.json` | 8.9 MB |
| `reframe/measure-agreement/artifact-agreement.json` | 8.9 MB |
| `reframe/measure-agreement/artifact-union_marked_filtered_control.json` | 8.6 MB |
| `reframe/measure-agreement/artifact-intersection_sweep_side.json` | 8.0 MB |
| `chapter-context/label-validation/export-list-volumes.jsonl` | 5.2 MB |
| `chapter-context/label-validation/gold-mentions.jsonl` | 5.0 MB |
| `reframe/measure-se-pocom/harness-head/central-files-index.json` | 3.4 MB |
| `chapter-context/skeptic/h/central-files-index.json` | 3.4 MB |
| `chapter-context/harness/central-files-index.json` | 3.4 MB |
| `reframe/verify-measure-agreement/artifact-agreement.json.gz` | 2.8 MB |
| `reframe/measure-agreement/artifact-agreement.json.gz` | 2.8 MB |
| `reframe/measure-agreement/artifact-union_marked_filtered_control.json.gz` | 2.7 MB |
| `reframe/measure-agreement/artifact-intersection_sweep_side.json.gz` | 2.6 MB |
| `reframe/measure-agreement/artifact-marked.json` | 2.5 MB |
| `reframe/measure-offsets/flat-spans.jsonl` | 2.4 MB |
| `reframe/measure-offsets/sample-spans.jsonl` | 2.4 MB |
| `chapter-context/label-validation/pocom-posts.json` | 2.1 MB |
| `reframe/measure-silver/registry-provenance.json` | 2.0 MB |
| `reframe/measure-se-pocom/out/rows.jsonl.gz` | 1.9 MB |
| `chapter-context/label-validation/gold-entries.jsonl` | 1.8 MB |
| `reframe/measure-offsets/swiftcli/flat-sample.jsonl` | 1.5 MB |

176 build caches and compiled binaries (134 MB) were also left out, mostly Swift module caches under `reframe/measure-offsets/swiftcheck/`.

One file over the cut is copied because the assessment cites it: `reframe/measure-se-pocom/out/merged-rule.json` (1.0 MB).

## Reading and re-running

- **Everything was read-only** against the live index (`frus.db`, opened `mode=ro`, index version 50), `~/frus-ner-raw*`, the Mac Studio M2a gold folder, `~/frus-semantic-raw/text`, the TEI corpus, and the POCOM and people registers.
- **Scripts hard-code the session scratchpad paths they ran from.** Re-running one means pointing those paths at this folder and at the stores.
- **No scripted LLM or token-count API call was made.** Corpus snippets were read inside Claude Code sessions, which send them to Anthropic (assessment §0, gate N1).
- **The held-out M2a documents are not named here.** No file in this folder names any of the 8 unkeyed M2a documents by volume and document id (checked before commit). #1290's `feasibility-2026-09-12/verify-method/stores.json` already names all 8 by staged filename, with size, seed count and hash, and no text or spans.
