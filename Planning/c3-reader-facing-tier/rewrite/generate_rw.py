#!/usr/bin/env python3
"""The rewrite test of R1 and R2 alone (the owner's word of 2026-10-31: "do the smaller test of r1 and r2
alone"; 8 pairs). The pilot's design (reader-facing-style/pilot/generate_r.py), on the reader-facing tier's
eight A and K memos: each memo and collection written into an overview twice, under the READER-FACING OUTPUT
section and skeleton as they stand and under R1 (the style review's 30-line §4 text at 848f3781) with R2's
skeleton; no vocabulary bullet. The writer is the source run's own cell. A blind pairwise judge on Fable at
max; O2' by the tier's script only. Writes rewrite.mjs, keymap.json, pins.json and prompts/."""
import hashlib, json, pathlib, random, shutil, subprocess

REPO = '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/elastic-kowalevski-07a5ac'
C3F = pathlib.Path('/Users/jbotts/frus-analysis/c3f')
OUT = C3F / 'rewrite'
RUNS = str(OUT / 'runs')
MANIFEST = '/Applications/FRUS Explorer.app/Contents/Resources/manifest.json'
sha = lambda t: hashlib.sha256(t.encode()).hexdigest()
show = lambda path: subprocess.run(['git', '-C', REPO, 'show', f'848f3781:{path}'], capture_output=True, text=True, check=True).stdout

guide = show('Docs/Agentic-Analysis-Guide.md')
b0 = guide.index('\n## 12. A house-rules block to paste into your agent')
i = guide.index('READER-FACING OUTPUT —', b0); j = guide.index('\n\nSCOPING —', i)
SECTION_OLD = guide[i:j].rstrip('\n') + '\n'
review = show('Planning/Agentic-Guide-Reader-Facing-Style-Review-2026-10-30.md')
a = review.index('```text\nREADER-FACING OUTPUT') + len('```text\n'); b = review.index('\n```\n', a)
SECTION_NEW = review[a:b].rstrip('\n') + '\n'
assert SECTION_OLD.count('\n') == 17 and SECTION_NEW.count('\n') == 30
assert sha(SECTION_NEW).startswith('d08e51eb') and sha(SECTION_OLD).startswith('8fbf4c7a')

runner = (C3F / 'prompts' / 'runner_A.txt').read_text()
s0 = runner.index('2. overview.md —'); s1 = runner.index('3. collection.fruscollection —')
SKELETON_OLD = runner[s0 + 3:s1].rstrip('\n') + '\n'
SKELETON_NEW = SKELETON_OLD
for old, new in [   # R2: the pilot's four replacements, unchanged
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
Q = (C3F / 'question.txt').read_text().strip()

K = json.load(open(C3F / 'keymap.json'))
SOURCES = sorted([(n, v) for n, v in K.items() if v.get('arm') in ('A', 'K')], key=lambda x: (x[0].split()[-1], x[1]['order']))
rng = random.Random(20261101)
labels = [f'w{k}' for k in range(1, 17)]; rng.shuffle(labels)
pairs, keymap, prompts = [], {}, {}
for n, (name, src) in enumerate(SOURCES):
    lab = src['label']
    inputs = OUT / 'inputs' / lab
    inputs.mkdir(parents=True, exist_ok=True)
    for f in ('memo.md', 'collection.fruscollection'):
        shutil.copy(C3F / 'runs' / lab / f, inputs / f)
    la, lb = labels[2 * n], labels[2 * n + 1]
    old_first = rng.random() < 0.5
    A = {'label': la, 'wording': 'old' if old_first else 'new'}
    B = {'label': lb, 'wording': 'new' if old_first else 'old'}
    pair = f'P{n + 1}'
    pairs.append({'pair': pair, 'source': lab, 'sourceRun': name, 'model': src['model'], 'effort': src['effort'], 'A': A, 'B': B})
    for x in (A, B):
        keymap[x['label']] = {'pair': pair, 'source': lab, 'sourceRun': name, 'wording': x['wording'],
                              'model': src['model'], 'effort': src['effort'], 'slot': 'A' if x is A else 'B'}
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
{Q}

THE OVERVIEW
{skeleton}
When both files are written, return as your entire final message the single line:
DONE {RUNS}/{x['label']}"""
    prompts['judge:' + pair] = f"""You are the reader judge. You read ONLY the two overviews named here, written for a historian
who commissioned the question and will never open a terminal, and judge which serves her better.
Both were written from the same research; they differ only in how they are written. Open no other
file, and ignore any mention of how or by what they were made.

THE FILES:
  Overview A: {RUNS}/{A['label']}/overview.md
  Overview B: {RUNS}/{B['label']}/overview.md
THE QUESTION:
  {Q}

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

ONE = {'type': 'object', 'properties': {'label': {'type': 'string'},
    'items': {'type': 'array', 'items': {'type': 'object', 'properties': {'id': {'type': 'string'}, 'verdict': {'type': 'string', 'enum': ['yes', 'no']},
              'evidence': {'type': 'string'}}, 'required': ['id', 'verdict', 'evidence']}},
    'citations': {'type': 'object', 'properties': {'verdict': {'type': 'string', 'enum': ['yes', 'no']}, 'evidence': {'type': 'string'}}, 'required': ['verdict', 'evidence']},
    'toolWords': {'type': 'string'}}, 'required': ['label', 'items', 'citations', 'toolWords']}
PAIR = {'type': 'object', 'properties': {'pair': {'type': 'string'}, 'A': ONE, 'B': ONE,
    'preference': {'type': 'string', 'enum': ['A', 'B']}, 'reason': {'type': 'string'}}, 'required': ['pair', 'A', 'B', 'preference', 'reason']}
J = lambda x: json.dumps(x, ensure_ascii=False)
script = f"""export const meta = {{
  name: 'reader-facing-rewrite-test',
  description: 'The rewrite test of R1 and R2 alone: the reader-facing tier\\'s A and K memos each written into an overview under the section as it stands and under R1 with R2, on the source run\\'s own cell, then a blind pairwise reader judge on Fable at max.',
  phases: [{{ title: 'Write' }}, {{ title: 'Judge' }}],
}}
// Generated by /Users/jbotts/frus-analysis/c3f/rewrite/generate_rw.py. args: {{ pairs: ['P1', ...] }}
const PROMPTS = {J(prompts)}
const PAIRS = {J({p['pair']: p for p in pairs})}
const PAIR = {J(PAIR)}
const safe = async (f) => {{ try {{ return await f() }} catch (e) {{ return {{ error: String(e) }} }} }}
const chosen = args.pairs.map(k => PAIRS[k])
log('rewrite test: ' + chosen.map(p => p.pair + ' (' + p.source + ')').join(', '))
const results = await pipeline(chosen,
  p => parallel([p.A, p.B].map(x => () => safe(() => agent(PROMPTS['write:' + x.label], {{ label: 'write:' + x.label, phase: 'Write', model: p.model, effort: p.effort }})))),
  (w, p) => safe(() => agent(PROMPTS['judge:' + p.pair], {{ label: 'judge:' + p.pair, phase: 'Judge', model: 'claude-fable-5-1', effort: 'max', schema: PAIR }}))
    .then(j => ({{ pair: p.pair, writers: (w || []).map(x => String(x).slice(0, 80)), preference: j && j.preference }})))
return {{ pairs: results }}
"""
(OUT / 'rewrite.mjs').write_text(script)
(OUT / 'keymap.json').write_text(json.dumps(keymap, indent=2) + '\n')
(OUT / 'prompts').mkdir(exist_ok=True)
for k, t in prompts.items():
    (OUT / 'prompts' / (k.replace(':', '_') + '.txt')).write_text(t)
pins = {'section_old': {'lines': 17, 'sha256': sha(SECTION_OLD)}, 'section_new': {'lines': 30, 'sha256': sha(SECTION_NEW)},
        'skeleton_old_sha256': sha(SKELETON_OLD), 'skeleton_new_sha256': sha(SKELETON_NEW), 'pairs': pairs}
(OUT / 'pins.json').write_text(json.dumps(pins, indent=2) + '\n')
for p in pairs:
    print(p['pair'], p['source'], p['sourceRun'], p['model'], p['effort'], 'A', p['A'], 'B', p['B'])
print('prompts:', len(prompts), '; script', len(script), 'chars')
