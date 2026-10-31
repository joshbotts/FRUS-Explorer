#!/usr/bin/env python3
"""The reader-facing pass's pilot (Planning/Agentic-Guide-Reader-Facing-Style-Review-2026-10-30.md §5):
four measured runs' memos, each written into an overview twice, under the READER-FACING OUTPUT
section as it stands and under the review's R1 with R2's skeleton; a blind pairwise reader judge and
an O2' scorer per pair. Every text is cut by marker; nothing is transcribed.
Writes pilot.mjs, keymap.json, pins.json and prompts/."""
import hashlib, json, pathlib, random, re

REPO = pathlib.Path('/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/agentic-analysis-guide-revisions-8b3e52')
OUT = pathlib.Path('/Users/jbotts/frus-analysis/c3r')
RUNS = str(OUT / 'runs')
MANIFEST = '/Applications/FRUS Explorer.app/Contents/Resources/manifest.json'
sha = lambda t: hashlib.sha256(t.encode()).hexdigest()

guide = (REPO / 'Docs/Agentic-Analysis-Guide.md').read_text()
i = guide.index('READER-FACING OUTPUT —'); j = guide.index('\n\nSCOPING —', i)
SECTION_OLD = guide[i:j].rstrip('\n') + '\n'
review = (REPO / 'Planning/Agentic-Guide-Reader-Facing-Style-Review-2026-10-30.md').read_text()
a = review.index('```text\nREADER-FACING OUTPUT') + len('```text\n'); b = review.index('\n```\n', a)
SECTION_NEW = review[a:b].rstrip('\n') + '\n'
assert SECTION_OLD.count('\n') == 17 and SECTION_NEW.count('\n') == 28, (SECTION_OLD.count('\n'), SECTION_NEW.count('\n'))

runner = pathlib.Path('/Users/jbotts/frus-analysis/c3s/prompts/runner_A.txt').read_text()
s0 = runner.index('2. overview.md —'); s1 = runner.index('3. collection.fruscollection —')
SKELETON_OLD = runner[s0 + 3:s1].rstrip('\n') + '\n'
SKELETON_NEW = SKELETON_OLD
for old, new in [
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
     '   1958–1960, Volume VII, Part 1, Document 12" — followed by the history.state.gov URL\n')]:
    assert SKELETON_NEW.count(old) == 1, old[:60]
    SKELETON_NEW = SKELETON_NEW.replace(old, new)

c3_runner = pathlib.Path('/Users/jbotts/frus-analysis/c3/prompts/runner.txt').read_text()
Q_C3 = c3_runner[c3_runner.index('THE QUESTION\n') + len('THE QUESTION\n'):].split('\n')[0].strip()
assert Q_C3.startswith('How did the United States decide whether to recognize'), Q_C3
Q_V = (REPO / 'Planning/c3-vectors-tier/question.txt').read_text().strip()
Q_S = (REPO / 'Planning/c3-steering-tier/question.txt').read_text().strip()
SOURCES = [('r12', Q_C3, 'claude-sonnet-5-5', 'high'), ('r8', Q_C3, 'claude-fable-5-1', 'medium'),
           ('v3', Q_V, 'claude-sonnet-5-5', 'high'), ('s3', Q_S, 'claude-opus-5-5', 'medium')]

rng = random.Random(20261030)
labels = [f'w{k}' for k in range(1, 9)]; rng.shuffle(labels)
pairs, keymap, prompts = [], {}, {}
for n, (src, q, model, effort) in enumerate(SOURCES):
    la, lb = labels[2 * n], labels[2 * n + 1]
    old_first = rng.random() < 0.5
    A = {'label': la, 'wording': 'old' if old_first else 'new'}
    B = {'label': lb, 'wording': 'new' if old_first else 'old'}
    pair = f'P{n + 1}'
    pairs.append({'pair': pair, 'source': src, 'model': model, 'effort': effort, 'A': A, 'B': B})
    for x in (A, B):
        keymap[x['label']] = {'pair': pair, 'source': src, 'wording': x['wording'], 'model': model, 'effort': effort, 'slot': 'A' if x is A else 'B'}
    inputs = str(OUT / 'inputs' / src)
    for x in (A, B):
        section, skeleton = (SECTION_OLD, SKELETON_OLD) if x['wording'] == 'old' else (SECTION_NEW, SKELETON_NEW)
        prompts['write:' + x['label']] = f"""You are writing the overview for a historian from one research session that is already done. Its
memo and its collection are in front of you, and nothing else is to be searched. Your label is
{x['label']}; the label means nothing and you need not mention it.

YOUR RUN DIRECTORY (yours alone; create it; write nothing outside it):
     {RUNS}/{x['label']}

INPUTS, read-only:
- {inputs}/memo.md: the operator's memo. It holds the scope, every figure in its audit form,
  every quotation with the document it was verified against, and a trace table written for an
  earlier overview of the same research.
- {inputs}/collection.fruscollection: the collection (JSON) that the overview's documents and
  quotations belong to. Its excerpts are the verified passages.
- "{MANIFEST}": each volume's printed title, for the full citations.
Do NOT read anything else: no other file under /Users/jbotts/ (nothing under /Users/jbotts/Development/,
no other folder of /Users/jbotts/frus-analysis/), no database, no network.

THE RULES
- Every figure, quotation and claim in the overview comes from the memo. Quote only passages the
  memo or the collection's excerpts give, word for word.
- Every document the overview cites is in the collection.
- Write two files in your run directory: overview.md, and trace.md, with one row per number and
  per quotation in the overview, giving the memo line it comes from.

READER-FACING OUTPUT — the rules the overview follows:
{section}
THE QUESTION
{q}

THE OVERVIEW
{skeleton}
When both files are written, return as your entire final message the single line:
DONE {RUNS}/{x['label']}"""
    prompts['o2p:' + pair] = f"""You are scoring two overviews on one rule: every numeral and number-word in an overview has a row
in its trace table, giving the memo line it comes from. Be exact and hard.

THE FILES, read-only:
  Overview A: {RUNS}/{A['label']}/overview.md, with its trace table {RUNS}/{A['label']}/trace.md
  Overview B: {RUNS}/{B['label']}/overview.md, with its trace table {RUNS}/{B['label']}/trace.md
  The memo both were written from: {inputs}/memo.md
Read nothing else, and ignore any mention of how or by what the files were made.

For each overview, list every numeral and number-word in overview.md ("three", "about one in
seven", "1,204", "twice", "half"). Leave out dates and years, document, volume and part numbers,
and any number inside a citation or a URL. For each one, decide whether trace.md has a row for it
whose memo line, checked in the memo, holds that figure. Count the numbers, count the traced ones,
and name every miss. The verdict is `obeyed` when there is no miss and `violated` otherwise.

`pair` is exactly: {pair}. Return the structured result."""
    prompts['judge:' + pair] = f"""You are the reader judge. You read ONLY the two overviews named here, written for a historian
who commissioned the question and will never open a terminal, and judge which serves her better.
Both were written from the same research; they differ only in how they are written. Open no other
file, and ignore any mention of how or by what they were made.

THE FILES:
  Overview A: {RUNS}/{A['label']}/overview.md
  Overview B: {RUNS}/{B['label']}/overview.md
THE QUESTION:
  {q}

FOR EACH OVERVIEW, five items, each yes or no, each with the passage that decided it:
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
FINALLY: which overview serves the historian better, A or B, and why, in two or three sentences.
The evidence is the same in both, so judge the writing.

`pair` is exactly: {pair}. Return the structured judgement."""

O2P = {'type': 'object', 'properties': {'pair': {'type': 'string'}, **{s: {'type': 'object', 'properties': {
    'label': {'type': 'string'}, 'numbers': {'type': 'integer'}, 'traced': {'type': 'integer'}, 'misses': {'type': 'string'},
    'verdict': {'type': 'string', 'enum': ['obeyed', 'violated']}}, 'required': ['label', 'numbers', 'traced', 'misses', 'verdict']} for s in 'AB'},
    'notes': {'type': 'string'}}, 'required': ['pair', 'A', 'B', 'notes']}
ONE = {'type': 'object', 'properties': {'label': {'type': 'string'},
    'items': {'type': 'array', 'items': {'type': 'object', 'properties': {'id': {'type': 'string'}, 'verdict': {'type': 'string', 'enum': ['yes', 'no']},
              'evidence': {'type': 'string'}}, 'required': ['id', 'verdict', 'evidence']}},
    'citations': {'type': 'object', 'properties': {'verdict': {'type': 'string', 'enum': ['yes', 'no']}, 'evidence': {'type': 'string'}}, 'required': ['verdict', 'evidence']},
    'toolWords': {'type': 'string'}}, 'required': ['label', 'items', 'citations', 'toolWords']}
PAIR = {'type': 'object', 'properties': {'pair': {'type': 'string'}, 'A': ONE, 'B': ONE,
    'preference': {'type': 'string', 'enum': ['A', 'B']}, 'reason': {'type': 'string'}}, 'required': ['pair', 'A', 'B', 'preference', 'reason']}

J = lambda x: json.dumps(x, ensure_ascii=False)
script = f"""export const meta = {{
  name: 'reader-facing-pilot',
  description: 'Reader-facing pass pilot: four memos each written into an overview under the section as it stands and under R1, then an O2 prime scorer and a blind pairwise reader judge per pair on Fable at max.',
  phases: [{{ title: 'Write' }}, {{ title: 'Score' }}, {{ title: 'Judge' }}],
}}
// Generated by /Users/jbotts/frus-analysis/c3r/generate_r.py. args: {{ pairs: ['P1', ...] }}
const PROMPTS = {J(prompts)}
const PAIRS = {J({p['pair']: p for p in pairs})}
const O2P = {J(O2P)}
const PAIR = {J(PAIR)}
const safe = async (f) => {{ try {{ return await f() }} catch (e) {{ return {{ error: String(e) }} }} }}
const chosen = args.pairs.map(k => PAIRS[k])
log('reader-facing pilot: ' + chosen.map(p => p.pair + ' (' + p.source + ')').join(', '))
const results = await pipeline(chosen,
  p => parallel([p.A, p.B].map(x => () => safe(() => agent(PROMPTS['write:' + x.label], {{ label: 'write:' + x.label, phase: 'Write', model: p.model, effort: p.effort }})))),
  (w, p) => parallel([
    () => safe(() => agent(PROMPTS['o2p:' + p.pair], {{ label: 'o2p:' + p.pair, phase: 'Score', model: 'claude-fable-5-1', effort: 'max', schema: O2P }})),
    () => safe(() => agent(PROMPTS['judge:' + p.pair], {{ label: 'judge:' + p.pair, phase: 'Judge', model: 'claude-fable-5-1', effort: 'max', schema: PAIR }})),
  ]).then(r => ({{ pair: p.pair, writers: w, o2p: r[0], judge: r[1] }})))
return {{ pairs: results }}
"""
(OUT / 'pilot.mjs').write_text(script)
(OUT / 'keymap.json').write_text(json.dumps(keymap, indent=2) + '\n')
for k, t in prompts.items():
    (OUT / 'prompts' / (k.replace(':', '_') + '.txt')).write_text(t)
pins = {'section_old': {'lines': SECTION_OLD.count('\n'), 'sha256': sha(SECTION_OLD)}, 'section_new': {'lines': SECTION_NEW.count('\n'), 'sha256': sha(SECTION_NEW)},
        'skeleton_old_sha256': sha(SKELETON_OLD), 'skeleton_new_sha256': sha(SKELETON_NEW), 'pairs': pairs}
(OUT / 'pins.json').write_text(json.dumps(pins, indent=2) + '\n')
print(json.dumps({k: v for k, v in pins.items() if k != 'pairs'}, indent=1))
for p in pairs: print(p['pair'], p['source'], p['model'], p['effort'], 'A', p['A'], 'B', p['B'])
print('prompts:', len(prompts), '; script', len(script), 'chars')
