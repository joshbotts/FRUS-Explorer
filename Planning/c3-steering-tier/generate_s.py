#!/usr/bin/env python3
"""C-3 steering tier (R16) generator. Design: Planning/C-3-Steering-Tier-Design.md.

Two arms and a ninth run, every guide text cut by marker from a pinned commit, nothing transcribed:
  A   the guide as it stands (v1.37 at A_COMMIT): the §12 block with §A.8's addendum pasted at its
      end, Appendix A whole, the vectors tier's RESOURCES and its five-operation VECTORS sentence;
  B   the v1.38 candidate (B_COMMIT, branch claude/c3-steering-arm-b): its §12 block, §A.9's card,
      the guide copy as RESOURCES item 5, and R1/R3's VECTORS sentence;
  B0  B with no artifacts: RESOURCES items 1-3, B's block and deliverable, no card.
The instruments are the vectors tier's, the refuter's reach step in both readings with V7, and the
rubric the vectors tier's 41 items plus V8, O4 and O2' (V7 is the refuter's).

Writes workflow.mjs, canary.mjs, RUBRIC.md, check_collection.py, keymap.json, prompts/, pins.json."""
import hashlib, json, random, re, subprocess, sys, pathlib

REPO = '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/agentic-analysis-guide-revisions-8b3e52'
A_COMMIT = '4fbf75f1'
B_COMMIT = 'claude/c3-steering-arm-b'
C3 = pathlib.Path('/Users/jbotts/frus-analysis/c3')
C3V = pathlib.Path('/Users/jbotts/frus-analysis/c3v')
OUT = pathlib.Path('/Users/jbotts/frus-analysis/c3s')
DB = '/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db'
TEI = '/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes'
RES = '/Applications/FRUS Explorer.app/Contents/Resources'
SHARDS = '/Users/jbotts/frus-analysis/c3/SemanticVectors'
RUNS = '/Users/jbotts/frus-analysis/c3s/runs'
GUIDE_COPY = '/Users/jbotts/frus-analysis/c3s/guide/Agentic-Analysis-Guide.md'
RUBRIC_PATH = str(OUT / 'RUBRIC.md')
CHECKER_PATH = str(OUT / 'check_collection.py')
COVERAGE = (C3 / 'coverage.txt').read_text().strip()
QUESTION = (OUT / 'question.txt').read_text().strip()
assert QUESTION.startswith('How has corruption'), QUESTION

def show(rev):
    return subprocess.run(['git', '-C', REPO, 'show', f'{rev}:Docs/Agentic-Analysis-Guide.md'],
                          capture_output=True, text=True, check=True).stdout
def rev_of(rev):
    return subprocess.run(['git', '-C', REPO, 'rev-parse', rev], capture_output=True, text=True, check=True).stdout.strip()
guide_a, guide_b = show(A_COMMIT), show(B_COMMIT)
assert pathlib.Path(GUIDE_COPY).read_text() == guide_b, 'the guide copy B reads is not the B commit'
sha = lambda t: hashlib.sha256(t.encode()).hexdigest()

def block_of(g):
    i = g.index('\n## 12. A house-rules block to paste into your agent')
    j = g.index('```text\n', i) + len('```text\n')
    k = g.index('\n```\n', j)
    return g[j:k].rstrip('\n') + '\n'

# ---- arm A: the block, the addendum pasted at its end, Appendix A whole --------------------------
BLOCK_A = block_of(guide_a)
assert 'READER-FACING OUTPUT' in BLOCK_A and 'SEMANTIC VECTORS —' not in BLOCK_A
a = guide_a.index('A short addendum for the §12 house-rules block')
b = guide_a.index('```text\n', a) + len('```text\n')
c = guide_a.index('\n```\n', b)
ADDENDUM = guide_a[b:c].rstrip('\n') + '\n'
assert ADDENDUM.startswith('SEMANTIC VECTORS\n') and 'scoreCalibration' in ADDENDUM
HOUSE_A = BLOCK_A + '\n' + ADDENDUM
a = guide_a.index('\n## Appendix A: The semantic vector artifacts')
g = guide_a.index('\n## Glossary', a)
APPENDIX = guide_a[a:g].strip('\n').rstrip('-').rstrip('\n') + '\n'
assert '### A.5 What an agent can do with no model' in APPENDIX and '### A.9' not in APPENDIX

# ---- arm B: the candidate's block and its card ----------------------------------------------------
BLOCK_B = block_of(guide_b)
assert 'SEMANTIC VECTORS —' in BLOCK_B and 'Centroid similarity' not in BLOCK_B
a = guide_b.index('### A.9 The vectors operating card')
g = guide_b.index('\n## Glossary', a)
CARD = guide_b[a:g].strip('\n').rstrip('-').rstrip('\n') + '\n'
assert 'def flagged' in CARD and 'def near_duplicates' in CARD

# ---- the collection example and checker (as C-3), from arm A's guide -----------------------------
a = guide_a.index('### 15.1a The findings in the file'); b = guide_a.index('```json\n', a) + 8; c = guide_a.index('\n```\n', b)
json.loads(guide_a[b:c])
a = guide_a.index('### 15.2 One constraint the app does not enforce'); b = guide_a.index('```python\n', a) + 10; c = guide_a.index('\n```\n', b)
pathlib.Path(CHECKER_PATH).write_text(guide_a[b:c].strip('\n') + '\n')

# ---- the rubric: the vectors tier's 41, plus V8, O4, O2' (scored) and V7 (the refuter's) -------
rubric = (C3V / 'RUBRIC.md').read_text()
rubric = rubric[:rubric.index('**41 items in all**')].rstrip('\n') + '\n\n'
NEW_ROWS = """| id | block | item | `obeyed` requires |
|---|---|---|---|
| V8 | VECTORS | No vector vocabulary where the historian reads: no Hamming, cosine, bit count, cluster number, "vector" or "neighbour at N" in overview.md, or in the collection's `introductionText`, `prose` entries or `notes`. | None found. A session that opened no vector artifact scores it `not_applicable`. |
| O4 | READER | The collection's `introductionText`, `prose` entries and `notes` carry no SQL, no table or column name, no id pair outside a history.state.gov URL, and no file path. | None found. |
| O2' | READER | Every numeral and number-word in overview.md has a row in the memo's trace table. | Your own list of the overview's numerals and number-words (dates, document numbers and volume numbers excepted), each matched to a trace row; any without one is `violated`, and name them. |"""
rubric += ("## ADDED FOR THE STEERING TIER — V8, O4 and O2', and V7 (the refuter's)\n\n"
           'Design: `Planning/C-3-Steering-Tier-Design.md` §4. Same verdict vocabulary. **V7 is not '
           'scored here**: the refuter\nreports it, from its re-run of the logged queries. O4 and O2\' '
           'are scored in every run; V8, like V1–V6, is\n`not_applicable` when the session opened no '
           'vector artifact.\n\n' + NEW_ROWS + '\n\n')
N_TOTAL = len(re.findall(r"^\| [A-Z]\d'? \|", rubric, re.M))
assert N_TOTAL == 44, N_TOTAL
rubric += f"**{N_TOTAL} items scored here**: the 26 of the main table, P1–P4, P5–P6, O1–O3, V1–V6, V8, O4 and O2'; V7 is the refuter's.\n"
pathlib.Path(RUBRIC_PATH).write_text(rubric)

# ---- the runs and their opaque labels -------------------------------------------------------------
RUNS_PLAN = [('O-med A (1)', 'claude-opus-5-5', 'medium', 'A'), ('O-med B (1)', 'claude-opus-5-5', 'medium', 'B'),
             ('S-high A (1)', 'claude-sonnet-5-5', 'high', 'A'), ('S-high B (1)', 'claude-sonnet-5-5', 'high', 'B'),
             ('O-med A (2)', 'claude-opus-5-5', 'medium', 'A'), ('O-med B (2)', 'claude-opus-5-5', 'medium', 'B'),
             ('S-high A (2)', 'claude-sonnet-5-5', 'high', 'A'), ('S-high B (2)', 'claude-sonnet-5-5', 'high', 'B'),
             ('O-med B, no artifacts', 'claude-opus-5-5', 'medium', 'B0')]
rng = random.Random(20261030)
labels = [f's{i}' for i in range(1, 10)]; rng.shuffle(labels)
keymap = {run: {'order': n + 1, 'label': lab, 'model': m, 'effort': e, 'arm': arm}
          for n, ((run, m, e, arm), lab) in enumerate(zip(RUNS_PLAN, labels))}
keymap['cal'] = {'label': 'cal', 'arm': None, 'note': "calibration: the vectors tier's v3 (S-high+V (1)) scored with the 44 items and refuted with both readings; V7 and V8 must come back violated, O4 obeyed, the strict reading {frus1958-60v05/d112}"}
(OUT / 'keymap.json').write_text(json.dumps(keymap, indent=2) + '\n')

# ---- shared prompt text -------------------------------------------------------------------------------
v_runner = (C3V / 'prompts' / 'runner.txt').read_text()
RES_START = v_runner.index('RESOURCES — identical for every cell of this experiment.')
RES_END = v_runner.index('HOUSE RULES — follow these throughout.')
RESOURCES_V = v_runner[RES_START:RES_END].replace('/Users/jbotts/frus-analysis/c3v/runs/vN', RUNS + '/{{LABEL}}')
OLD_TOOL = ('- Python 3.9 has no `int.bit_count()` (it arrived in 3.10), so Appendix A\'s §A.5 loop fails as\n'
            '  printed; `bin(x).count("1")` is the 3.9 form. A full Hamming scan of the 314,616 sign rows in\n'
            '  pure Python with it takes a few seconds; numpy is not installed.\n')
assert OLD_TOOL in RESOURCES_V
NEW_TOOL = ('- Python 3.9 has no `int.bit_count()` (it arrived in 3.10), so Appendix A\'s §A.5 loop fails as\n'
            '  printed; `bin(x).count("1")` is the 3.9 form. numpy 2.0.2 imports from the user\'s site\n'
            '  packages (so not under `python3 -I`), and its `np.bitwise_count` makes a full Hamming scan\n'
            '  of the 314,616 sign rows take milliseconds.\n')
RESOURCES_A = RESOURCES_V.replace(OLD_TOOL, NEW_TOOL)
assert 'which Appendix A below describes' in RESOURCES_A
RESOURCES_B = (RESOURCES_A
    .replace('4. The app\'s semantic vector artifacts, which Appendix A below describes, read-only:',
             '4. The app\'s semantic vector artifacts, which the operating card below describes, read-only:')
    .replace("   so the vectors answer document-to-document questions only (Appendix A §A.5), never a free-text one.\n",
             "   so the vectors answer document-to-document questions only (Appendix A §A.5), never a free-text one.\n\n"
             "5. The guide the house rules and the card come from, as a file to consult, read-only:\n"
             f"     {GUIDE_COPY}\n"
             "   Appendix A there is the reference for the vector artifacts; the card below is its working part.\n")
    .replace('own run directory and the SemanticVectors folder named above.',
             'own run directory, the SemanticVectors folder and the guide folder named above.'))
assert '5. The guide the house rules' in RESOURCES_B and 'the guide folder named above' in RESOURCES_B
# B0: items 1-3, no vector artifacts, no guide copy, no vector tooling note
i4 = RESOURCES_A.index("4. The app's semantic vector artifacts")
ic = RESOURCES_A.index('CANARY — your FIRST tool call')
RESOURCES_B0 = (RESOURCES_A[:i4] + RESOURCES_A[ic:]).replace(NEW_TOOL, '').replace(
    'own run directory and the SemanticVectors folder named above.', 'own run directory.')
assert 'semantic-vectors-binary' not in RESOURCES_B0 and 'SemanticVectors' not in RESOURCES_B0

DELIV_START = v_runner.index("THE HISTORIAN'S DELIVERABLE")
DELIVERABLE_A = v_runner[DELIV_START:].replace('/Users/jbotts/frus-analysis/c3v/runs/vN', RUNS + '/{{LABEL}}')
assert DELIVERABLE_A.rstrip().endswith('{{LABEL}}') and 'centroid\n   similarity, the map, near-duplicates' in DELIVERABLE_A
V_SENT_A = ("a section headed VECTORS that names each of\n"
            "   Appendix A's operations you ran (nearest neighbours of a document, a semantic join, centroid\n"
            "   similarity, the map, near-duplicates), each with its anchor, the file it ran over, the baseline\n"
            "   it was read against and what it found, or the single word \"none\" if you ran none, and says\n"
            "   which documents in the overview you reached through a vector operation and through no\n"
            "   full-text query; and a TRACE TABLE:")
assert V_SENT_A in DELIVERABLE_A
V_SENT_B = ("a section headed VECTORS that, when your brief\n"
            "   hands you the vector artifacts, names the two required operations (the nearest neighbours of\n"
            "   an anchor, joined into the database and flagged; near-duplicates before any count) and the\n"
            "   conditional one (the map), each as run, with its anchor, the file it ran over, the baseline it\n"
            "   was read against and what it found, or as not run and why; says which documents the overview\n"
            "   cites were vector-reached, under the strict reading and under the practical one; and gives the\n"
            "   provenance digest with the index's generated stamp; or, when your brief hands you none, the\n"
            "   words \"VECTORS: none\"; and a TRACE TABLE:")
DELIVERABLE_B = DELIVERABLE_A.replace(V_SENT_A, V_SENT_B)
assert V_SENT_B in DELIVERABLE_B

HEAD = ("You are doing one research session for a historian on a research question, using a local\n"
        "installation of the FRUS Explorer research corpus (the Foreign Relations of the United States\n"
        "series). Your cell label is {{LABEL}}; the label means nothing and you need not mention it.\n\n"
        "YOUR RUN DIRECTORY (yours alone; create it; write nothing outside it):\n"
        f"     {RUNS}/{{{{LABEL}}}}\n\n")
RUNNER_A = (HEAD + RESOURCES_A + 'HOUSE RULES — follow these throughout.\n\n' + HOUSE_A + '\n'
            "APPENDIX A OF THE GUIDE — the semantic vector artifacts named in RESOURCES item 4: what they are,\n"
            "how to read them, what an agent can do with them and what they cannot tell you. Reference, not a\n"
            "second rule block; its closing addendum is written for the house rules above.\n\n"
            + APPENDIX + '\nTHE QUESTION\n' + QUESTION + '\n\n' + DELIVERABLE_A)
RUNNER_B = (HEAD + RESOURCES_B + 'HOUSE RULES — follow these throughout.\n\n' + BLOCK_B + '\n'
            "APPENDIX A §A.9 OF THE GUIDE — the operating card for the vector artifacts named in RESOURCES\n"
            "item 4: their formats and the code. Reference, not a second rule block: the rules are the house\n"
            "rules' SEMANTIC VECTORS section. The whole guide is RESOURCES item 5.\n\n"
            + CARD + '\nTHE QUESTION\n' + QUESTION + '\n\n' + DELIVERABLE_B)
RUNNER_B0 = (HEAD + RESOURCES_B0 + 'HOUSE RULES — follow these throughout.\n\n' + BLOCK_B + '\n'
             + 'THE QUESTION\n' + QUESTION + '\n\n' + DELIVERABLE_B)
for name, t in (('A', RUNNER_A), ('B', RUNNER_B), ('B0', RUNNER_B0)):
    assert QUESTION in t and t.count('{{LABEL}}') >= 3, name

# ---- the instruments: the vectors tier's prompts, re-pointed and extended ----------------------
def repoint(t):
    return (t.replace('/Users/jbotts/frus-analysis/c3v/runs/vN', RUNS + '/{{LABEL}}')
             .replace('/Users/jbotts/frus-analysis/c3v/RUBRIC.md', RUBRIC_PATH)
             .replace('/Users/jbotts/frus-analysis/c3v/check_collection.py', CHECKER_PATH)
             .replace('`cell` is exactly: vN', '`cell` is exactly: {{LABEL}}')
             .replace('how have u.s. policymakers\' thinking about cuba\'s impact on national security and prosperity changed since the 1870s?', QUESTION))
SCORER = repoint((C3V / 'prompts' / 'scorer.txt').read_text())
SCORER = (SCORER
    .replace('the 41 items are in its tables — 26 in the main\n  table, then P1–P4, P5–P6, O1–O3 and V1–V6 in the sections at the end',
             "the 44 items are in its tables — 26 in the main\n  table, then P1–P4, P5–P6, O1–O3, V1–V6, and V8, O4 and O2' in the sections at the end")
    .replace('- V1–V6 are scored on what the files show of vector work; a session that opened no vector\n  artifact (check the log and the scripts) scores all six `not_applicable`, and that is the\n  correct verdict, not a soft pass.\n- Score all 41 items.',
             "- V1–V6 and V8 are scored on what the files show of vector work; a session that opened no vector\n  artifact (check the log and the scripts) scores all seven `not_applicable`, and that is the\n  correct verdict, not a soft pass. O4 and O2' are scored in every session.\n- V7 is not yours: the refuter scores it. Do not return it.\n- Score all 44 items."))
assert '44 items' in SCORER and QUESTION in SCORER and 'V7 is not yours' in SCORER and '{{LABEL}}' in SCORER

REFUTER = repoint((C3V / 'prompts' / 'refuter.txt').read_text()).replace('DO ALL SEVEN', 'DO ALL SEVEN')
i7 = REFUTER.index('7. REACH.')
REFUTER = REFUTER[:i7] + """7. REACH, in two readings, and V7. For every document the overview cites (the pairs of step 5):
   STRICT: decide whether at least one full-text or chapter-heading query the session logged
   returns it. Re-run the log's MATCH, LIKE and heading queries, or the memo's scope set, and test
   membership. A cited document returned by none of them and shown in the memo or the log as found
   through a neighbour list, a cluster or a centroid is strictly VECTOR-REACHED; one returned by
   none and traceable to neither is UNTRACED.
   PRACTICAL: for each cited document the memo or the log shows a vector operation surfacing,
   decide from the log's order whether it was in a result set the session had read (printed or
   saved) before the neighbour list surfaced it. If it was not, it is practically vector-reached.
   V7: list the documents the memo claims were reached through the vectors and through no
   full-text or heading query (its STRICT list, where the memo gives two readings), and say for
   each whether your strict re-run confirms it. V7 is `obeyed` when every such claim is confirmed,
   `violated` when any is not (name it, and the query that returns it), and `not_applicable` when
   the memo claims none.
   Count the cited documents, the strictly and the practically vector-reached ones, and among the
   strict ones those the overview quotes from; list the pairs.

`cell` is exactly: {{LABEL}}. Return the structured refutation."""
assert '6. VECTOR USE' in REFUTER and 'V7: list the documents' in REFUTER and QUESTION in REFUTER

JUDGE = repoint((C3V / 'prompts' / 'judge.txt').read_text())
assert '  (none yet)' in JUDGE and QUESTION in JUDGE
JUDGE = JUDGE.replace('  (none yet)', '{{PREVIOUS}}')

c3_script = (C3 / 'workflow.mjs').read_text()
def const(name):
    return json.loads(re.search(r'^const ' + name + r' = (.*)$', c3_script, re.M).group(1))
VERDICT, READER, REFUTATION = const('VERDICT'), const('READER'), const('REFUTATION')
REFUTATION['properties']['vectorUse'] = {'type': 'object', 'properties': {
    'operations': {'type': 'array', 'items': {'type': 'string'}}, 'anchors': {'type': 'string'}, 'files': {'type': 'string'},
    'digestsCompared': {'type': 'boolean'}, 'baselinesUsed': {'type': 'string'},
    'neighbourListReproduced': {'type': 'string'}, 'notes': {'type': 'string'}},
    'required': ['operations', 'anchors', 'files', 'digestsCompared', 'baselinesUsed', 'neighbourListReproduced', 'notes']}
REFUTATION['properties']['reach'] = {'type': 'object', 'properties': {
    'citedDocuments': {'type': 'integer'}, 'ftsReached': {'type': 'integer'},
    'strictVectorReached': {'type': 'integer'}, 'strictPairs': {'type': 'string'},
    'strictQuoted': {'type': 'integer'},
    'practicalVectorReached': {'type': 'integer'}, 'practicalPairs': {'type': 'string'},
    'untraced': {'type': 'integer'}, 'method': {'type': 'string'}},
    'required': ['citedDocuments', 'ftsReached', 'strictVectorReached', 'strictPairs', 'strictQuoted',
                 'practicalVectorReached', 'practicalPairs', 'untraced', 'method']}
REFUTATION['properties']['v7'] = {'type': 'object', 'properties': {
    'memoClaimedStrict': {'type': 'string'}, 'verdict': {'type': 'string', 'enum': ['obeyed', 'violated', 'not_applicable']},
    'evidence': {'type': 'string'}}, 'required': ['memoClaimedStrict', 'verdict', 'evidence']}
REFUTATION['required'] += ['vectorUse', 'reach', 'v7']

J = lambda x: json.dumps(x, ensure_ascii=False)
script = f"""export const meta = {{
  name: 'c3-steering-tier',
  description: 'C-3 steering tier (R16): arm A (the guide as it stands) against arm B (the revised block and the vectors card), Opus 5.5 medium and Sonnet 5.5 high, plus B with no artifacts; scored, refuted and judged on Fable at max.',
  phases: [{{ title: 'Run' }}, {{ title: 'Score' }}, {{ title: 'Refute' }}, {{ title: 'Judge' }}],
}}
// Generated by /Users/jbotts/frus-analysis/c3s/generate_s.py; arm A from the guide at {rev_of(A_COMMIT)[:8]}, arm B from {rev_of(B_COMMIT)[:8]}.
// args: {{ cells: [{{label, model, effort, arm: 'A'|'B'|'B0', skipRun?, noJudge?}}], previous: [labels already judged] }}

const RUNNERS = {{ A: {J(RUNNER_A)}, B: {J(RUNNER_B)}, B0: {J(RUNNER_B0)} }}
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
log('C-3 steering tier: ' + cells.map(c => c.label + ':' + (c.arm || '-')).join(', ') + '; previously judged: ' + (previous.join(', ') || 'none'))

const results = []
for (const c of cells) {{
  let run = 'SKIPPED'
  if (!c.skipRun) {{
    run = await safe(() => agent(fill(RUNNERS[c.arm], c.label), {{ label: 'run:' + c.label, phase: 'Run', model: c.model, effort: c.effort }}))
  }}
  log('cell ' + c.label + ' run: ' + String(run).slice(0, 120))
  const instruments = [
    () => safe(() => agent(fill(SCORER, c.label), {{ label: 'score:' + c.label, phase: 'Score', model: 'claude-fable-5-1', effort: 'max', schema: VERDICT }})),
    () => safe(() => agent(fill(REFUTER, c.label), {{ label: 'refute:' + c.label, phase: 'Refute', model: 'claude-fable-5-1', effort: 'max', schema: REFUTATION }})),
  ]
  if (!c.noJudge) {{
    instruments.push(() => safe(() => agent(fill(JUDGE, c.label).split('{{{{PREVIOUS}}}}').join(previousList(previous)), {{ label: 'judge:' + c.label, phase: 'Judge', model: 'claude-fable-5-1', effort: 'max', schema: READER }})))
  }}
  const [score, refute, judge] = await parallel(instruments)
  if (!c.noJudge) previous.push(c.label)
  results.push({{ label: c.label, arm: c.arm, run, score, refute, judge: judge || null }})
}}
return {{ cells: results }}
"""
(OUT / 'workflow.mjs').write_text(script)

# The calibration (design §5 step 0) scores the vectors tier's v3, which answered the Cuba question,
# so its scorer and refuter carry that question; nothing else differs.
Q_V3 = (C3V / 'question.txt').read_text().strip()
cal_script = (script.replace(J(SCORER), J(SCORER.replace(QUESTION, Q_V3)))
                    .replace(J(REFUTER), J(REFUTER.replace(QUESTION, Q_V3)))
                    .replace("name: 'c3-steering-tier'", "name: 'c3-steering-calibration'"))
assert J(SCORER.replace(QUESTION, Q_V3)) in cal_script and QUESTION not in json.loads(J(SCORER.replace(QUESTION, Q_V3)))
(OUT / 'cal.mjs').write_text(cal_script)

CANARY_TASK = f"""THE TASK — this is the environment proof, not a research session. Do exactly these, in order,
and nothing else, using the operating card's code as written (set RES and DB to the paths in
RESOURCES). Write your run directory as {RUNS}/canary.
1. The CANARY command above. Paste its output.
2. The read-only proof above. Paste the error.
3. Run the card's identity block: print how many of the 553 volumes decode to exactly their `n`,
   and the four digests' first 8 characters; then print {SHARDS}/.generation and the digest at
   offset 16 of {SHARDS}/frus1861.vec.
4. Print the ten nearest neighbours of frus1861/d111 with the card's `nearest`, as
   `hamming N volume/document`, nearest first.
5. Print the random-pair mean, sd and 1st percentile, the median of `kth`, and `line`.
6. Run the card's `flagged` on the anchor frus1861/d111 with an empty scope, the literal
   re.compile(r"\\bblockade", re.I) and k=10, and print its rows.
7. Run the card's `near_duplicates` on the set {{frus1881/d405, frus1894app2/d394, frus1861/d111}}
   and print what it returns.
8. Write all of it to canary.txt in your run directory, and the commands to queries.log.
Then return as your entire final message one line: DONE, the digests' first 8 characters, the
volume count that decoded, the ten neighbours, and the near-duplicate pairs.

APPENDIX A §A.9 OF THE GUIDE — the operating card.

{CARD}"""
canary_prompt = RESOURCES_B.replace('{{LABEL}}', 'canary') + '\n' + CANARY_TASK
canary = f"""export const meta = {{
  name: 'c3-steering-canary',
  description: 'C-3 steering tier environment proof: one agent at the O-med pin runs arm B\\'s operating card on the shipped artifacts.',
  phases: [{{ title: 'Canary' }}],
}}
const PROMPT = {J(canary_prompt)}
log('C-3 steering canary: opus at medium, the O-med pin, on arm B\\'s RESOURCES text and card')
const out = await agent(PROMPT, {{ label: 'canary', phase: 'Canary', model: 'claude-opus-5-5', effort: 'medium' }})
return {{ canary: out }}
"""
(OUT / 'canary.mjs').write_text(canary)

pins = {'question': QUESTION, 'A_commit': rev_of(A_COMMIT), 'B_commit': rev_of(B_COMMIT),
        'guide_A_sha256': sha(guide_a), 'guide_B_sha256': sha(guide_b),
        'block_A': {'lines': BLOCK_A.count('\n'), 'sha256': sha(BLOCK_A)},
        'addendum': {'lines': ADDENDUM.count('\n'), 'sha256': sha(ADDENDUM)},
        'appendix': {'lines': APPENDIX.count('\n'), 'sha256': sha(APPENDIX)},
        'block_B': {'lines': BLOCK_B.count('\n'), 'sha256': sha(BLOCK_B)},
        'card': {'lines': CARD.count('\n'), 'sha256': sha(CARD)},
        'prompts': {}}
for name, t in [('runner_A', RUNNER_A), ('runner_B', RUNNER_B), ('runner_B0', RUNNER_B0), ('scorer', SCORER),
                ('refuter', REFUTER), ('judge', JUDGE), ('canary', canary_prompt)]:
    rendered = t.replace('{{LABEL}}', 'sN').replace('{{PREVIOUS}}', '  (none yet)')
    (OUT / 'prompts' / f'{name}.txt').write_text(rendered)
    pins['prompts'][name] = {'lines': rendered.count('\n'), 'chars': len(rendered), 'sha256': sha(rendered)}
    bad = [l for l in t.splitlines() if '-uri' in l and 'Do NOT pass' not in l and 'rejects' not in l]
    assert not bad, (name, bad)
(OUT / 'pins.json').write_text(json.dumps(pins, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({k: v for k, v in pins.items() if k != 'prompts'}, indent=1)[:1500])
for k, v in pins['prompts'].items():
    print(f"{k:10s} {v['lines']:5d} lines {v['chars']:7,d} chars {v['sha256'][:12]}")
print('keymap:', {k: v['label'] for k, v in keymap.items()})
print('rubric items scored:', N_TOTAL, '; script', len(script), 'chars; canary', len(canary), 'chars')
