# tools/oh-report — the report to the Office of the Historian (#1309)

These scripts re-check every item of `Planning/OH-Report-2026-10-01.md` against the FRUS TEI corpus and
write the CSVs that go with it. Standard library only, macOS's bundled `python3`. They read the corpus
and the app's manifest, write only under `OUT_DIR`, and change nothing in the app.

## Run it

```bash
# 1. The broken cross-references, from the app's own validator, into scratch (never into Resources):
OUTPUT_DIR=/tmp/xref GENERATED_DATE=2026-10-01 swift run -c release CrossRefValidationGenerator

# 2. Everything else, and the CSVs. CORPUS_COMMIT is required and has no default.
CORPUS_COMMIT=550a8c5c5 GENERATED_DATE=2026-10-01 XREF_CSV=/tmp/xref/broken-refs-report.csv \
  python3 tools/oh-report/build_oh_report.py --check Planning/OH-Report-2026-10-01.md

# 3. The public-site checks (network; about ten minutes, because the site throttles):
sh tools/oh-report/check_urls.sh > /tmp/web-checks.txt

# 4. The tool's own tests (no corpus needed):
python3 tools/oh-report/selftest.py
```

`Planning/OH-Report-2026-10-01/web-checks.txt` is three passes of step 3 merged by hand, because
history.state.gov answers 403 for any page once it has had a few dozen requests: its header says which
pass each line is from. Do not overwrite it with one pass without reading the 403s.

`CORPUS_COMMIT` is the revision of `HistoryAtState/frus` the corpus copy is at (`git -C ~/Development/frus
log -1`, or an earlier commit when `git diff <commit> HEAD -- volumes` is empty). Every line number and byte
offset in the report is relative to it.

## What it does

Two kinds of class, and the script says which is which:

- A **scan** runs one rule over all of `volumes/*.xml`; its rows are whatever the rule finds. Pagination,
  dates, transcription, headers and the Sources lists are scans. A scan that finds nothing stops the run.
- An **adjudicated table** is written by hand in `build_oh_report.py`, and each row is re-verified on every
  run. The structure rows (`STRUCTURE`) state a file's nesting before and after one edit: the script asserts
  the "before", applies the edit to a copy in memory, re-parses it, and asserts the "after". The
  cross-reference causes (`XREF`) each name a suggested target, which must exist. A row that no longer holds
  stops the run.

The run **writes nothing and exits 1** when a re-check fails, when `CORPUS_COMMIT` is missing, or (with
`--check`) when the report does not carry a figure sentence this run produced. The figure sentences are
printed at the end of every run; they are how the report's numbers are tied to the corpus.

The broken cross-references come from `CrossRefValidationGenerator`'s CSV. The script checks each of its rows
at its byte offset, then runs its own scan of every `<ref target>` by the same resolution rule
(`CrossRefKit.RefClassification.anchorCandidates`, transcribed) and requires the two sets to be equal.

## Files

| File | What |
|---|---|
| `ohlib.py` | Byte-scan readers: the div tree, page breaks, ids; the simulated repair (`move_close_tags`, `retype_div`) |
| `build_oh_report.py` | The classes, the adjudicated tables, the CSVs, `counts.json`, `--check` |
| `check_urls.sh`, `urls.txt` | The public-site checks, with their controls |
| `selftest.py` | The readers, the simulated repair, and the pagination, part and date rules, over synthetic volumes in a temporary directory. The cross-reference, transcription, header and Sources-list scans are checked only against the corpus |

## When the corpus moves

Re-run steps 1 and 2 at the new commit. Line numbers in `STRUCTURE` and `XREF` are those of `550a8c5c5`; a
volume the Office of the Historian has since corrected fails its "before" assertion, which is the signal to
delete that row. Rows are never updated to make a run pass without re-reading the file.
