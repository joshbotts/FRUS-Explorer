# Page citations — the measurements behind #1503

#1503 changed which document a page names: a page-only citation (*FRUS, 1945, vol. V, p. 123*), a
reader's page link and a stored `<ref target="#pg_N">` edge now go to the document that **begins**
on the page, where they went to the document owning the last `<pb>` at or before it. The figures
in that change's code comments (`PageSpanResolver`'s type doc, `placingStart` and
`numbersPagesPerDocument`, `CitationMatchingEngine`'s type doc and `sharedPageListLimit`,
`IndexingPipeline`'s v61 note and `resolvePageBasedCrossReferences`, `FRUSDocumentAST.startPage`,
`PageNumber.parse(_:xmlId:)`, and `CitationMatchingEngineTests`' `mixedPerDocumentVolume`) and in
its `Planning/DEVELOPMENT-PLAN.md` entry come from these scripts; the v61 note points at this
directory, and each of the others names the script behind its figures. They were written in the
lane's session folder and committed here for #1512, so every figure can be re-derived from a
clone.

**Corpus: `HistoryAtState/frus` at `550a8c5c5`** (the merge of its PR #465, *xrefs-contd*), and
`FRUSExplorer/Resources/manifest.json` as of `b192f8fc` (unchanged since, through this commit).
A later corpus moves the numbers; say which commit you ran against.

Stdlib only, the macOS-bundled `python3` (3.9) — the `tools/semantic-harvest/` contract. Nothing
here reads the app, the index or the network, and the corpus is only ever read: the two passes
write to the directory you name, and the analysis scripts print.

## Run

Two SAX passes over the corpus write per-volume JSON; every other script reads one or both.

```bash
export VOLUMES_DIR=~/Development/frus/volumes         # the default; set it if yours lives elsewhere
python3 tools/page-citations/scan_corpus.py /tmp/pc/scan   # 553 volumes, ~40 s
python3 tools/page-citations/replica.py     /tmp/pc/rep    # 553 volumes, ~50 s

python3 tools/page-citations/measure_rules.py /tmp/pc/scan
python3 tools/page-citations/rules_f.py       /tmp/pc/rep /tmp/pc/scan
python3 tools/page-citations/xrefs_f.py       /tmp/pc/rep /tmp/pc/scan
# … and the rest, each taking the directory its row below names
```

`MANIFEST` overrides the manifest (default: this repo's). Each analysis script refuses to run over
an empty directory rather than printing zeroes. The timings were measured on an Apple M5 with
python 3.9.6; each analysis script takes seconds.

## The two passes

| script | writes | records |
|---|---|---|
| `scan_corpus.py OUT` | `OUT/<volume>.json` | **`div[@type="document"]` only**: each document's start page (the `@n` of the last `<pb>` before its first printed text), M2's first-child variant of it, its own `<pb>`s, its `frus:doc-dateTime-min`; every `#pg_` reference inside a document with the text of its enclosing `<note>`; and the `@n` of every `<pb>` outside every document div (`pbs_outside`, added in #1512's review round 1; the scripts reading the scan ignore it, except `rules_f.py`) |
| `replica.py OUT [VOLUME …]` | `OUT/<volume>.json` | **everything the parser emits as an AST**, in emission order — documents, legacy editorial notes and the prose sections `TEIParserDelegate` promotes to quasi-documents — with each one's start `<pb>` (`@n` and `xml:id`), the `<pb>`s its nodes hold and the `#pg_` refs they hold |

The scan was the lane's first measurement and could not see a promoted section's start row; review
round 1 wrote the replica to measure the rule over the rows the index actually holds. Where the
two disagree, **the replica's figures are the ones the shipped code states**.

## What each script reproduces

Every figure below was reproduced exactly on 2026-09-27 against the corpus above; the five lane
scripts and `simulate.py` also reproduce their recorded output **byte for byte**, over the scan
both before and after it gained `pbs_outside`. The figures #1512's review found stated in a
comment or the plan with no script printing them are now printed by `rules_f.py`,
`quasi_starts.py` and `brackets.py`: the closing part of each of their rows below.

**Over the scan** (the lane's figures, the DEVELOPMENT-PLAN entry's first half):

| script | reproduces |
|---|---|
| `measure_rules.py SCAN` | 311,245 document divs in the 548 volumes that are not microfiche supplements (306,672 printed + 4,573 per-document); **306,469** printed-volume documents with a recorded arabic start; at the page each begins on, the old rule's preceding document 156,646 / earlier 32,276 / none 117,525 / several 20 / itself 2, the new rule's **itself alone 185,473** / among several 120,996; 494,101 distinct pages (begins-one 185,473, begins-several 54,934, printed-one 253,587, printed-several 107; old: one 410,270, several 100, none 83,731); the page check (178 unplaced, 582 newly placed, 173 still not, 5 lost, 740 in the per-document volumes, 77,887 ranges narrower, 42 old ranges excluding the start page; 173 + 582 + 740 is the engine's 1,495 nothing placed before #1503); M2's variant differing for 2 |
| `measure_xrefs.py SCAN` | **55,007** same-volume arabic `pg_N` references inside documents in the 533 printed volumes; 8,171 unchanged, **29,753 moved**, **16,904 newly resolved**, 179 by neither; where the rules differ and the note names one date, the new rule's **6,061** against the old's **455**; of 12,749 references to a page several documents begin on, the note names the first **2,502** times and only a later one **1,825** (none of theirs 8,422) |
| `count_brackets.py SCAN` | starts by spelling: 310,695 digit, 364 bracketed (`[31]`), 71 roman, 12 other, 103 none; 14 bracketed breaks inside documents in 8 volumes |
| `inspect_gaps.py SCAN` | the 178 unplaced printed-volume documents (100 `frus1977-80v27` with no break, 78 on a non-arabic page, 62 of them `frus1863p1`'s roman pages) and the 25 that fall back (20 out-of-order; 4 garbled numbers such as `254 [524]`, and `frus1902app1` d100's plate label `[Map 7]`) |
| `list_pagination_defects.py SCAN` | the 20 documents in 11 volumes whose own break runs below the page they begin on (#1309's next report) |

**Over the replica** (review round 1; the figures the code comments state):

| script | reproduces |
|---|---|
| `rules_f.py REP [SCAN]` | of **306,463** printed-volume documents whose start places them, the old rule's preceding document 156,625 / an earlier document or a section 32,293 / none 117,503 / several 40 / itself 2, and the new rule's **itself alone 185,470** / among others 120,993 (`PageSpanResolver`'s and `CitationMatchingEngine`'s type docs); the documents nothing places, 178 printed and 349 per-document (the engine's 527). Then: the printed volumes' pages by how many they name — at most **ten**, on one page, and nine on three (`sharedPageListLimit`); in the fifteen per-document volumes, page 1 under the shipped rule against what the committed rule listed, `frus1969-76ve10` **665** against 120 and `frus1981-88v16` **88** against 15; and with SCAN, each one's page-1 breaks outside every document div against the documents holding one (ve10 0 and 657, ve04 221 and 108: `mixedPerDocumentVolume`). And the per-document gate's margins (`numbersPagesPerDocument`): at most `frus1902app1`'s 2 of 196 printed-volume documents restart, and `frus1919Parisv13` reaches 36 of 149 when every row with a page counts, a section by its breaks; and in the per-document volumes, 391 documents with no break of their own begin on a page 1 (377 on a break outside every document, 14 on one another document holds) and 349 on a later page (`placingStart`) |
| `xrefs_f.py REP SCAN` | of the 55,007 references: 8,206 stay, **29,760 move**, **16,897 newly resolve**, 144 by neither, 35 stored against a promoted section; 6,061 against 455; 12,749 on a page several begin on, 2,502 / 1,825 / 8,422 (the v61 note and `resolvePageBasedCrossReferences`) |
| `simulate.py REP` | the committed rule (C) against round 1's (F): 869 printed-volume pages whose first answer moves, references stored against a section (C 267, F 116), the 1,182 printed-volume pages F answers with a section; the fifteen volumes that number pages per document with their restart rates (`frus1969-76ve14p1` 106 of 189 to `frus1969-76ve04` 306 of 330, `numbersPagesPerDocument`), and their 520 page numbers, 85 of which C answered with one document (36 begin there, 49 printed there); the 349 per-document documents C placed and F leaves unplaced |
| `simulate2.py REP` | against v2's rule, no reference that resolved stops resolving (0 resolved-then-unresolved of 55,880 refs in every emitted AST); 18 pages mixing a section and a document |
| `quasi_starts.py REP` | **1,425** promoted sections beginning on an arabic page; their start rows move the first answer for **309** pages in **96** volumes, **201** of them from the one document printed there (`FRUSDocumentAST.startPage`). Under the bracket rule before round 1's fix 2, 1,427 |
| `brackets.py REP` | **358** document starts on a bracketed page whose id is its `pg_N`, **6** on `frus1871`'s `pg-seq1_` pagination, and all **14** bracketed breaks inside documents `pg_N` (`PageNumber.parse(_:xmlId:)`). Then the digit breaks whose id is not `pg_N`: **256** `<pb>`s in 6 printed volumes (270 counted once per AST holding or starting on one) — `frus1871` 119, `frus1977-80v20` 99 zero-padded, `frus1862` 20, `frus1865p1` 16, and one each in `frus1884` and `frus1977-80v13`, whose ids disagree with their `@n` — and the pages naming the AST that holds one beside another: 81 of `frus1871`'s name two documents, 9 each of `frus1862`'s and `frus1865p1`'s the President's message beside a document |
| `sections_by_volume.py REP` | the 1,182 pages by volume: **926** are `frus1919Parisv13`'s, and **740** of those answer with several sections at once, because a promoted chapter does not mark its parent as holding documents: a compilation with a chapter or subchapter it holds on 730, a chapter with its subchapter on 10 |

## What is not here

The lane's mutation-testing helpers (`apply_mutants.py`, `mutants.py`, `run_set.sh`) and its A/B
and full-unit logs stay in the session folder the DEVELOPMENT-PLAN entry names: they drove the
test suites against the Swift code as it stood that day, and neither reproduces a corpus figure.
`peek.py`, a one-off printer of a few documents' raw TEI, and `r1_restarts.py`, a first look at
the per-document restart rate that `simulate.py` supersedes, are left out for the same reason.
