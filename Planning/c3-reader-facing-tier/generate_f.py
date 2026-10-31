#!/usr/bin/env python3
"""C-3 reader-facing tier generator. Design: Planning/C-3-Reader-Facing-Tier-Design.md.

Three arms, every guide text cut by marker from a pinned commit, nothing transcribed:
  A  the guide as it stands (v1.38 at 848f3781): the §12 block with §A.8's addendum pasted at its end,
     Appendix A whole, R16's arm A RESOURCES and deliverable;
  W  candidate W (claude/c3-reader-facing-arm-w): its block (R1) with its addendum (R6's bullet), its
     Appendix A, and R2's four skeleton replacements in the deliverable, as the pilot made them;
  K  candidate K (claude/c3-reader-facing-arm-k): its block (R7, R8, R10), A's addendum and appendix.
The instruments are R16's: the rubric with V4, O1 and O2' reworded, O2' scored from the harness's
script, the refuter's steps 8 to 10, and one judge a block.

Writes workflow.mjs, cal.mjs, canary.mjs, RUBRIC.md, check_collection.py, keymap.json, pins.json and
prompts/ (one rendered copy of each prompt)."""
import hashlib, json, random, re, subprocess, pathlib

REPO = '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/elastic-kowalevski-07a5ac'
COMMITS = {'A': '848f3781', 'W': 'claude/c3-reader-facing-arm-w', 'K': 'claude/c3-reader-facing-arm-k'}
C3 = pathlib.Path('/Users/jbotts/frus-analysis/c3')
C3V = pathlib.Path('/Users/jbotts/frus-analysis/c3v')
C3S = pathlib.Path('/Users/jbotts/frus-analysis/c3s')
OUT = pathlib.Path('/Users/jbotts/frus-analysis/c3f')
RUNS = str(OUT / 'runs')
RUBRIC_PATH = str(OUT / 'RUBRIC.md')
CHECKER_PATH = str(OUT / 'check_collection.py')
QUESTION = (OUT / 'question.txt').read_text().strip()
assert QUESTION.startswith('How did policymakers assess American soft power'), QUESTION
Q_R16 = (C3S / 'question.txt').read_text().strip()
Q_V = (C3V / 'question.txt').read_text().strip()
c3_runner = (C3 / 'prompts' / 'runner.txt').read_text()
Q_C3 = c3_runner[c3_runner.index('THE QUESTION\n') + len('THE QUESTION\n'):].split('\n')[0].strip()
assert Q_R16.startswith('How has corruption') and Q_C3.startswith('How did the United States decide whether to recognize')
sha = lambda t: hashlib.sha256(t.encode()).hexdigest()


def show(rev):
    return subprocess.run(['git', '-C', REPO, 'show', f'{rev}:Docs/Agentic-Analysis-Guide.md'],
                          capture_output=True, text=True, check=True).stdout


def rev_of(rev):
    return subprocess.run(['git', '-C', REPO, 'rev-parse', rev], capture_output=True, text=True, check=True).stdout.strip()


def block_of(g):
    i = g.index('\n## 12. A house-rules block to paste into your agent')
    j = g.index('```text\n', i) + len('```text\n')
    k = g.index('\n```\n', j)
    return g[j:k].rstrip('\n') + '\n'


def addendum_of(g):
    a = g.index('A short addendum for the §12 house-rules block')
    b = g.index('```text\n', a) + len('```text\n')
    c = g.index('\n```\n', b)
    return g[b:c].rstrip('\n') + '\n'


def appendix_of(g):
    a = g.index('\n## Appendix A: The semantic vector artifacts')
    e = g.index('\n## Glossary', a)
    return g[a:e].strip('\n').rstrip('-').rstrip('\n') + '\n'


guides = {arm: show(c) for arm, c in COMMITS.items()}
BLOCK = {arm: block_of(g) for arm, g in guides.items()}
ADD = {arm: addendum_of(g) for arm, g in guides.items()}
APP = {arm: appendix_of(g) for arm, g in guides.items()}
assert sha(BLOCK['A']).startswith('c2f5511d') and sha(ADD['A']).startswith('e8117cb8') and sha(APP['A']).startswith('4e11cc17')
assert [BLOCK[a].count('\n') for a in 'AWK'] == [205, 218, 212], [BLOCK[a].count('\n') for a in 'AWK']
assert ADD['K'] == ADD['A'] and APP['K'] == APP['A'] and ADD['W'].count('\n') == 18
assert 'None of this vocabulary reaches the overview' in ADD['W'] and 'None of this vocabulary reaches the overview' in APP['W']
assert 'Documents cited' in BLOCK['W'] and 'frus_documents_vocab' in BLOCK['K'] and 'one bundled series in' in BLOCK['K'].replace('\n  ', ' ')
assert '11 of 695' in BLOCK['A'] and '11 of 695' in BLOCK['W'] and '11 of 695' not in BLOCK['K']

# ---- the collection checker (as C-3), from arm A's guide -----------------------------------------
gA = guides['A']
a = gA.index('### 15.1a The findings in the file'); b = gA.index('```json\n', a) + 8; c = gA.index('\n```\n', b)
json.loads(gA[b:c])
a = gA.index('### 15.2 One constraint the app does not enforce'); b = gA.index('```python\n', a) + 10; c = gA.index('\n```\n', b)
pathlib.Path(CHECKER_PATH).write_text(gA[b:c].strip('\n') + '\n')

# ---- the rubric: R16's 44 items, with V4, O1 and O2' reworded -----------------------------------
rubric = (C3S / 'RUBRIC.md').read_text()
REWORD = [
    ('| O1 | READER | The overview contains no SQL, column or table name, id pair or file path. |',
     '| O1 | READER | The overview contains no SQL, column or table name, id pair outside a history.state.gov URL, or file path. |'),
    ('| V4 | VECTORS | Suppressed edition twins on every neighbour surface (the Ed2 volumes, cosine 1.0 to their first editions). | The suppression stated and visible in the lists, or no Ed2 volume in any list. |',
     '| V4 | VECTORS | Suppressed edition twins on every neighbour surface: the Ed2 volumes whose first editions are in the corpus, frus1951-54IranEd2 and frus1969-76ve15p2Ed2 (cosine 1.0 to their first editions). frus1977-80v09Ed2 has no first edition in the corpus; the house rules say never to fold it, and its documents in a list are not a violation. | The suppression stated and visible in the lists, or no Ed2 volume with a first edition in the corpus in any list. |'),
    ("| O2' | READER | Every numeral and number-word in overview.md has a row in the memo's trace table. | Your own list of the overview's numerals and number-words (dates, document numbers and volume numbers excepted), each matched to a trace row; any without one is `violated`, and name them. |",
     "| O2' | READER | Every numeral and number-word in overview.md has a row in the memo's trace table. | Scored from the harness's script, `checks/o2p_flags.txt` in the run directory: each number it flags is TRACED (a row holds that figure in another form; name the row), NOT A NUMBER (only a \"one\" used as a pronoun; every other number-word is a number) or UNTRACED. A row that covers the overview's archival identifiers as a group (\"the identifiers in part 2\") traces them. Any UNTRACED is `violated`, and name them. If the script found no trace table, `violated`. |"),
]
for old, new in REWORD:
    assert rubric.count(old) == 1, old[:60]
    rubric = rubric.replace(old, new)
rubric = rubric.replace("**44 items scored here**", "## REWORDED FOR THE READER-FACING TIER — V4, O1 and O2'\n\n"
                        "Design: `Planning/C-3-Reader-Facing-Tier-Design.md` §4.1. The rows above carry the new texts, the same for every arm: "
                        "V4 exempts frus1977-80v09Ed2, an Ed2 volume with no first edition; O1 excepts the id pair inside a history.state.gov URL, "
                        "as O4 and the judge's J5 do; O2' is scored from the harness's script. Every other item is R16's, unchanged.\n\n"
                        "**44 items scored here**")
N_TOTAL = len(re.findall(r"^\| [A-Z]\d'? \|", rubric, re.M))
assert N_TOTAL == 44, N_TOTAL
pathlib.Path(RUBRIC_PATH).write_text(rubric)

# ---- the runs: four blocks, the arms rotated, opaque labels -----------------------------------------
CELLS = {'O-med': ('claude-opus-5-5', 'medium'), 'S-high': ('claude-sonnet-5-5', 'high')}
PLAN = [(1, 'O-med', '(1)', 'AWK'), (2, 'S-high', '(1)', 'WKA'), (3, 'O-med', '(2)', 'KAW'), (4, 'S-high', '(2)', 'AWK')]
rng = random.Random(20261031)
labels = [f'f{i}' for i in range(1, 13)]
rng.shuffle(labels)
keymap, order = {}, 0
for block, cell, rep, arms in PLAN:
    labs = []
    for arm in arms:
        name = f'{cell} {arm} {rep}'
        keymap[name] = {'order': order + 1, 'block': block, 'label': labels[order], 'model': CELLS[cell][0],
                        'effort': CELLS[cell][1], 'arm': arm}
        labs.append(labels[order])
        order += 1
    slots = labs[:]
    rng.shuffle(slots)
    keymap[f'judge {block}'] = {'block': block, 'slots': dict(zip('XYZ', slots))}
keymap['cal'] = {'label': 'cal', 'arm': None, 'note': (
    "calibration: the scorer on R16's s1 and s3 (copied as cal-s1, cal-s3), whose O2' misses, s3's V4 under the exemption and "
    "every other item are known; the refuter's steps 8 to 10 alone on the vectors tier's v2 (its '11 of 695' as its own "
    "finding) and C-3's r8 (a null reported with nothing beside it that returns rows on that surface)")}
(OUT / 'keymap.json').write_text(json.dumps(keymap, indent=2) + '\n')

# ---- shared prompt text: R16's arm A, re-pointed --------------------------------------------------
v_runner = (C3V / 'prompts' / 'runner.txt').read_text()
RES_START = v_runner.index('RESOURCES — identical for every cell of this experiment.')
RES_END = v_runner.index('HOUSE RULES — follow these throughout.')
RESOURCES_V = v_runner[RES_START:RES_END].replace('/Users/jbotts/frus-analysis/c3v/runs/vN', RUNS + '/{{LABEL}}')
OLD_TOOL = ('- Python 3.9 has no `int.bit_count()` (it arrived in 3.10), so Appendix A\'s §A.5 loop fails as\n'
            '  printed; `bin(x).count("1")` is the 3.9 form. A full Hamming scan of the 314,616 sign rows in\n'
            '  pure Python with it takes a few seconds; numpy is not installed.\n')
NEW_TOOL = ('- Python 3.9 has no `int.bit_count()` (it arrived in 3.10), so Appendix A\'s §A.5 loop fails as\n'
            '  printed; `bin(x).count("1")` is the 3.9 form. numpy 2.0.2 imports from the user\'s site\n'
            '  packages (so not under `python3 -I`), and its `np.bitwise_count` makes a full Hamming scan\n'
            '  of the 314,616 sign rows take milliseconds.\n')
assert OLD_TOOL in RESOURCES_V
RESOURCES = RESOURCES_V.replace(OLD_TOOL, NEW_TOOL)

DELIV_START = v_runner.index("THE HISTORIAN'S DELIVERABLE")
DELIVERABLE_A = v_runner[DELIV_START:].replace('/Users/jbotts/frus-analysis/c3v/runs/vN', RUNS + '/{{LABEL}}')
# R2: the pilot's four skeleton replacements (reader-facing-style/pilot/generate_r.py), made the same way
R2 = [
    ('**1. What FRUS answers directly** — one paragraph: the finding,',
     '**1. What FRUS answers directly** — one paragraph of about 150 words: the finding,'),
    ('**2. Where FRUS points for the rest** — one paragraph: the archival series',
     '**2. Where FRUS points for the rest** — two bulleted lists, one series to a line: the archival series'),
    ('     ## Read next — the collection, by name, and what the historian\'s additions would unlock\n',
     '     ## Read next — the collection, by name, and what the historian\'s additions would unlock\n'
     '     ## Documents cited — every document the overview cites, once each, in full as the printed\n'
     '        edition, then its history.state.gov URL, in the order first cited\n'),
    ('   Cite as the printed edition — "Foreign Relations of the United States, 1958–1960, Volume VII,\n'
     '   Part 1, Document 12" — followed by the history.state.gov URL\n',
     '   In the text, cite a document by year, volume and document number, and give its full citation\n'
     '   once, in Documents cited: as the printed edition — "Foreign Relations of the United States,\n'
     '   1958–1960, Volume VII, Part 1, Document 12" — followed by the history.state.gov URL\n')]
DELIVERABLE_W = DELIVERABLE_A
for old, new in R2:
    assert DELIVERABLE_W.count(old) == 1, old[:60]
    DELIVERABLE_W = DELIVERABLE_W.replace(old, new)
DELIVERABLE = {'A': DELIVERABLE_A, 'W': DELIVERABLE_W, 'K': DELIVERABLE_A}

HEAD = ("You are doing one research session for a historian on a research question, using a local\n"
        "installation of the FRUS Explorer research corpus (the Foreign Relations of the United States\n"
        "series). Your cell label is {{LABEL}}; the label means nothing and you need not mention it.\n\n"
        "YOUR RUN DIRECTORY (yours alone; create it; write nothing outside it):\n"
        f"     {RUNS}/{{{{LABEL}}}}\n\n")
APP_HEAD = ("APPENDIX A OF THE GUIDE — the semantic vector artifacts named in RESOURCES item 4: what they are,\n"
            "how to read them, what an agent can do with them and what they cannot tell you. Reference, not a\n"
            "second rule block; its closing addendum is written for the house rules above.\n\n")
RUNNERS = {arm: (HEAD + RESOURCES + 'HOUSE RULES — follow these throughout.\n\n' + BLOCK[arm] + '\n' + ADD[arm] + '\n'
                 + APP_HEAD + APP[arm] + '\nTHE QUESTION\n' + QUESTION + '\n\n' + DELIVERABLE[arm]) for arm in 'AWK'}
for arm, t in RUNNERS.items():
    assert QUESTION in t and t.count('{{LABEL}}') >= 3, arm

# ---- the instruments: R16's prompts, re-pointed and extended ------------------------------------
def repoint(t, label_from='`cell` is exactly: vN'):
    return (t.replace('/Users/jbotts/frus-analysis/c3v/runs/vN', RUNS + '/{{LABEL}}')
             .replace('/Users/jbotts/frus-analysis/c3v/RUBRIC.md', RUBRIC_PATH)
             .replace('/Users/jbotts/frus-analysis/c3v/check_collection.py', CHECKER_PATH)
             .replace(label_from, '`cell` is exactly: {{LABEL}}')
             .replace("how have u.s. policymakers' thinking about cuba's impact on national security and prosperity changed since the 1870s?", QUESTION))

SCORER = repoint((C3V / 'prompts' / 'scorer.txt').read_text())
SCORER = (SCORER
    .replace('the 41 items are in its tables — 26 in the main\n  table, then P1–P4, P5–P6, O1–O3 and V1–V6 in the sections at the end',
             "the 44 items are in its tables — 26 in the main\n  table, then P1–P4, P5–P6, O1–O3, V1–V6, and V8, O4 and O2' in the sections at the end")
    .replace('- V1–V6 are scored on what the files show of vector work; a session that opened no vector\n  artifact (check the log and the scripts) scores all six `not_applicable`, and that is the\n  correct verdict, not a soft pass.\n- Score all 41 items.',
             "- V1–V6 and V8 are scored on what the files show of vector work; a session that opened no vector\n  artifact (check the log and the scripts) scores all seven `not_applicable`, and that is the\n  correct verdict, not a soft pass. O4 and O2' are scored in every session.\n- V7 is not yours: the refuter scores it. Do not return it.\n"
             "- checks/ in the run directory holds the harness's own script outputs, written after the session\n  ended. They are not the session's work: never credit them to it.\n"
             "- O2' is scored from the harness's script, not from your own list. checks/o2p_flags.txt lists the\n"
             "  numbers in overview.md that the script could not match to a row of the memo's trace table: WEAK\n"
             "  (a row holds the value, but not the words after it) and UNTRACED (no row holds the value), each\n"
             "  with its sentence and the nearest row. Read only those. Decide each: TRACED (name the trace row\n"
             "  that holds that figure, in another form), NOT A NUMBER (only a \"one\" used as a pronoun: \"no one\",\n"
             "  \"one of them\"; every other number-word is a number, \"the two\" included), or UNTRACED. A row\n"
             "  that covers the overview's archival identifiers as a group (\"the identifiers in part 2\") traces\n"
             "  them. O2' is `violated` if any is UNTRACED; name each in the evidence, and give the count of flags you\n"
             "  read and how you decided them. Do not list the overview's numbers yourself. If the script found\n"
             "  no trace table, O2' is `violated`.\n"
             "- For T1 you may read checks/match_check.txt: every full-text term the session ran that returns no\n"
             "  document in the index copy, with the nearest form that does.\n- Score all 44 items."))
assert '44 items' in SCORER and QUESTION in SCORER and 'checks/o2p_flags.txt' in SCORER and '{{LABEL}}' in SCORER

REFUTER = repoint((C3V / 'prompts' / 'refuter.txt').read_text())
i7 = REFUTER.index('7. REACH.')
STEP7 = """7. REACH, in two readings, and V7. For every document the overview cites (the pairs of step 5):
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
"""
STEPS_8_10 = """
8. ZEROS. List every result the memo or the overview reports as zero, none, absent or not found
   (a query, a scan or a lookup that returned nothing). For each, say what the memo prints beside
   it: RELAXED, the relaxed form of the same query on the same surface (a term dropped, the date
   widened) with its count; OTHER, another query shown to return rows on that surface (a positive
   control, say); or NOTHING. A query that returns rows on a different surface (another volume
   set, other columns) is NOTHING for that zero. Count each kind, and list them.

9. THE HOUSE RULES' FIGURES. checks/figures_check.txt in the run directory (the harness's script)
   lists where memo.md and overview.md print a figure the session's house rules themselves print.
   For each occurrence, say whether the session RE-DERIVED it (its query or script shown, with the
   output), ATTRIBUTED it to the guide or the house rules, or presented it as its OWN finding with
   neither. A number that only coincides with one of the rules' figures (a document number, say)
   is NOT ONE of them. Count each kind, and list them.

10. TERMS THAT REACH NOTHING. checks/match_check.txt (the harness's script) lists every full-text
   term the session's logged commands and scripts ran that returns no document in the index copy,
   with the nearest form that does, and each `term*` prefix with whether the log looked its stem up
   in frus_documents_vocab before using it. For each dead term, say whether the memo or the overview
   reports a count or an absence from it, and whether the session NOTICED (said the term reaches
   nothing, or replaced it with a form that does). Count the dead terms, those reported from and
   those noticed. A term the script lists that is not a search term (a word from code) is NOT A TERM.

checks/ holds the harness's own script outputs, written after the session ended: they are not the
session's work.
"""
REFUTER = REFUTER[:i7] + STEP7 + STEPS_8_10 + "\n`cell` is exactly: {{LABEL}}. Return the structured refutation."
assert REFUTER.count('DO ALL SEVEN') == 1
REFUTER = REFUTER.replace('DO ALL SEVEN', 'DO ALL TEN')
S3_OLD = 'where the memo gives none, resolve the printed citation\nthrough manifest.json and say you did.'
if S3_OLD not in REFUTER:
    S3_OLD = re.search(r'where the memo gives none, resolve the printed citation\s+through manifest\.json and say you did\.', REFUTER).group(0)
REFUTER = REFUTER.replace(S3_OLD, S3_OLD + ' Where the overview has a Documents cited list, a\nshort citation in its text (year, volume, document number) resolves through that list.')
assert '6. VECTOR USE' in REFUTER and '10. TERMS THAT REACH NOTHING' in REFUTER and 'DO ALL TEN' in REFUTER and QUESTION in REFUTER
assert 'resolves through that list' in REFUTER

# the calibration's refuter: steps 8 to 10 alone
hdr_end = REFUTER.index('DO ALL TEN')
REFUTER_STEPS = (REFUTER[:hdr_end] + 'DO STEPS 8, 9 AND 10 BELOW, AND ONLY THOSE, and show your work in `notes` (the commands you ran\nand what came back):\n'
                 + STEPS_8_10 + "\n`cell` is exactly: {{LABEL}}. Return the structured result.")

JUDGE = f"""You are the reader judge. You read ONLY the three overviews and the three collections named here,
each written for a historian who commissioned the question and will never open a terminal, and judge
which serve her best. Do not open any other file: no memo, no log, no script output. Do not run
queries. Ignore any mention of which model or setting produced a file.

THE FILES, labelled X, Y and Z (the labels mean nothing):
  X: {RUNS}/{{{{X}}}}/overview.md and {RUNS}/{{{{X}}}}/collection.fruscollection
  Y: {RUNS}/{{{{Y}}}}/overview.md and {RUNS}/{{{{Y}}}}/collection.fruscollection
  Z: {RUNS}/{{{{Z}}}}/overview.md and {RUNS}/{{{{Z}}}}/collection.fruscollection
Read each collection as text: its title page, headings, prose, notes and excerpts are part of what the
historian receives. If a file is absent, say so in the evidence of every item it affects and judge
what is there.
THE QUESTION:
  {QUESTION}

FOR EACH OF X, Y AND Z, five items, each yes or no, each with the passage that decided it:
  J1  The overview opens with the three-part bottom line, in this order and before any finding:
      what FRUS answers directly; where FRUS points for the rest; what this request cannot get
      from FRUS.
  J2  Every number in the overview is given as a count of a named set in words ("about one
      document in seven among the 43 volumes indexed"), never as a bare percentage or a figure
      with no base; "no" if any number fails this.
  J3  Every document the overview cites is cited in full as the printed edition (Foreign Relations
      of the United States, years, volume, part, document number) with a history.state.gov link,
      in the text or in a list of the documents cited; "no" if any is cited by a bare id pair, or
      by title, date or correspondent alone with no full citation anywhere.
  J4  What the request cannot get from FRUS is stated as a search that was run (its terms, the
      volumes, and the controls that make the zero a measurement), not as an assertion.
  J5  The overview contains no SQL, no table or column name, no volume_id/document_id string (such
      as frus1961-63v12/d45) outside a link, and no file path.
THEN, FOR EACH: CITATIONS, yes if one citation form is used throughout and every cited document
can be found in full with its link, no otherwise, with the passage; and TOOL WORDS, every word of
the research machinery a historian would not know (index, query, hits, returned, matched, TEI,
corpus, stem, vector, Hamming and the like) and every technical term left unexplained, each with
where it appears, or "none".
FINALLY: rank X, Y and Z, best to worst for the historian, and give the reason for the order in two
or three sentences, judging the whole of what she receives: the evidence and the writing.

`block` is exactly: {{{{BLOCK}}}}. Return the structured judgement."""

# ---- schemas -----------------------------------------------------------------------------------------
c3_script = (C3 / 'workflow.mjs').read_text()
def const(name):
    return json.loads(re.search(r'^const ' + name + r' = (.*)$', c3_script, re.M).group(1))
VERDICT, REFUTATION = const('VERDICT'), const('REFUTATION')
REFUTATION['properties']['vectorUse'] = {'type': 'object', 'properties': {
    'operations': {'type': 'array', 'items': {'type': 'string'}}, 'anchors': {'type': 'string'}, 'files': {'type': 'string'},
    'digestsCompared': {'type': 'boolean'}, 'baselinesUsed': {'type': 'string'},
    'neighbourListReproduced': {'type': 'string'}, 'notes': {'type': 'string'}},
    'required': ['operations', 'anchors', 'files', 'digestsCompared', 'baselinesUsed', 'neighbourListReproduced', 'notes']}
REFUTATION['properties']['reach'] = {'type': 'object', 'properties': {
    'citedDocuments': {'type': 'integer'}, 'ftsReached': {'type': 'integer'},
    'strictVectorReached': {'type': 'integer'}, 'strictPairs': {'type': 'string'}, 'strictQuoted': {'type': 'integer'},
    'practicalVectorReached': {'type': 'integer'}, 'practicalPairs': {'type': 'string'},
    'untraced': {'type': 'integer'}, 'method': {'type': 'string'}},
    'required': ['citedDocuments', 'ftsReached', 'strictVectorReached', 'strictPairs', 'strictQuoted',
                 'practicalVectorReached', 'practicalPairs', 'untraced', 'method']}
REFUTATION['properties']['v7'] = {'type': 'object', 'properties': {
    'memoClaimedStrict': {'type': 'string'}, 'verdict': {'type': 'string', 'enum': ['obeyed', 'violated', 'not_applicable']},
    'evidence': {'type': 'string'}}, 'required': ['memoClaimedStrict', 'verdict', 'evidence']}
STEP_PROPS = {
    'zeros': {'type': 'object', 'properties': {'total': {'type': 'integer'}, 'relaxed': {'type': 'integer'}, 'other': {'type': 'integer'},
              'nothing': {'type': 'integer'}, 'list': {'type': 'string'}}, 'required': ['total', 'relaxed', 'other', 'nothing', 'list']},
    'houseFigures': {'type': 'object', 'properties': {'occurrences': {'type': 'integer'}, 'rederived': {'type': 'integer'},
                     'attributed': {'type': 'integer'}, 'own': {'type': 'integer'}, 'notOne': {'type': 'integer'}, 'list': {'type': 'string'}},
                     'required': ['occurrences', 'rederived', 'attributed', 'own', 'notOne', 'list']},
    'deadTerms': {'type': 'object', 'properties': {'listed': {'type': 'integer'}, 'notATerm': {'type': 'integer'}, 'reportedFrom': {'type': 'integer'},
                  'noticed': {'type': 'integer'}, 'list': {'type': 'string'}}, 'required': ['listed', 'notATerm', 'reportedFrom', 'noticed', 'list']}}
REFUTATION['properties'].update(STEP_PROPS)
REFUTATION['required'] += ['vectorUse', 'reach', 'v7', 'zeros', 'houseFigures', 'deadTerms']
STEPS = {'type': 'object', 'properties': {'cell': {'type': 'string'}, **STEP_PROPS, 'notes': {'type': 'string'}},
         'required': ['cell', 'zeros', 'houseFigures', 'deadTerms', 'notes']}
ONE = {'type': 'object', 'properties': {'slot': {'type': 'string', 'enum': ['X', 'Y', 'Z']},
       'items': {'type': 'array', 'items': {'type': 'object', 'properties': {'id': {'type': 'string'},
                 'verdict': {'type': 'string', 'enum': ['yes', 'no']}, 'evidence': {'type': 'string'}}, 'required': ['id', 'verdict', 'evidence']}},
       'citations': {'type': 'object', 'properties': {'verdict': {'type': 'string', 'enum': ['yes', 'no']}, 'evidence': {'type': 'string'}},
                     'required': ['verdict', 'evidence']},
       'toolWords': {'type': 'string'}}, 'required': ['slot', 'items', 'citations', 'toolWords']}
BLOCKJUDGE = {'type': 'object', 'properties': {'block': {'type': 'string'}, 'overviews': {'type': 'array', 'items': ONE},
              'ranking': {'type': 'array', 'items': {'type': 'string', 'enum': ['X', 'Y', 'Z']}}, 'reason': {'type': 'string'}},
              'required': ['block', 'overviews', 'ranking', 'reason']}

J = lambda x: json.dumps(x, ensure_ascii=False)
script = f"""export const meta = {{
  name: 'c3-reader-facing-tier',
  description: 'C-3 reader-facing tier: arm A (the guide as it stands) against W (R1, R2 and the vocabulary bullet) and K (R7, R8 and R10), Opus 5.5 medium and Sonnet 5.5 high; scored and refuted on Fable at max, one judge a block.',
  phases: [{{ title: 'Run' }}, {{ title: 'Score' }}, {{ title: 'Refute' }}, {{ title: 'Judge' }}],
}}
// Generated by /Users/jbotts/frus-analysis/c3f/generate_f.py; A from {rev_of(COMMITS['A'])[:8]}, W from {rev_of(COMMITS['W'])[:8]}, K from {rev_of(COMMITS['K'])[:8]}.
// args: {{ run?: {{label, model, effort, arm}}, instruments?: label, judge?: {{block, slots: {{X, Y, Z}}}} }}

const RUNNERS = {{ A: {J(RUNNERS['A'])}, W: {J(RUNNERS['W'])}, K: {J(RUNNERS['K'])} }}
const SCORER = {J(SCORER)}
const REFUTER = {J(REFUTER)}
const JUDGE = {J(JUDGE)}
const VERDICT = {J(VERDICT)}
const REFUTATION = {J(REFUTATION)}
const BLOCKJUDGE = {J(BLOCKJUDGE)}

const fill = (t, label) => t.split('{{{{LABEL}}}}').join(label)
const safe = async (f) => {{ try {{ return await f() }} catch (e) {{ return {{ error: String(e) }} }} }}
const out = {{}}
if (args.run) {{
  const r = args.run
  log('run ' + r.label + ' (' + r.model + ' at ' + r.effort + ')')
  const res = await safe(() => agent(fill(RUNNERS[r.arm], r.label), {{ label: 'run:' + r.label, phase: 'Run', model: r.model, effort: r.effort }}))
  out.run = String(typeof res === 'string' ? res : JSON.stringify(res)).slice(0, 300)
}}
const thunks = []
if (args.instruments) {{
  const lab = args.instruments
  thunks.push(() => safe(() => agent(fill(SCORER, lab), {{ label: 'score:' + lab, phase: 'Score', model: 'claude-fable-5-1', effort: 'max', schema: VERDICT }})).then(s => ['score', s]))
  thunks.push(() => safe(() => agent(fill(REFUTER, lab), {{ label: 'refute:' + lab, phase: 'Refute', model: 'claude-fable-5-1', effort: 'max', schema: REFUTATION }})).then(s => ['refute', s]))
}}
if (args.judge) {{
  const j = args.judge
  const p = JUDGE.split('{{{{BLOCK}}}}').join(String(j.block)).split('{{{{X}}}}').join(j.slots.X).split('{{{{Y}}}}').join(j.slots.Y).split('{{{{Z}}}}').join(j.slots.Z)
  thunks.push(() => safe(() => agent(p, {{ label: 'judge:' + j.block, phase: 'Judge', model: 'claude-fable-5-1', effort: 'max', schema: BLOCKJUDGE }})).then(s => ['judge', s]))
}}
const res = (await parallel(thunks)).filter(Boolean)
for (const [kind, s] of res) {{
  if (!s || s.error) {{ out[kind] = s ? s.error.slice(0, 200) : 'null'; continue }}
  if (kind === 'score') out.score = {{ obeyed: s.obeyed, violated: s.violated, notApplicable: s.notApplicable, violatedIds: (s.items || []).filter(x => x.verdict === 'violated').map(x => x.id) }}
  if (kind === 'refute') out.refute = {{ numbers: s.numbersReproduced + '/' + s.numbersTotal, quotes: s.quotationsVerified + '/' + s.quotationsTotal, fabrications: s.fabrications, v7: s.v7 && s.v7.verdict }}
  if (kind === 'judge') out.judge = {{ ranking: s.ranking }}
}}
return out
"""
(OUT / 'workflow.mjs').write_text(script)

# ---- the calibration (design §6 step 0) -----------------------------------------------------------------
SCORER_R16 = SCORER.replace(QUESTION, Q_R16)
STEPS_V2 = REFUTER_STEPS.replace(QUESTION, Q_V)
STEPS_R8 = REFUTER_STEPS.replace(QUESTION, Q_C3)
assert QUESTION not in SCORER_R16 and QUESTION not in STEPS_V2 and QUESTION not in STEPS_R8
cal = f"""export const meta = {{
  name: 'c3-reader-facing-calibration',
  description: 'C-3 reader-facing tier calibration: the scorer on two runs of R16 with known answers, and the refuter\\'s steps 8 to 10 on two earlier runs with known answers, on Fable at max.',
  phases: [{{ title: 'Calibrate' }}],
}}
const SCORER = {J(SCORER_R16)}
const STEPS_V2 = {J(STEPS_V2)}
const STEPS_R8 = {J(STEPS_R8)}
const VERDICT = {J(VERDICT)}
const STEPS = {J(STEPS)}
const fill = (t, label) => t.split('{{{{LABEL}}}}').join(label)
const safe = async (f) => {{ try {{ return await f() }} catch (e) {{ return {{ error: String(e) }} }} }}
const res = await parallel([
  () => safe(() => agent(fill(SCORER, 'cal-s1'), {{ label: 'score:cal-s1', phase: 'Calibrate', model: 'claude-fable-5-1', effort: 'max', schema: VERDICT }})),
  () => safe(() => agent(fill(SCORER, 'cal-s3'), {{ label: 'score:cal-s3', phase: 'Calibrate', model: 'claude-fable-5-1', effort: 'max', schema: VERDICT }})),
  () => safe(() => agent(fill(STEPS_V2, 'cal-v2'), {{ label: 'steps:cal-v2', phase: 'Calibrate', model: 'claude-fable-5-1', effort: 'max', schema: STEPS }})),
  () => safe(() => agent(fill(STEPS_R8, 'cal-r8'), {{ label: 'steps:cal-r8', phase: 'Calibrate', model: 'claude-fable-5-1', effort: 'max', schema: STEPS }})),
])
return {{ done: res.map(r => r ? (r.error ? 'error' : 'ok') : 'null') }}
"""
(OUT / 'cal.mjs').write_text(cal)

# ---- the canary (design §6 step 1): the vectors tier's task, re-pointed, on arm A's text ---------------------
c3v_canary = (C3V / 'prompts' / 'canary.txt').read_text()
t0 = c3v_canary.index('THE TASK — this is the environment proof')
t1 = c3v_canary.index('\n## Appendix A: The semantic vector artifacts')
CANARY_TASK = c3v_canary[t0:t1].replace('/Users/jbotts/frus-analysis/c3v/runs/canary', RUNS + '/canary').rstrip('\n') + '\n'
assert RUNS + '/canary' in CANARY_TASK and 'frus1861/d111' in CANARY_TASK
canary_prompt = RESOURCES.replace('{{LABEL}}', 'canary') + '\n' + CANARY_TASK + '\n' + APP['A']
canary = f"""export const meta = {{
  name: 'c3-reader-facing-canary',
  description: 'C-3 reader-facing tier environment proof: one agent at the O-med pin runs the CANARY, the read-only proof and Appendix A\\'s decode and neighbour list on the shipped artifacts.',
  phases: [{{ title: 'Canary' }}],
}}
const PROMPT = {J(canary_prompt)}
log('C-3 reader-facing canary: opus at medium, the O-med pin, on the arms\\' RESOURCES text and Appendix A')
const out = await agent(PROMPT, {{ label: 'canary', phase: 'Canary', model: 'claude-opus-5-5', effort: 'medium' }})
return {{ canary: String(out).slice(0, 1500) }}
"""
(OUT / 'canary.mjs').write_text(canary)

# ---- pins and rendered prompts ---------------------------------------------------------------------
pins = {'question': QUESTION, 'commits': {a: rev_of(c) for a, c in COMMITS.items()},
        'guides_sha256': {a: sha(g) for a, g in guides.items()},
        'blocks': {a: {'lines': BLOCK[a].count('\n'), 'sha256': sha(BLOCK[a])} for a in 'AWK'},
        'addenda': {a: {'lines': ADD[a].count('\n'), 'sha256': sha(ADD[a])} for a in 'AWK'},
        'appendices': {a: {'lines': APP[a].count('\n'), 'sha256': sha(APP[a])} for a in 'AWK'},
        'prompts': {}}
(OUT / 'prompts').mkdir(exist_ok=True)
rendered = [('runner_A', RUNNERS['A']), ('runner_W', RUNNERS['W']), ('runner_K', RUNNERS['K']), ('scorer', SCORER),
            ('refuter', REFUTER), ('judge', JUDGE), ('canary', canary_prompt), ('cal_scorer', SCORER_R16),
            ('cal_steps_v2', STEPS_V2), ('cal_steps_r8', STEPS_R8)]
for name, t in rendered:
    r = (t.replace('{{LABEL}}', 'fN').replace('{{X}}', 'fX').replace('{{Y}}', 'fY').replace('{{Z}}', 'fZ').replace('{{BLOCK}}', 'N'))
    (OUT / 'prompts' / f'{name}.txt').write_text(r)
    pins['prompts'][name] = {'lines': r.count('\n'), 'chars': len(r), 'sha256': sha(r)}
    bad = [l for l in t.splitlines() if '-uri' in l and 'Do NOT pass' not in l and 'rejects' not in l]
    assert not bad, (name, bad)
(OUT / 'pins.json').write_text(json.dumps(pins, indent=2, ensure_ascii=False) + '\n')
for k, v in pins['prompts'].items():
    print(f"{k:13s} {v['lines']:5d} lines {v['chars']:7,d} chars {v['sha256'][:12]}")
print('blocks', {a: v['lines'] for a, v in pins['blocks'].items()}, 'addenda', {a: v['lines'] for a, v in pins['addenda'].items()})
print('keymap:', {k: v.get('label', v.get('slots')) for k, v in keymap.items() if k != 'cal'})
print('rubric items:', N_TOTAL, '; workflow', len(script), 'chars')
