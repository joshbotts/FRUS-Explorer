#!/usr/bin/env python3
"""C-3 vectors tier generator: C-3's generator with three additions (design §2), all cut from the
files by marker, nothing transcribed: Appendix A whole; the vector artifacts as RESOURCES item 4;
a VECTORS section in the memo. The rubric gains V1–V6 (design §4); the refuter gains the vector-use
and reach checks (design §3); the judge ranks this tier's overviews alone (decision 3).

The question is read from question.txt beside this file (decision 3: the owner's second question).
Writes workflow.mjs, canary.mjs, RUBRIC.md, keymap.json, prompts/ and check_collection.py."""
import hashlib, json, random, re, sys, pathlib

REPO = pathlib.Path('/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/c3-cloud-sessions-95c770')
GUIDE = REPO / 'Docs/Agentic-Analysis-Guide.md'
C3 = pathlib.Path('/Users/jbotts/frus-analysis/c3')
OUT = pathlib.Path('/Users/jbotts/frus-analysis/c3v')
DB = '/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db'
TEI = '/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes'
RES = '/Applications/FRUS Explorer.app/Contents/Resources'
SHARDS = '/Users/jbotts/frus-analysis/c3/SemanticVectors'
RUNS = '/Users/jbotts/frus-analysis/c3v/runs'
RUBRIC_PATH = str(OUT / 'RUBRIC.md')
CHECKER_PATH = str(OUT / 'check_collection.py')
COVERAGE = (C3 / 'coverage.txt').read_text().strip()

qfile = OUT / 'question.txt'
QUESTION = qfile.read_text().strip() if qfile.exists() else ''
if not QUESTION:
    print('WARNING: question.txt is empty or missing; the runner prompt carries {{QUESTION}} until it is filled', file=sys.stderr)
    QUESTION = '{{QUESTION}}'

guide = GUIDE.read_text()

# ---- the §12 block, fence to fence (as C-3) -----------------------------------------------------
i = guide.index('\n## 12. A house-rules block to paste into your agent')
j = guide.index('```text\n', i) + len('```text\n')
k = guide.index('\n```\n', j)
BLOCK = guide[j:k].rstrip('\n') + '\n'
assert 'READER-FACING OUTPUT' in BLOCK

# ---- Appendix A, heading to the Glossary ----------------------------------------------------------
a = guide.index('\n## Appendix A: The semantic vector artifacts')
g = guide.index('\n## Glossary', a)
APPENDIX = guide[a:g].strip('\n').rstrip('-').rstrip('\n') + '\n'
assert '### A.5 What an agent can do with no model' in APPENDIX and '### A.8 What the vectors cannot tell you' in APPENDIX
APPENDIX_LINES = APPENDIX.count('\n')

# ---- §15.1a example and §15.2 checker (as C-3) ---------------------------------------------------
a = guide.index('### 15.1a The findings in the file'); b = guide.index('```json\n', a) + 8; c = guide.index('\n```\n', b)
COLLECTION_EXAMPLE = guide[b:c].strip('\n'); json.loads(COLLECTION_EXAMPLE)
a = guide.index('### 15.2 One constraint the app does not enforce'); b = guide.index('```python\n', a) + 10; c = guide.index('\n```\n', b)
pathlib.Path(CHECKER_PATH).write_text(guide[b:c].strip('\n') + '\n')

# ---- the rubric: C-3's file whole, plus V1–V6 ------------------------------------------------------
rubric = (C3 / 'RUBRIC.md').read_text().rstrip('\n') + '\n\n'
V_ROWS = """| id | block | item | `obeyed` requires |
|---|---|---|---|
| V1 | VECTORS | Checked the provenance pin before using any vector: the index's `provenanceDigest` against the shards manifest's and the shard folder's `.generation`, and said so (§A.2, "the one family rule"). | The digests named as equal, or a refusal to use a shard that disagreed. |
| V2 | VECTORS | Took document identity from the index's run-length segments (§A.3) and never from a shard's position in the XML or `d{ordinal+1}`. | A decode shown, and a spot check of at least one known pair (`frus1861/d111` is row-addressable). |
| V3 | VECTORS | Calibrated before reading any Hamming distance, against both baselines (§A.5): random pairs and the k-th-neighbour distribution, recomputed on this digest. | Both figures reported before the first neighbour is interpreted. A neighbour called "close" with neither is `violated`. |
| V4 | VECTORS | Suppressed edition twins on every neighbour surface (the Ed2 volumes, cosine 1.0 to their first editions). | The suppression stated and visible in the lists, or no Ed2 volume in any list. |
| V5 | VECTORS | Reported any cluster-based figure with the set's unclustered share against an era-matched baseline, never the corpus figure alone (§A.5, §A.8). | The share and its baseline, or no cluster figure. |
| V6 | VECTORS | Gave every cosine the reader sees through the index's `scoreCalibration` offsets, or as a raw cosine labelled raw (§A.7's last paragraph). | The offset named, or the word raw. |"""
rubric += ('## ADDED FOR THE VECTORS TIER — V1–V6, Appendix A\'s own rules made scoreable\n\n'
           'Design: `Planning/C-3-Vectors-Tier-Design.md` §4. Same verdict vocabulary. **A run that used no\n'
           'vector artifact scores V1–V6 `not_applicable`**, all six; that is a finding about the appendix as a\n'
           'front door, not a soft pass.\n\n' + V_ROWS + '\n\n')
N_TOTAL = len(re.findall(r'^\| [A-Z]\d \|', rubric, re.M)); N_MAIN = N_TOTAL - 15
assert N_TOTAL == 41 and N_MAIN == 26, (N_TOTAL, N_MAIN)
rubric += f'**{N_TOTAL} items in all**: the {N_MAIN} of the main table, P1–P4, P5–P6, O1–O3, and V1–V6.\n'
pathlib.Path(RUBRIC_PATH).write_text(rubric)

# ---- the cells and their opaque labels --------------------------------------------------------------
CELLS = [('O-med+V (1)', 'claude-opus-5-5', 'medium'), ('S-high+V (1)', 'claude-sonnet-5-5', 'high'),
         ('O-med+V (2)', 'claude-opus-5-5', 'medium'), ('S-high+V (2)', 'claude-sonnet-5-5', 'high')]
rng = random.Random(20261026)
labels = ['v1', 'v2', 'v3', 'v4']; rng.shuffle(labels)
keymap = {cell: {'label': lab, 'model': m, 'effort': e} for (cell, m, e), lab in zip(CELLS, labels)}
keymap['calv'] = {'label': 'calv', 'model': None, 'effort': None,
                  'note': "calibration of V1–V6: C-3's r5 (S-high, first run, no vectors) scored with the extended rubric; V1–V6 must all be not_applicable"}
(OUT / 'keymap.json').write_text(json.dumps(keymap, indent=2) + '\n')

# ---- shared prompt text ---------------------------------------------------------------------------------
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

4. The app's semantic vector artifacts, which Appendix A below describes, read-only:
     "{RES}/semantic-vectors-index.json"     identity (run-length-encoded ids), provenance, calibration
     "{RES}/semantic-vectors-binary.bin"     Tier 1: 314,616 sign vectors of 512 bits, then 660 centroids
     "{RES}/semantic-map.bin"                the 2-D map placements
     "{RES}/semantic-map-index.json"         the map's cluster labels and era histograms
     "{RES}/semantic-shards-manifest.json"   one row per Tier-2 shard, with its SHA-256
     {SHARDS}/<volume>.vec          Tier 2: 553 int8 shards, one per volume (a copy of the
                                              app's own folder; its .generation file holds the digest)
   No embedder is available in this session: there is no way to turn words into a query vector,
   so the vectors answer document-to-document questions only (Appendix A §A.5), never a free-text one.

CANARY — your FIRST tool call is exactly this command, and its output must be exactly
{COVERAGE}
     sqlite3 "file:{DB}?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"
Your SECOND is the read-only proof, which must FAIL with "attempt to write a readonly database":
     sqlite3 -readonly {DB} "BEGIN; CREATE TABLE zz(x); ROLLBACK;"
If either disagrees, stop and report it; do not improvise another way in.

HARD CONSTRAINTS
- Do NOT read anything under /Users/jbotts/Development/ (any folder in it), under
  /Users/jbotts/Downloads/, or under any other folder of /Users/jbotts/frus-analysis/ than your
  own run directory and the SemanticVectors folder named above. Those trees hold notes, memos and
  kits about this corpus and about related questions, and reading one invalidates this run.
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
- Python 3.9 has no `int.bit_count()` (it arrived in 3.10), so Appendix A's §A.5 loop fails as
  printed; `bin(x).count("1")` is the 3.9 form. A full Hamming scan of the 314,616 sign rows in
  pure Python with it takes a few seconds; numpy is not installed.
"""

c3_runner = (C3 / 'prompts' / 'runner.txt').read_text()
DELIV_START = c3_runner.index("THE HISTORIAN'S DELIVERABLE")
DELIVERABLE = c3_runner[DELIV_START:].replace('/Users/jbotts/frus-analysis/c3/runs/rN', RUNS + '/{{LABEL}}')
DELIVERABLE = DELIVERABLE.replace(
    "   retrieved it and its (volume_id, document_id); and a TRACE TABLE:",
    "   retrieved it and its (volume_id, document_id); a section headed VECTORS that names each of\n"
    "   Appendix A's operations you ran (nearest neighbours of a document, a semantic join, centroid\n"
    "   similarity, the map, near-duplicates), each with its anchor, the file it ran over, the baseline\n"
    "   it was read against and what it found, or the single word \"none\" if you ran none, and says\n"
    "   which documents in the overview you reached through a vector operation and through no\n"
    "   full-text query; and a TRACE TABLE:")
assert 'headed VECTORS' in DELIVERABLE, 'the VECTORS sentence did not land in the deliverable'

RUNNER = f"""You are doing one research session for a historian on a research question, using a local
installation of the FRUS Explorer research corpus (the Foreign Relations of the United States
series). Your cell label is {{{{LABEL}}}}; the label means nothing and you need not mention it.

YOUR RUN DIRECTORY (yours alone; create it; write nothing outside it):
     {RUNS}/{{{{LABEL}}}}

{RESOURCES}
HOUSE RULES — follow these throughout.

{BLOCK}
APPENDIX A OF THE GUIDE — the semantic vector artifacts named in RESOURCES item 4: what they are,
how to read them, what an agent can do with them and what they cannot tell you. Reference, not a
second rule block; its closing addendum is written for the house rules above.

{APPENDIX}
THE QUESTION
{QUESTION}

{DELIVERABLE}"""

def relabel(text):
    """C-3's rendered prompts carry the sample label rN; put the template placeholder back."""
    return re.sub(r'\brN\b', '{{LABEL}}', text.replace('/Users/jbotts/frus-analysis/c3/runs/rN', RUNS + '/{{LABEL}}'))
c3_scorer = relabel((C3 / 'prompts' / 'scorer.txt').read_text())
SCORER = (c3_scorer.replace('/Users/jbotts/frus-analysis/c3/RUBRIC.md', RUBRIC_PATH)
          .replace('the 35 items are in its tables — 26 in the main\n  table, then P1–P4, P5–P6 and O1–O3 in the sections at the end',
                   'the 41 items are in its tables — 26 in the main\n  table, then P1–P4, P5–P6, O1–O3 and V1–V6 in the sections at the end')
          .replace('- Score all 35 items.', '- V1–V6 are scored on what the files show of vector work; a session that opened no vector\n  artifact (check the log and the scripts) scores all six `not_applicable`, and that is the\n  correct verdict, not a soft pass.\n- Score all 41 items.')
          .replace('do not\nread any other directory under /Users/jbotts/frus-analysis/c3/runs/ or /Users/jbotts/frus-analysis/ than the one named above.',
                   'do not\nread any other directory under /Users/jbotts/frus-analysis/ than the one named above and the vector\nartifacts (the bundle files and /Users/jbotts/frus-analysis/c3/SemanticVectors/).')
          .replace('  - "/Applications/FRUS Explorer.app/Contents/Resources/"*.json',
                   '  - "/Applications/FRUS Explorer.app/Contents/Resources/"*.json, and the vector artifacts there\n    (semantic-vectors-index.json, semantic-vectors-binary.bin, semantic-map.bin, semantic-map-index.json,\n    semantic-shards-manifest.json) with the Tier-2 shards at /Users/jbotts/frus-analysis/c3/SemanticVectors/'))
assert '41 items' in SCORER and 'V1–V6 are scored' in SCORER and 'THE QUESTION the session was answering' in SCORER
SCORER = re.sub(r'(THE QUESTION the session was answering:\n  ).*', lambda m: m.group(1) + QUESTION, SCORER, count=1)

c3_refuter = relabel((C3 / 'prompts' / 'refuter.txt').read_text())
REFUTER = (c3_refuter.replace('/Users/jbotts/frus-analysis/c3/check_collection.py', CHECKER_PATH)
           .replace('do not\nread any other directory under /Users/jbotts/frus-analysis/c3/runs/ or /Users/jbotts/frus-analysis/ than the one named above.',
                    'do not\nread any other directory under /Users/jbotts/frus-analysis/ than the one named above and the vector\nartifacts (the bundle files and /Users/jbotts/frus-analysis/c3/SemanticVectors/).')
           .replace('  - "/Applications/FRUS Explorer.app/Contents/Resources/"*.json',
                    '  - "/Applications/FRUS Explorer.app/Contents/Resources/"*.json, and the vector artifacts there\n    (semantic-vectors-index.json, semantic-vectors-binary.bin, semantic-map.bin, semantic-map-index.json,\n    semantic-shards-manifest.json) with the Tier-2 shards at /Users/jbotts/frus-analysis/c3/SemanticVectors/')
           .replace('DO ALL FIVE, and show your work', 'DO ALL SEVEN, and show your work'))
REFUTER = re.sub(r'(THE QUESTION the session was answering:\n  ).*', lambda m: m.group(1) + QUESTION, REFUTER, count=1)
REFUTER = REFUTER.replace('`cell` is exactly: {{LABEL}}. Return the structured refutation.', f"""6. VECTOR USE. From the memo's VECTORS section, the log and the scripts, record which of Appendix
   A's operations the session ran (nearest neighbours of a document, semantic join, centroid
   similarity, the map, near-duplicates), each with its anchor and the file it ran over (the
   bundle's binary, a shard, the map); whether the three provenance digests were compared; and
   whether any distance was read against a baseline. Re-run one neighbour list the session
   reports, if it reports any, from the bundle's binary with §A.3's decode, and say whether it
   reproduces. A session that ran none records "none" and the rest of this step is empty.

7. REACH. For every document the overview cites (the pairs of step 5), decide whether at least one
   full-text or chapter-heading query the session logged returns it: re-run the log's MATCH,
   LIKE and heading queries, or the memo's scope set, and test membership. A cited document
   returned by none of them and shown in the memo or the log as found through a neighbour list, a
   cluster or a centroid is VECTOR-REACHED; one returned by none and traceable to neither is
   UNTRACED. Count the cited documents, the vector-reached ones, and among those the ones the
   overview quotes from; list the vector-reached pairs.

`cell` is exactly: {{{{LABEL}}}}. Return the structured refutation.""")
assert '6. VECTOR USE' in REFUTER and '7. REACH' in REFUTER

c3_judge = relabel((C3 / 'prompts' / 'judge.txt').read_text())
JUDGE = re.sub(r'(THE QUESTION:\n  ).*', lambda m: m.group(1) + QUESTION, c3_judge, count=1)
JUDGE = JUDGE.replace('  (none yet)', '{{PREVIOUS}}')
assert '{{PREVIOUS}}' in JUDGE and QUESTION in JUDGE

# ---- schemas: C-3's, the refutation extended ----------------------------------------------------------
c3_script = (C3 / 'workflow.mjs').read_text()
def const(name):
    m = re.search(r'^const ' + name + r' = (.*)$', c3_script, re.M)
    return json.loads(m.group(1))
VERDICT, READER = const('VERDICT'), const('READER')
REFUTATION = const('REFUTATION')
REFUTATION['properties']['vectorUse'] = {'type': 'object', 'properties': {
    'operations': {'type': 'array', 'items': {'type': 'string'}}, 'anchors': {'type': 'string'}, 'files': {'type': 'string'},
    'digestsCompared': {'type': 'boolean'}, 'baselinesUsed': {'type': 'string'},
    'neighbourListReproduced': {'type': 'string'}, 'notes': {'type': 'string'}},
    'required': ['operations', 'anchors', 'files', 'digestsCompared', 'baselinesUsed', 'neighbourListReproduced', 'notes']}
REFUTATION['properties']['reach'] = {'type': 'object', 'properties': {
    'citedDocuments': {'type': 'integer'}, 'ftsReached': {'type': 'integer'}, 'vectorReached': {'type': 'integer'},
    'vectorReachedQuoted': {'type': 'integer'}, 'untraced': {'type': 'integer'},
    'vectorReachedPairs': {'type': 'string'}, 'method': {'type': 'string'}},
    'required': ['citedDocuments', 'ftsReached', 'vectorReached', 'vectorReachedQuoted', 'untraced', 'vectorReachedPairs', 'method']}
REFUTATION['required'] += ['vectorUse', 'reach']

# ---- the scripts ---------------------------------------------------------------------------------------------
J = lambda x: json.dumps(x, ensure_ascii=False)
script = f"""export const meta = {{
  name: 'c3-vectors-tier',
  description: 'C-3 vectors tier: Sonnet 5.5 at high and Opus 5.5 at medium with Appendix A and the vector artifacts, two runs each; scored, refuted and judged on Fable at max.',
  phases: [{{ title: 'Run' }}, {{ title: 'Score' }}, {{ title: 'Refute' }}, {{ title: 'Judge' }}],
}}
// Generated by /Users/jbotts/frus-analysis/c3v/generate_v.py from the guide at v1.34; the design is Planning/C-3-Vectors-Tier-Design.md.
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
log('C-3 vectors tier: ' + cells.map(c => c.label).join(', ') + '; previously judged: ' + (previous.join(', ') || 'none'))

const results = []
for (const c of cells) {{
  let run = 'SKIPPED'
  if (!c.skipRun) {{
    run = await safe(() => agent(fill(RUNNER, c.label), {{ label: 'run:' + c.label, phase: 'Run', model: c.model, effort: c.effort }}))
  }}
  log('cell ' + c.label + ' run: ' + String(run).slice(0, 120))
  const instruments = [
    () => safe(() => agent(fill(SCORER, c.label), {{ label: 'score:' + c.label, phase: 'Score', model: 'claude-fable-5-1', effort: 'max', schema: VERDICT }})),
  ]
  if (!c.scoreOnly) {{
    instruments.push(() => safe(() => agent(fill(REFUTER, c.label), {{ label: 'refute:' + c.label, phase: 'Refute', model: 'claude-fable-5-1', effort: 'max', schema: REFUTATION }})))
    instruments.push(() => safe(() => agent(fill(JUDGE, c.label).split('{{{{PREVIOUS}}}}').join(previousList(previous)), {{ label: 'judge:' + c.label, phase: 'Judge', model: 'claude-fable-5-1', effort: 'max', schema: READER }})))
  }}
  const [score, refute, judge] = await parallel(instruments)
  if (!c.scoreOnly) previous.push(c.label)
  results.push({{ label: c.label, run, score, refute: refute || null, judge: judge || null }})
}}
return {{ cells: results }}
"""
(OUT / 'workflow.mjs').write_text(script)

CANARY_TASK = f"""THE TASK — this is the environment proof, not a research session. Do exactly these, in order,
and nothing else. Write your run directory as {RUNS}/canary.
1. The CANARY command above. Paste its output.
2. The read-only proof above. Paste the error.
3. Read semantic-vectors-index.json, semantic-shards-manifest.json and {SHARDS}/.generation and print
   the three provenance digests; then read the first 64 bytes of semantic-vectors-binary.bin and
   print its magic, version, dims, document count, centroid count and the digest at offset 20.
4. Decode every volume's ids with §A.3's `decode_segments` (the appendix below gives it) and print
   how many of the 553 volumes decode to exactly their `n`, and the row of frus1861/d111.
5. Print the ten nearest neighbours of frus1861/d111 by Hamming distance over the sign rows of
   semantic-vectors-binary.bin (§A.5's loop), as `hamming N volume/document`, nearest first.
6. Read {SHARDS}/frus1861.vec: print its magic, dims, document count and the digest at offset 16,
   and whether its SHA-256 and size match the manifest's row for frus1861.
7. Write all of it to canary.txt in your run directory, and the commands to queries.log.
Then return as your entire final message one line: DONE, the three digests' first 8 characters,
the volume count that decoded, and the ten neighbours.

{APPENDIX}"""
canary_prompt = RESOURCES.replace('{{LABEL}}', 'canary') + '\n' + CANARY_TASK
canary = f"""export const meta = {{
  name: 'c3-vectors-canary',
  description: 'C-3 vectors tier environment proof: one agent at the O-med pin reads the artifacts, decodes the ids and reproduces Appendix A\\'s neighbour list.',
  phases: [{{ title: 'Canary' }}],
}}
const PROMPT = {J(canary_prompt)}
log('C-3 vectors canary: opus at medium, the O-med pin, on the exact RESOURCES text plus Appendix A')
const out = await agent(PROMPT, {{ label: 'canary', phase: 'Canary', model: 'claude-opus-5-5', effort: 'medium' }})
return {{ canary: out }}
"""
(OUT / 'canary.mjs').write_text(canary)

for name, t in [('runner', RUNNER), ('scorer', SCORER), ('refuter', REFUTER), ('judge', JUDGE), ('canary', canary_prompt)]:
    (OUT / 'prompts' / f'{name}.txt').write_text(t.replace('{{LABEL}}', 'vN').replace('{{PREVIOUS}}', '  (none yet)'))
print(f'block: {BLOCK.count(chr(10))} lines; appendix: {APPENDIX_LINES} lines, {len(APPENDIX):,} chars, sha256 {hashlib.sha256(APPENDIX.encode()).hexdigest()[:16]}')
print(f'question: {QUESTION[:100]!r}')
for name, t in [('runner', RUNNER), ('scorer', SCORER), ('refuter', REFUTER), ('judge', JUDGE), ('canary', canary_prompt)]:
    bad = [l for l in t.splitlines() if '-uri' in l and 'Do NOT pass' not in l and 'rejects' not in l]
    print(f'{name}: {len(t):,} chars; -uri outside its warning: {bad or "none"}')
print('keymap:', {k: v['label'] for k, v in keymap.items()})
print('rubric items:', N_TOTAL, '; script', len(script), 'chars; canary', len(canary), 'chars')
