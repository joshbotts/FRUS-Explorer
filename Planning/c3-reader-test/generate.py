#!/usr/bin/env python3
"""C-3 generator: reads the guide, the C-0c rubric and the review, and emits workflow.mjs,
RUBRIC.md, check_collection.py, keymap.json and one rendered copy of each prompt.

Nothing in the prompts is hand-transcribed from the guide: the §12 block, the §15.1a example,
the §15.2 checker and the O1–O3 items are cut out of the files by marker (runbook §8).
"""
import hashlib, json, random, re, sys, pathlib

REPO = pathlib.Path('/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/c3-cloud-sessions-95c770')
GUIDE = REPO / 'Docs/Agentic-Analysis-Guide.md'
REVIEW = REPO / 'Planning/Agentic-Guide-Accessibility-Review-2026-10-14.md'
C0C_RUBRIC = REPO / 'Planning/c0c-falsifier/RUBRIC.md'
OUT = pathlib.Path('/Users/jbotts/frus-analysis/c3')
DB = '/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db'
TEI = '/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes'
RES = '/Applications/FRUS Explorer.app/Contents/Resources'
RUNS = '/Users/jbotts/frus-analysis/c3/runs'
RUBRIC_PATH = str(OUT / 'RUBRIC.md')
CHECKER_PATH = str(OUT / 'check_collection.py')
COVERAGE = (OUT / 'coverage.txt').read_text().strip()   # the canary's known answer

QUESTION = ('How did the United States decide whether to recognize governments that came to power '
            'by force in Latin America, and what did it ask of them before recognizing?')

guide = GUIDE.read_text()

# ---- the §12 block, fence to fence -------------------------------------------------------------
i = guide.index('\n## 12. A house-rules block to paste into your agent')
j = guide.index('```text\n', i) + len('```text\n')
k = guide.index('\n```\n', j)
BLOCK = guide[j:k].rstrip('\n') + '\n'
assert 'READER-FACING OUTPUT' in BLOCK, 'the block lost its reader-facing section'
assert '-uri' not in BLOCK.replace('no `-uri`', '').replace('`-uri`', ''), BLOCK

# ---- §15.1a example and §15.2 checker, cut by marker -------------------------------------------
a = guide.index('### 15.1a The findings in the file')
b = guide.index('```json\n', a) + len('```json\n')
c = guide.index('\n```\n', b)
COLLECTION_EXAMPLE = guide[b:c].strip('\n')
json.loads(COLLECTION_EXAMPLE)  # it must parse
a = guide.index('### 15.2 One constraint the app does not enforce')
b = guide.index('```python\n', a) + len('```python\n')
c = guide.index('\n```\n', b)
CHECKER = guide[b:c].strip('\n') + '\n'
pathlib.Path(CHECKER_PATH).write_text(CHECKER)

# ---- the rubric: C-0c's file whole, plus O1–O3 from the review ---------------------------------
review = REVIEW.read_text()
o_rows = [l for l in review.splitlines() if re.match(r'\| O[123] \|', l)]
assert len(o_rows) == 3, o_rows
rubric = C0C_RUBRIC.read_text().rstrip('\n') + '\n\n'
rubric += ('## ADDED FOR C-3 — O1–O3, the READER-FACING OUTPUT section made scoreable\n\n'
           'From `Planning/Agentic-Guide-Accessibility-Review-2026-10-14.md` §3 (R8). Scored on the\n'
           'OVERVIEW (`overview.md`), with the memo consulted for O2\'s trace. Same verdict vocabulary.\n\n'
           '| id | block | item |\n|---|---|---|\n' + '\n'.join(o_rows) + '\n\n')
N_TOTAL = len(re.findall(r'^\| [A-Z]\d \|', rubric, re.M))
N_MAIN = N_TOTAL - 9   # P1–P6 and O1–O3 sit in the sections at the end
assert N_TOTAL == 35 and N_MAIN == 26, (N_TOTAL, N_MAIN)   # C-0c's header says 24; its table holds 26
rubric += f'**{N_TOTAL} items in all**: the {N_MAIN} of the main table, P1–P4, P5–P6, and O1–O3.\n'
pathlib.Path(RUBRIC_PATH).write_text(rubric)

# ---- the cells and their opaque labels --------------------------------------------------------
CELLS = [
    ('S-med', 'claude-sonnet-5-5', 'medium'), ('S-high', 'claude-sonnet-5-5', 'high'), ('S-max', 'claude-sonnet-5-5', 'max'),
    ('O-med', 'claude-opus-5-5', 'medium'), ('O-high', 'claude-opus-5-5', 'high'), ('O-max', 'claude-opus-5-5', 'max'),
    ('F-med', 'claude-fable-5-1', 'medium'), ('F-high', 'claude-fable-5-1', 'high'), ('F-max', 'claude-fable-5-1', 'max'),
]
rng = random.Random(20261025)
labels = [f'r{n}' for n in range(1, 10)]
rng.shuffle(labels)
keymap = {cell: {'label': lab, 'model': m, 'effort': e} for (cell, m, e), lab in zip(CELLS, labels)}
keymap['cal'] = {'label': 'cal', 'model': None, 'effort': None,
                 'note': 'calibration: the 2026-08-31 Cuba starter kit scored as if it were a cell'}
(OUT / 'keymap.json').write_text(json.dumps(keymap, indent=2) + '\n')

# ---- shared prompt text ------------------------------------------------------------------------
RESOURCES = f"""RESOURCES — identical for every cell of this experiment.

1. A SQLite copy of the FRUS Explorer search index (a 553-volume index, taken 2026-10-25):
     {DB}
   Open it READ-ONLY. Either of these works on this machine:
     sqlite3 "file:{DB}?mode=ro" "SELECT ..."
     sqlite3 -readonly {DB} "SELECT ..."
   In Python: sqlite3.connect("file:{DB}?mode=ro", uri=True)
   Do NOT pass `-uri`: this sqlite3 build rejects it with "unknown option".
   Never write to it. Tables: document_cache, frus_documents (FTS5 over the corpus text),
   user_content (FTS5 over the reader's own notes/summaries), cross_references, document_dates,
   persons, person_mentions, person_rollup, person_rollup_member, document_sources,
   external_citations, document_subject_refs, document_subject_volumes, document_subjects,
   volume_sources, volume_structures, page_ranges, user_tags, terms.

2. The TEI XML corpus the index was built from, one file per volume (553 files):
     {TEI}/*.xml
   (the path has a space in it: quote it)

3. The bundled JSON reference data shipped with the app, build 1.0 (1776):
     "{RES}"/*.json
   including manifest.json (volume titles, coverage dates, publication dates, subseries),
   document-subject-index.json, volume-subject-profiles-index.json, semantic-map-index.json,
   collection-usage-index.json, external-citation-index.json, central-files-index.json,
   collection-authority.json, series-facts-index.json, lot-claimants-index.json,
   presidential-library-catalog.json, volume-sources-index.json, decimal-class-labels.json,
   subject-numeric-labels.json, provenance-flow-index.json, source-provenance-index.json,
   digitized-ranges-index.json, roll-scans-index.json, curated-lot-resolutions.json,
   curated-library-resolutions.json, person-authority-index.json, administrations.json.

CANARY — your FIRST tool call is exactly this command, and its output must be exactly
{COVERAGE}
     sqlite3 "file:{DB}?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"
Your SECOND is the read-only proof, which must FAIL with "attempt to write a readonly database":
     sqlite3 -readonly {DB} "BEGIN; CREATE TABLE zz(x); ROLLBACK;"
If either disagrees, stop and report it; do not improvise another way in.

HARD CONSTRAINTS
- Do NOT read anything under /Users/jbotts/Development/ (any folder in it), under
  /Users/jbotts/Downloads/, or under any other folder of /Users/jbotts/frus-analysis/ than your
  own run directory. Those trees hold notes, memos and kits about this corpus and about related
  questions, and reading one invalidates this run.
- No network.
- Write only inside your own run directory.

TOOLING NOTES (this machine, measured on earlier runs; not under test)
- A tool call that prints nothing for 180 seconds is killed, and a foreground call is killed at
  about 120 seconds even while printing. Chunk long scans (one call per volume or per shard),
  checkpoint to your run directory as you go, and flush (`python3 -u`). For anything longer, run it
  in the background and poll a file.
- `timeout` does not exist on macOS, and neither does `gtimeout`. Do not reach for either.
- zsh does not word-split an unquoted $VAR; pass a file of ids, or an array.
- `tee` buffers and `tee | head` SIGPIPEs the writer: poll the redirect target, not the tee.
- Python is 3.9: no backslash inside an f-string expression; `csv.field_size_limit(10**9)`.
- sqlite3 is 3.54.0. document_cache.body_text is large (about 1.8 GB over the corpus): aggregate
  in SQL, read documents 5 to 15 at a time, keep the raw text you quote from on disk.
"""

DELIVERABLE = f"""THE HISTORIAN'S DELIVERABLE — four files in your run directory, all required, written in ONE
session (there is no second round: whatever you do not write now, nobody gets).

1. memo.md — the scope memo: the scope you chose (volumes, date span, inclusion rule) and how you
   found it; what you measured, with the audit form of every number (the query, the pair, the
   counting surface, the share with its denominator); every quotation with the SELECT that
   retrieved it and its (volume_id, document_id); and a TRACE TABLE: one row per number and per
   quotation in the overview, giving the memo line it comes from. The memo is for the operator.

2. overview.md — for the historian, who commissioned the question and never opens a terminal.
   Use this skeleton:
     # <The question, as asked>
     ## The bottom line
     **1. What FRUS answers directly** — one paragraph: the finding, with the documents it rests
        on cited as the edition, and the size of the set in words.
     **2. Where FRUS points for the rest** — one paragraph: the archival series the printed
        documents came from and the ones the editors cited without printing, each named as a
        series with its record group, entry, identifier, dates and access status; and which of
        the two channels each is.
     **3. What this request cannot get from FRUS** — one paragraph: each part of the question the
        corpus does not hold, with what was searched to establish it (the terms, the volumes, the
        controls) and, where one exists, the shelf that holds it anyway.
     **Scope** — two sentences: which volumes, how many documents, what was excluded, in words.
     ## Decisions this needs from you — the definitional choices the question leaves open, each in
        one sentence with the consequence of each choice, and the inclusion rule you used meanwhile.
     ## Findings — three to six, each a heading, a paragraph, and one to three quoted documents
        cited as the edition
     ## How this was done — one paragraph a methods section would accept
     ## Read next — the collection, by name, and what the historian's additions would unlock
   Cite as the printed edition — "Foreign Relations of the United States, 1958–1960, Volume VII,
   Part 1, Document 12" — followed by the history.state.gov URL
   (https://history.state.gov/historicaldocuments/<volume_id>/<document_id>).

3. collection.fruscollection — the overview in the historian's own tool, a file the app opens.
   Scope it by the rule "every document the argument rests on, and nothing else". Order it under
   headings that follow the overview's findings, date order within each. The file carries: the
   three-part bottom line on its title page (introductionText), the run's name and date
   (authorLine), a `prose` entry under each heading saying why these documents and what thread
   they follow, a `notes` entry on each document saying what it shows (every agent-written note
   opens with an attribution line naming the run and the date), an `excerpt` for every quotation
   the overview relies on (the app checks each excerpt's text against its document, so write the
   passage exactly as retrieved), a closing `prose` block naming the threads you could not follow,
   and a `generated` block of type `archivalSources` at the end. The format, shown by this example
   (its ids and texts are placeholders; the keys and shape are the contract):
{COLLECTION_EXAMPLE}
   Rules the app does not enforce and you must: `format` is exactly "fruscollection";
   `formatVersion` 2 with `minimumReaderVersion` 1 (the file carries excerpts and notes); all six
   composition keys present; EVERY `document` and `excerpt` entry carries BOTH `volumeId` and
   `documentId` (an entry missing either imports as empty with no error); no duplicate document
   pair; every pair verified to exist in document_cache before the file is written; never a volume
   whose id ends in Ed2 beside its first edition. Save it with the `.fruscollection` extension.

4. queries.log — every shell command you ran against the resources, one per line, in the order
   you ran them. Append as you go; do not reconstruct it at the end. End it with the `ELIDED:`
   line the house rules require.

Before you finish, check two things and say in the overview that you did: every quotation in the
overview and every excerpt in the collection is one the memo verified against its document, and
every document the overview cites is in the collection.

When all four files are written, return as your entire final message the single line:
DONE {RUNS}/{{{{LABEL}}}}
"""

RUNNER = f"""You are doing one research session for a historian on a research question, using a local
installation of the FRUS Explorer research corpus (the Foreign Relations of the United States
series). Your cell label is {{{{LABEL}}}}; the label means nothing and you need not mention it.

YOUR RUN DIRECTORY (yours alone; create it; write nothing outside it):
     {RUNS}/{{{{LABEL}}}}

{RESOURCES}
HOUSE RULES — follow these throughout.

{BLOCK}
THE QUESTION
{QUESTION}

{DELIVERABLE}"""

SECTION_8_CHECK = """THE QUOTATION CHECK (the guide's rule, which the app's own excerpt check also applies): lower-case
both the quotation and the document, drop everything but [a-z0-9] from both, split the quotation at
its ellipsis marks (…, ..., [...]), and require every segment, in order at increasing offsets, as a
substring of header || dateline || source_note || body_text of the EXACT (volume_id, document_id)
cited. Segment-strict: a quotation whose segments are not all found in that row, in that order, is
a FABRICATION even if the words exist elsewhere in the corpus. A quotation found in the row but
credited in the overview to a different document, or to an edition citation (volume, part,
document number) that does not resolve to that pair, is a MIS-CITATION. Use the memo's trace table
to map each overview citation to its pair; where the memo gives none, resolve the printed citation
through manifest.json and say you did."""

SCORER = f"""You are scoring one research session's output against a fixed rubric. Be a hard, evidence-bound
marker: this is a measurement that will decide what a piece of documentation recommends, and a
generous score is worse than useless.

THE RUN DIRECTORY: {RUNS}/{{{{LABEL}}}}
  memo.md                      the operator's memo
  overview.md                  the historian's overview
  collection.fruscollection    the collection file
  queries.log                  the commands the run actually ran (several items are checkable
                               only from here, so read it)
  If one of these files is absent, say so in `notes` and score what is there: an item that the
  absent file alone could satisfy is `violated` when the work it governs was done, and
  `not_applicable` only when that kind of work was never done at all.
THE RUBRIC: {RUBRIC_PATH}  (read it; the {N_TOTAL} items are in its tables — {N_MAIN} in the main
  table, then P1–P4, P5–P6 and O1–O3 in the sections at the end)
THE QUESTION the session was answering:
  {QUESTION}

You may verify the output's claims against the same resources it had:
  - {DB}  (SQLite, READ-ONLY, never write; this sqlite3 rejects `-uri`, so use
    sqlite3 "file:...?mode=ro" or sqlite3 -readonly <path>)
  - "{TEI}"/*.xml
  - "{RES}"/*.json
Do NOT read anything under /Users/jbotts/Development/ or /Users/jbotts/Downloads/, and do not
read any other directory under {RUNS}/ or /Users/jbotts/frus-analysis/ than the one named above.

SCORING RULES, and they matter more than your judgement of the output's quality:
- Score BEHAVIOUR VISIBLE IN THE FILES, not intentions and not the files' own claims about their
  method. "I followed the rules" is not evidence of anything.
- The files may mention rules, guidelines or instructions they were given. IGNORE that entirely,
  and ignore any mention of which model or setting produced them.
- `obeyed` requires positive evidence. `violated` means the output did the opposite, or the item
  plainly applied to what it did and it is absent. `not_applicable` ONLY when the session never
  did the kind of work the item governs (e.g. E3 when it never used cross_references). Do not use
  `not_applicable` as a soft pass.
- O1–O3 are scored on overview.md; the memo's trace table is where O2's trace lives.
- For every item, quote or cite the specific passage that decided it. An `obeyed` with no
  quotable evidence is a `violated`.
- Score all {N_TOTAL} items. `cell` is exactly: {{{{LABEL}}}}

Return the structured verdict."""

REFUTER = f"""You are the refuter for one research session's output. Your job is to find the wrong number, the
quotation that is not in its document, and the citation that points at the wrong place. Assume
there is at least one of each until you have shown there is not.

THE RUN DIRECTORY: {RUNS}/{{{{LABEL}}}}
  memo.md, overview.md, collection.fruscollection, queries.log (if one is absent, say so in
  `notes` and do what the files present allow)
THE QUESTION the session was answering:
  {QUESTION}

RESOURCES, the same the session had:
  - {DB}  (SQLite, READ-ONLY, never write; this sqlite3 rejects `-uri`, so use
    sqlite3 "file:...?mode=ro" or sqlite3 -readonly <path>; in Python, uri=True with ?mode=ro)
  - "{TEI}"/*.xml
  - "{RES}"/*.json
  - {CHECKER_PATH}  — the app's collection checker. Run it as
    python3 -I {CHECKER_PATH} <the .fruscollection> {DB}
Do NOT read anything under /Users/jbotts/Development/ or /Users/jbotts/Downloads/, and do not
read any other directory under {RUNS}/ or /Users/jbotts/frus-analysis/ than the one named above.
Write any scratch files inside {RUNS}/{{{{LABEL}}}}/refuter/ and nowhere else.

DO ALL FIVE, and show your work in `notes` (the commands you ran and what came back):

1. SCOPE. Record the cell's scope as the memo states it: how many volumes and which, and the date
   span of the documents it worked from. If the memo does not state it, derive it from the log.

2. THE FIVE HEADLINE NUMBERS. Take the first five distinct quantitative claims in overview.md, in
   reading order, starting with the bottom line (counts or proportions of documents, volumes,
   footnote pointers, archival units; not dates, not document numbers, not volume numbers). For
   each, find its memo line through the trace table, run the memo's or the log's SQL yourself,
   and say whether the overview's figure (rounded as the overview rounds it) is reproduced. A
   number with no memo line, or whose query you cannot run, is NOT reproduced. If the overview
   holds fewer than five numbers, say so and set numbersTotal to the count it holds.

3. EVERY QUOTATION. List every passage inside quotation marks or set as a block quote in
   overview.md, and every `excerpt` in the collection. Apply the check below to each, against
   the exact pair the memo's trace gives. Count fabrications and mis-citations separately and
   name each one.

{SECTION_8_CHECK}

4. THE ARCHIVAL IDENTIFIERS. For every NARA identifier (NAID), record group and entry, lot number
   or presidential-library collection the bottom line's second paragraph names, confirm it against
   the bundled artifacts (collection-authority.json, central-files-index.json,
   volume-sources-index.json, presidential-library-catalog.json, external-citation-index.json,
   series-facts-index.json) or the index's document_sources / external_citations rows. Count the
   identifiers checked and the ones confirmed.

5. THE DELIVERABLE. Run the checker on the collection and paste its output. Count the entries by
   kind (document, heading, prose, excerpt, generated) and the documents carrying `notes`. Then
   list every document the overview cites (resolve printed citations to pairs through the memo's
   trace or manifest.json) and say how many of them are in the collection and which are not.

`cell` is exactly: {{{{LABEL}}}}. Return the structured refutation."""

JUDGE = f"""You are the reader judge. You read ONLY two files and judge whether they serve a historian who
commissioned the question and will never open a terminal. Do not open memo.md or queries.log; do
not run queries; do not read anything outside the two files named here and the earlier overviews
listed below. Ignore any mention of which model or setting produced a file.

THE FILES:
  {RUNS}/{{{{LABEL}}}}/overview.md
  {RUNS}/{{{{LABEL}}}}/collection.fruscollection   (read it as text: its title page, headings,
                                                   prose, notes and excerpts are part of what the
                                                   historian receives)
  If one is absent, say so in the evidence of every item it affects and judge what is there.
THE QUESTION:
  {QUESTION}

FIVE ITEMS, each yes or no, each with the passage that decided it:
  J1  The overview opens with the three-part bottom line, in this order and before any finding:
      what FRUS answers directly; where FRUS points for the rest; what this request cannot get
      from FRUS.
  J2  Every number in the overview is given as a count of a named set in words ("about one
      document in seven among the 43 volumes indexed"), never as a bare percentage or a figure
      with no base; "no" if any number fails this.
  J3  Every document the overview cites is cited as the printed edition (Foreign Relations of the
      United States, years, volume, part, document number) with a history.state.gov link; "no"
      if any is cited by a bare id pair or by title alone.
  J4  What the request cannot get from FRUS is stated as a search that was run — its terms, the
      volumes, and the controls that make the zero a measurement — not as an assertion.
  J5  The overview contains no SQL, no table or column name, no volume_id/document_id string
      (such as frus1961-63v12/d45) and no file path.

THEN A RANKING. Overviews already judged in this experiment:
{{{{PREVIOUS}}}}
Read each one you have not been given before as well, then rank ALL of them together with this
cell's, best to worst for the historian, by label, with a one-line reason. If there are none, the
ranking is this cell alone.

`cell` is exactly: {{{{LABEL}}}}. Return the structured judgement."""

# ---- schemas -----------------------------------------------------------------------------------
VERDICT = {
    'type': 'object',
    'properties': {
        'cell': {'type': 'string'},
        'items': {'type': 'array', 'items': {'type': 'object', 'properties': {
            'id': {'type': 'string'}, 'block': {'type': 'string'},
            'verdict': {'type': 'string', 'enum': ['obeyed', 'violated', 'not_applicable']},
            'evidence': {'type': 'string'}}, 'required': ['id', 'block', 'verdict', 'evidence']}},
        'obeyed': {'type': 'integer'}, 'violated': {'type': 'integer'}, 'notApplicable': {'type': 'integer'},
        'notes': {'type': 'string'}},
    'required': ['cell', 'items', 'obeyed', 'violated', 'notApplicable', 'notes']}
REFUTATION = {
    'type': 'object',
    'properties': {
        'cell': {'type': 'string'},
        'scope': {'type': 'object', 'properties': {
            'volumes': {'type': 'integer'}, 'volumeIds': {'type': 'string'}, 'dateSpan': {'type': 'string'},
            'source': {'type': 'string'}}, 'required': ['volumes', 'volumeIds', 'dateSpan', 'source']},
        'headline': {'type': 'array', 'items': {'type': 'object', 'properties': {
            'claim': {'type': 'string'}, 'memoLine': {'type': 'string'}, 'reproduced': {'type': 'boolean'},
            'note': {'type': 'string'}}, 'required': ['claim', 'memoLine', 'reproduced', 'note']}},
        'numbersReproduced': {'type': 'integer'}, 'numbersTotal': {'type': 'integer'},
        'quotationsTotal': {'type': 'integer'}, 'quotationsVerified': {'type': 'integer'},
        'fabrications': {'type': 'integer'}, 'fabricationDetails': {'type': 'string'},
        'miscitations': {'type': 'integer'}, 'miscitationDetails': {'type': 'string'},
        'identifiersChecked': {'type': 'integer'}, 'identifiersConfirmed': {'type': 'integer'},
        'identifierDetails': {'type': 'string'},
        'collection': {'type': 'object', 'properties': {
            'opens': {'type': 'boolean'}, 'checkerOutput': {'type': 'string'},
            'documents': {'type': 'integer'}, 'headings': {'type': 'integer'}, 'prose': {'type': 'integer'},
            'excerpts': {'type': 'integer'}, 'generated': {'type': 'integer'}, 'documentsWithNotes': {'type': 'integer'},
            'citedInOverview': {'type': 'integer'}, 'citedAndPresent': {'type': 'integer'},
            'citedMissing': {'type': 'string'}},
            'required': ['opens', 'checkerOutput', 'documents', 'headings', 'prose', 'excerpts', 'generated',
                         'documentsWithNotes', 'citedInOverview', 'citedAndPresent', 'citedMissing']},
        'notes': {'type': 'string'}},
    'required': ['cell', 'scope', 'headline', 'numbersReproduced', 'numbersTotal', 'quotationsTotal',
                 'quotationsVerified', 'fabrications', 'fabricationDetails', 'miscitations', 'miscitationDetails',
                 'identifiersChecked', 'identifiersConfirmed', 'identifierDetails', 'collection', 'notes']}
READER = {
    'type': 'object',
    'properties': {
        'cell': {'type': 'string'},
        'items': {'type': 'array', 'items': {'type': 'object', 'properties': {
            'id': {'type': 'string'}, 'verdict': {'type': 'string', 'enum': ['yes', 'no']},
            'evidence': {'type': 'string'}}, 'required': ['id', 'verdict', 'evidence']}},
        'yes': {'type': 'integer'},
        'ranking': {'type': 'array', 'items': {'type': 'string'}},
        'rankingReason': {'type': 'string'}},
    'required': ['cell', 'items', 'yes', 'ranking', 'rankingReason']}

# ---- the script --------------------------------------------------------------------------------
J = lambda x: json.dumps(x, ensure_ascii=False)
script = f"""export const meta = {{
  name: 'c3-reader-test',
  description: 'C-3: the reader-facing block section under 9 model x effort cells, one question; each cell scored, refuted and judged on Fable at max.',
  phases: [{{ title: 'Run' }}, {{ title: 'Score' }}, {{ title: 'Refute' }}, {{ title: 'Judge' }}],
}}
// Generated by /Users/jbotts/frus-analysis/c3/generate.py from the guide at v1.33 (f0479037).
// args: {{ cells: [{{label, model, effort, skipRun?}}], previous: [labels already judged] }}

const RUNNER = {J(RUNNER)}
const SCORER = {J(SCORER)}
const REFUTER = {J(REFUTER)}
const JUDGE = {J(JUDGE)}
const RUNS = {J(RUNS)}
const VERDICT = {J(VERDICT)}
const REFUTATION = {J(REFUTATION)}
const READER = {J(READER)}

const fill = (t, label) => t.split('{{{{LABEL}}}}').join(label)
const previousList = (labels) => labels.length
  ? labels.map(l => '  ' + RUNS + '/' + l + '/overview.md').join('\\n')
  : '  (none yet)'
const safe = async (f) => {{ try {{ return await f() }} catch (e) {{ return {{ error: String(e) }} }} }}

const cells = args.cells
const previous = (args.previous || []).slice()
log('C-3: ' + cells.map(c => c.label).join(', ') + '; previously judged: ' + (previous.join(', ') || 'none'))

const results = []
for (const c of cells) {{
  let run = 'SKIPPED'
  if (!c.skipRun) {{
    run = await safe(() => agent(fill(RUNNER, c.label), {{ label: 'run:' + c.label, phase: 'Run', model: c.model, effort: c.effort }}))
  }}
  log('cell ' + c.label + ' run: ' + String(run).slice(0, 120))
  const [score, refute, judge] = await parallel([
    () => safe(() => agent(fill(SCORER, c.label), {{ label: 'score:' + c.label, phase: 'Score', model: 'claude-fable-5-1', effort: 'max', schema: VERDICT }})),
    () => safe(() => agent(fill(REFUTER, c.label), {{ label: 'refute:' + c.label, phase: 'Refute', model: 'claude-fable-5-1', effort: 'max', schema: REFUTATION }})),
    () => safe(() => agent(fill(JUDGE, c.label).split('{{{{PREVIOUS}}}}').join(previousList(previous)), {{ label: 'judge:' + c.label, phase: 'Judge', model: 'claude-fable-5-1', effort: 'max', schema: READER }})),
  ])
  previous.push(c.label)
  results.push({{ label: c.label, run, score, refute, judge }})
}}
return {{ cells: results }}
"""
(OUT / 'workflow.mjs').write_text(script)

# ---- rendered prompts and the verification print (runbook §8) ----------------------------------
for name, t in [('runner', RUNNER), ('scorer', SCORER), ('refuter', REFUTER), ('judge', JUDGE)]:
    (OUT / 'prompts' / f'{name}.txt').write_text(t.replace('{{LABEL}}', 'rN').replace('{{PREVIOUS}}', '  (none yet)'))
sha = hashlib.sha256(BLOCK.encode()).hexdigest()[:16]
print(f'block: {BLOCK.count(chr(10))} lines, sha256 {sha}, reader-facing section present')
print(f'coverage (canary): {COVERAGE}')
for name, t in [('runner', RUNNER), ('scorer', SCORER), ('refuter', REFUTER), ('judge', JUDGE)]:
    bad = [l for l in t.splitlines() if '-uri' in l and 'Do NOT pass' not in l and 'rejects' not in l]
    print(f'{name}: {len(t)} chars; -uri outside its warning: {bad or "none"}')
print('keymap:', {k: v['label'] for k, v in keymap.items()})
print('rubric rows:', sum(1 for l in rubric.splitlines() if re.match(r'\| [A-Z]\d ', l)))
print('script:', len(script), 'chars ->', OUT / 'workflow.mjs')
