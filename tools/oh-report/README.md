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

`Planning/OH-Report-2026-10-01/web-checks.txt` is four runs merged by hand (three whole passes of step 3,
and a fourth of two single requests), because history.state.gov answers 403 for any page once it has had
a few dozen requests: its header says which run each line is from. Do not overwrite it with one pass
without reading the 403s.

`CORPUS_COMMIT` is the revision of `HistoryAtState/frus` the corpus copy is at (`git -C ~/Development/frus
log -1`, or an earlier commit when `git diff <commit> HEAD -- volumes` is empty). Every line number and byte
offset in the report is relative to it.

## What it does

Two kinds of class, and the script says which is which:

- A **scan** runs one rule over all of `volumes/*.xml`; its rows are whatever the rule finds. Pagination,
  dates, transcription, headers and the Sources lists are scans. A scan that finds nothing stops the run.
  A scan's rule is a heuristic, and two of the first draft's were wrong (a list's "1)" counted as a stray
  parenthesis; a space supplied at every tag, which misspelt four datelines). Read a sample of a class's rows
  in the file before trusting its count, and give a new rule a control in `selftest.py`.
- An **adjudicated table** is written by hand in `build_oh_report.py`, and each row is re-verified on every
  run. The structure rows (`STRUCTURE`) state a file's nesting before and after one edit: the script asserts
  the "before", applies the edit to a copy in memory, re-parses it, and asserts the "after". The
  cross-reference causes (`XREF`) each name a suggested target, which must exist. A row that no longer holds
  stops the run.

The run **writes nothing, prints `NOT WRITTEN` and exits 1** when a re-check fails, when `CORPUS_COMMIT` is
missing, when its arguments are anything but none or `--check FILE` (the flag alone, the file before the
flag, a file that does not exist: each is refused before the corpus is read), or, with `--check`, when the
report does not carry a figure sentence this run produced.

The **figure sentences** are how the report's numbers are tied to the corpus: 53 of them, printed at the end
of every run (`figure_sentences`). `--check` looks for each one:

- in **Part A only**, the text that goes to the Office of the Historian (the report must have a `# Part A`
  and a `# Part B` heading; Part B repeats some figures and does not count);
- as a **whole figure**. A sentence that begins or ends with a number is not found inside a longer number,
  so a run that now says "1 files carry" does not pass on a report that still says "11 files carry". This
  matters most on the re-run after the Office of the Historian corrects volumes, when counts fall;
- and the lines above Part A must state how many sentences there are.

A figure in Part A that no sentence states is not checked. The sentences cover every class's total and
each count in section 6; the per-volume examples (for instance "`frus1875v02` has 11") are not among them.

Every quotation in the CSVs is the file's own text. `ohlib.plain()` puts nothing where an inline tag stands
(`<hi>`, `<gloss>`, `<persName>` and the like) and a space where any other tag does, so
`D<hi rend="smallcaps">epartment of</hi> S<hi rend="smallcaps">tate</hi>` is quoted, and read by the
rules, as "Department of State".

The broken cross-references come from `CrossRefValidationGenerator`'s CSV. The script checks each of its rows
at its byte offset, then runs its own scan of every `<ref target>` by the same resolution rule
(`CrossRefKit.RefClassification.anchorCandidates`, transcribed). Every row of the CSV must be in the script's
set. The script's set may hold more only for references made in, or into, a file outside the app's manifest,
which the generator tallies and does not list; anything else it finds beyond the CSV stops the run. At
`550a8c5c5` the two sets are equal.

## Files

| File | What |
|---|---|
| `ohlib.py` | Byte-scan readers: the div tree, page breaks, ids; the simulated repair (`move_close_tags`, `retype_div`) |
| `build_oh_report.py` | The classes, the adjudicated tables, the CSVs, `counts.json`, `--check` |
| `check_urls.sh`, `urls.txt` | The public-site checks, with their controls |
| `selftest.py` | The readers, the simulated repair, `--check`, and the pagination, part, date, transcription and Sources-list rules, over synthetic volumes in a temporary directory: a fixture for each rule and a control (one step outside the rule, which must give no row) for each condition that narrows it. The cross-reference scan, the header scan, the missing-documents check and the structure rows are checked only against the corpus |

## When the corpus moves

Re-run steps 1 and 2 at the new commit. Line numbers in `STRUCTURE` and `XREF` are those of `550a8c5c5`; a
volume the Office of the Historian has since corrected fails its "before" assertion, which is the signal to
delete that row. Rows are never updated to make a run pass without re-reading the file.
