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
flag, a file that does not exist: each is refused before the corpus is read), when the corpus holds no
volume or lacks one of the four the report makes a statement about by name (`NAMED`: a scan asserts each
such statement only where it reads that file), or, with `--check`, when the report does not carry a figure
sentence this run produced.

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
A sentence is looked for anywhere in Part A, and one occurrence is enough: each carries enough of its own
passage to stand in one place ("all 744 files in `volumes/`", not "744 files"), but a figure the report
states twice (the summary table and its section) is pinned once, by whichever copy matches.

Every quotation in the CSVs is the file's text as `ohlib.plain()` reads it:

- a run of whitespace (a line wrap and its indentation) is one space, and a footnote inside the text is
  left out;
- nothing stands where an inline tag does (`<hi>`, `<gloss>`, `<persName>` and the like), so
  `D<hi rend="smallcaps">epartment of</hi> S<hi rend="smallcaps">tate</hi>` is quoted, and read by the
  rules, as "Department of State";
- a space stands where any other tag does, whether or not the file has whitespace there. So
  `State</hi>,<lb/><hi …>Washington` is quoted "State, Washington". This is the one place a quotation
  holds a character the file lacks. At `550a8c5c5` it is 19 of `transcription.csv`'s 169 quotations, all of
  them section 6.5's datelines at an `<lb/>`. Every other quotation there, and every one in the other
  quotation columns (`dates.csv` `printed`, `cross-references.csv` `printed_reference`, both headings of
  `sources-lists.csv`, `missing-documents.csv` `heading`), matches its file with the tags stripped to nothing
  and whitespace collapsed. That was measured in review round 2 by a scratch script, not by this tool.

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
| `status_at_commit.py` | Where each filed row stands at a later corpus revision: `dump` reads one corpus copy, `compare` sets two dumps side by side. Writes only the file it is given |
| `selftest.py` | The readers, the simulated repair, `--check`, `main()`'s three refusals that need no corpus, and the pagination, part, date, transcription and Sources-list rules, over synthetic volumes in a temporary directory: a fixture for each rule, and controls (one step outside the rule, which must give no row) for the conditions that narrow it. The controls are the ones a mutant has asked for (two reviews' and a sweep's, listed in the session's `DEVELOPMENT-PLAN.md` entry); a condition nobody has mutated may have none. The cross-reference scan, the header scan, the missing-documents check and the structure rows are checked only against the corpus |

## When the corpus moves

First ask where the filed rows stand, which changes nothing:

```bash
# A copy of volumes/ at the report's revision (an APFS clone, then the changed files from git), and the clone itself:
cp -c -R ~/Development/frus/volumes /path/old/volumes
for f in $(git -C ~/Development/frus diff --name-only 550a8c5c5 HEAD -- volumes); do
  git -C ~/Development/frus show 550a8c5c5:$f > /path/old/$f; done
VOLUMES_DIR=/path/old/volumes python3 tools/oh-report/status_at_commit.py dump /path/old.json
python3 tools/oh-report/status_at_commit.py dump /path/new.json
python3 tools/oh-report/status_at_commit.py compare /path/old.json /path/new.json
```

Each structure edit is reported as `as-reported`, `corrected-as-suggested` or `changed-otherwise` (with
where each division now sits), and each scan as rows gone and rows new, matched on every column but the line
and the byte offset. Set `XREF_CSV` on each `dump` to a `CrossRefValidationGenerator` CSV made from the same
copy to include the cross-references. The copy at the old revision is not a git checkout, so its
missing-documents class is empty there: read that class from the new side alone. The three sweep rows the
report withdraws (`frus1866p2` ch17, `frus1868p2` ch33, `frus1945v01` persons) are not in `STRUCTURE` and are
not reported.

At `deb6a04f8` (2026-10-09, upstream pull request #470): 17 of the 19 structure edits are corrected as
suggested, in 13 volumes, and the two Sources-list edits (`frus1955-57v13`, `frus1964-68v06`) stand as
reported. No row of any other class is gone or new. Upstream also moved `frus1945v01`'s list of persons
out of the Introductory Note, a sweep row the report withdraws.

At `99d851c79` (2026-10-10, upstream pull request #471): Documents 900–946 are back in
`frus1952-54v09p1`, so the missing-documents class and the part-gap class stop at the new revision,
which is this tool's way of saying a class no longer holds. 352 of the 653 cross-reference rows are
gone, every one of them `target-in-missing-pages` in `frus1952-54v09p2`, and none is new. Structure
is as at `deb6a04f8`, and the dates, glued tags, headers, pagination, Sources lists and
transcription classes are as filed, row for row.

Two things changed with that run. The `ch4` heading misprint in `frus1952-54v09p1` is found from
the chapter's own start tag: read by its line number at `550a8c5c5`, it was reported gone at
`99d851c79`, where it stands 648 lines lower. At the report's revision the row and its line are
what they were (`diff -r` of the two runs' outputs is empty). And the committed
`Planning/cross-ref-validation/broken-refs-report.csv`, this tool's default `XREF_CSV`, is the
validator's run at `99d851c79`: to reproduce the report as filed, make the CSV from a copy of the
corpus at `550a8c5c5` with `CrossRefValidationGenerator` and name it.

Then, for a new edition of the report, re-run steps 1 and 2 at the new commit. Line numbers in `STRUCTURE`
and `XREF` are those of `550a8c5c5`; a volume the Office of the Historian has since corrected fails its
"before" assertion, which is the signal to delete that row. Rows are never updated to make a run pass
without re-reading the file. The report filed on 2026-10-02 and its CSVs are left as filed.
