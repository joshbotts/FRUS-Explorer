# Early-era NER harvest runbook — R-1 over the no-list volumes (#234)

The corpus this covers is the one described in the comments on
[#234](https://github.com/joshbotts/FRUS-Explorer/issues/234): the FRUS volumes whose editors
published **no list of persons**, which is where the People browser, person search, person
analytics, and the co-mention graph currently see nothing at all.

This is the sibling of `README.md` (the embeddings harvest) and executes stage **R-1** of
`Planning/M2-Semantic-Pipeline-Ride-Along.md` §3. It replaces that file's placeholder line — *"the
NER pass gets its own harness in this folder once the spike numbers and the M2a ground-truth sample
exist"* — for the half that is now true: the spike numbers exist
(`Planning/semantic-spike/V0-Spike-Verdict.md`). **M2a does not.** What that means for what you may
do with the output is the first section below, because it is the only rule in this file that cannot
be worked around.

---

## 0. What this harvest is, and what it is not

**It is a candidate harvest.** Per the ride-along's seam (§2, "Does not ride", item 1): running a
detection pass to *produce* candidates is harvest; nothing derived from it may enter a shipped
artifact until the M2a prose ground truth exists and has scored it. That rule is inherited from the
archived wave plan and restated in `Planning/People-Early-Era-Program.md` §5, and it is not a
formality — **a confidently-wrong person is this app's most serious defect class**, and #259 was
closed not-planned for proposing merges that would have undone the guardrails an audit installed.

So: run every phase here whenever you like. Publish nothing from it until §5 is satisfied.

**It detects spans, not people.** This pass answers "where in the text is a person named". It does
not decide *which* person, does not merge, does not mint an identity, and does not touch the
`person_rollup` machinery. Identity is R-3, behind the synthetic-ref namespace and force-merge-only
rules.

---

## 1. The corpus, measured

Every figure sourced; nothing here is re-derived by this runbook.

| | | source |
|---|---|---|
| volumes with no editor person list | **268** (app view) / **267** (TEI rule) | Program doc §1; M1a-Findings "Reconciling two volume counts" |
| documents in them | **199,246 — 62.9% of the corpus** | Program doc §1 |
| of those, pre-1930 | 82,862 | Program doc §1 |
| body text in scope | 705 M chars ≈ **~176 M tokens** (51.3% of corpus tokens) | Ride-along §1 |
| `<persName>` elements already marked | **253,919** — 141,064 `from`, 95,837 `to`, 17,018 untyped | Program doc §3 |
| of those, carrying a link to any identity | **0** | Program doc §3 |
| distinct name strings / appearing 5+ times | 13,914 / 3,253 | Program doc §3 |
| **share of person mentions that carry markup** | **~34% pooled**; 66.0% best volume, **12.4% worst**, degrading after 1946 | M1a-Findings |
| POCOM constraint on `from`/`to` names | 83.2% surname-known, 63.9% unique-by-year *(a ceiling, not a precision)* | M1a-Findings |

The 268-vs-267 gap is exactly three volumes and each is a known defect: `frus1873p1v1` and
`frus1873p1v2` carry a real 57-entry list under `xml:id="correspondents"` that
`FRUSDocumentParser.structuralKind` does not read, and `frus1941-43` has no list but contributes 77
back-of-book subject-index headings to the People browser as if they were people. **This harvest
uses the TEI rule (267)** — it should look at what the TEI has, not at what the app currently shows.
Fixing the two parser defects is worth doing and is not part of this runbook.

The markup row is why this file exists at all. M1a overturned the program's original reading: the
editors mark up the correspondence apparatus and leave the body prose alone, so roughly two-thirds
of person mentions in these volumes are unmarked and **detection is required, not optional**.

---

## 2. The two layers, and why one of them is free

One pass of each volume's TEI produces both:

* **The marked layer** — the 253,919 `<persName>` elements the editors already delimit, placed in
  the R-0 text layer's coordinate space. No model, no server, no LM Studio, no cost. This is M1b's
  input, and it is worth having on disk whatever happens to the detector question.
* **The detected layer** — candidates from an LM Studio chat model over the same text, grounded by
  exact-substring location. Optional, priced sample-first (§4).

Both come out of `harvest_ner.py`, which is stdlib-only like its sibling and runs on the stock macOS
`python3`. It **imports** `harvest_embeddings.py` rather than copying its extractor, and asserts per
volume that its own `(doc_id, ordinal, text)` list equals `extract_documents`'. A volume that
disagrees aborts the run instead of writing offsets that mean something slightly different from the
embeddings' text layer — the cross-source-join failure class this repo keeps re-learning.

Verify the harness before trusting it with machine time, exactly as the embeddings harvester was
verified against a mock server:

```
cd tools/semantic-harvest && SELFTEST=1 python3 harvest_ner.py
```

23 checks, no corpus and no server needed: R-0 parity, `<persName>` offsets surviving a nested tag
and a line break, the scope rule, hallucination grounding, overlap de-duplication, resume,
byte-stable gzip, and the refusal in §4.3.

---

## 3. Phases N-0 and N-1 — scope and the marked layer (free)

Inputs, same as the embeddings runbook: a copy of `Development/frus/volumes/` at `~/frus-volumes`,
and a copy of `FRUSExplorer/Resources/manifest.json` beside the script.

```
cd ~/semantic-harvest                      # wherever the two scripts live
SCOPE_ONLY=1 python3 harvest_ner.py        # N-0: derive scope.json, stop
python3 harvest_ner.py                     # N-1: the marked layer over that scope
```

**N-0 self-check: it must print 267.** The rule is m1a_survey.py's — a volume is in scope iff its
TEI defines no `<persName xml:id=…>` anywhere. A different number means the corpus copy or the rule
has moved since 2026-08-07, and the script says so on the same line. Investigate before harvesting;
a scope that silently grew is a harvest of the wrong corpus.

**N-1 expectation: ~253,919 rows** across the scope, split ~141,064 / ~95,837 / ~17,018 by
`from` / `to` / untyped, and **zero** carrying a `corresp`. N-0 reads all 552 volumes (3.34 GB) once
to derive the scope and caches the answer in `scope.json`; N-1 re-reads only the 267 in it. No model
is in the loop for either, and the printed chars/s and per-volume timing tell you the real clock
within the first volume. Interruptions are fine — a completed volume is skipped on re-run.

If the marked totals come out far from those figures, stop and reconcile before going further: they
are the one part of this program that is already measured, so they are the cheapest possible check
that the pass is reading what M1a read.

---

## 4. Phase N-2 — the detector pilot

### 4.1 Why a pilot and not a sweep

The arithmetic, using the ride-along §4.4 convention (8B-class chat model on the M1 Max Studio at
**~350–600 tok/s aggregate**) and the corpus's measured 4.16 chars/token:

| | |
|---|---|
| scope text | 705 M chars ≈ 176 M tokens |
| chunks at 3200 chars / 480 overlap | ~230–260 k (mean document is ~3,540 chars, so most are one chunk) |
| system prompt re-sent per chunk | ~190 tokens ⇒ **+~28%** on input |
| total through the model | ~225 M input + ~16 M generated ≈ **240 M tokens** |
| **wall-clock, continuous** | **~5–8 days** |

That is the same tier the ride-along assigned to the *adversarial review* (7–12 days), not to the
overnight band the embedding pass occupies — and it would be spent before any ground truth exists to
say whether the output is worth having. Against it, the same section prices Apple `NLTagger` over
the same scope at **~1–2 h**: a 60–100× difference in cost that no leaderboard can settle for
19th-century diplomatic prose, which is far from every NER model's training distribution.

So the LM-Studio route is measured on a sample first, which is also what
`Planning/People-Early-Era-Program.md` §5 requires of the whole program ("pilot before corpus").

### 4.2 Running the pilot

Load **one chat model** in LM Studio (server tab, server on 1234) and copy its id exactly from
`curl -s localhost:1234/v1/models` — the harvester refuses an unlisted id, because LM Studio routes
an unknown id to whatever model is loaded, which "works" while writing a fictional model into
provenance (measured on the embedding spike, 2026-08-10).

The pilot volumes are M1a's twelve — the same era-stratified sample every existing measurement in
this program was taken on, and the sample the M2a ground truth will be drawn from:

```
cd ~/semantic-harvest
DETECT=llm \
VOLUMES=frus1872p1,frus1867p2,frus1895p1,frus1904,frus1924v02,frus1929v02,frus1942v05,frus1937v02,frus1938v01,frus1948v05p2,frus1948v06,frus1949v06 \
SAMPLE_DOCS=40 \
MODEL="<id from /v1/models>" \
MODEL_FILE="/path/to/the/loaded.gguf" \
OUT_DIR=~/frus-ner-raw-pilot-<model> \
caffeinate -i python3 harvest_ner.py 2>&1 | tee ner-pilot-<model>.log
```

480 documents ≈ 600–700 chunks: **well under an hour**, and the closing line replaces that estimate
with a measurement. `SAMPLE_DOCS` picks deterministically from `(SEED, volume id)`, so two models
scored against each other see the *same* documents. Repeat with a fresh `OUT_DIR` per model; keep
`SAMPLE_DOCS` and `SEED` identical across them or the comparison is not one.

`MODEL_FILE` pins the GGUF's SHA-256 into provenance. The embedding spike captured it for only one
of five stores and the V-0 verdict lists that as the gap to close; do not repeat it here.

**Model choice is still an open owner decision** (ride-along §6.4: "detector shortlist sign-off").
What the harness needs of a candidate: it must be a *chat* model, it should honour
`response_format: json_schema` (the harness tolerates a bare JSON object and counts the failures if
not), and it should sit in the 7–14 B band the cost table above assumes. Two or three, scored on the
same sample, and the numbers decide.

### 4.3 The refusal

`DETECT=llm` over the whole derived scope with no sampling exits rather than running:

```
Refusing an unsampled LLM sweep over the whole scope: NER-RUNBOOK.md prices it at days of
continuous Studio time, and no ground truth exists to score it.
```

`FULL_SWEEP=1` overrides it. §5 is what should be true before you type that.

### 4.4 What to read in the output

Per volume, `detected/<vol>.head.json`:

| field | what it tells you |
|---|---|
| `mentions`, `novel`, `overlapping_marked` | how much the model adds beyond the editors' markup. M1a predicts roughly two unmarked mentions per marked one; a run where `novel` is near zero has found nothing the marked layer did not. |
| `unlocated`, `unlocated_examples` | **the grounding signal.** A name the model returns that does not occur verbatim in the passage it was shown is stored nowhere and counted here. A high rate means the model is normalising or inventing; read the examples, they say which. |
| `truncated`, `unparsable` | schema adherence. Non-zero `truncated` means `MAX_TOKENS` is clipping a dense passage. |
| `prompt_tokens`, `completion_tokens`, `secs` | the real cost per chunk, which is what re-prices §4.1 for the model you actually ran. |

Read a few dozen rows by hand as well — `unlocated_examples` catches invention, but only reading the
kept rows catches the opposite failure, a model returning place names and ship names with perfect
grounding. That is the same habit that caught the two `Ibid.` defects in #784: the sample is the
review artifact.

### 4.5 What the detector route cannot do, stated up front

* **It is asked for distinct surface strings, not spans.** The harness locates every occurrence of
  each returned string, which cuts output tokens by an order of magnitude — but a surface the model
  names once is then found everywhere it occurs, and a surface it omits is missed everywhere. Recall
  is measured per mention; the model's job is per string.
* **`temperature=0` is not determinism.** Batching and cache state can move a local model's output
  between runs. Provenance pins the prompt, the schema, the decoding parameters, the model id and
  the GGUF SHA — it does not pin the outputs. Any figure quoted from this store must name the run
  that produced it.
* **A chunk carries no volume context.** The model sees ~800 tokens and nothing about the volume,
  the date, or the correspondents.
* **No roles, no dates, no identities.** Those are R-2/R-3, and POCOM's 63.9% unique-by-year is
  their prior, not this pass's.

---

## 5. Phase N-3 onward — what closes R-1, and what is not built

**The gate: M2a is un-keyed.** The ride-along §3 defines it — extend `m1a_survey.py` to sample
~60–80 documents, era-stratified, for *exhaustive* person-mention annotation (~900–1,200 decisions),
keyed by the owner alongside the M1a 300 rows that are also still un-keyed. Until that exists, every
number in §4.4 is descriptive (how much did it find, how grounded was it) and none is evaluative
(was it right). Precision and recall are simply unavailable. This runbook cannot route around that
and does not try.

**The control detector is not built.** Apple `NLTagger` over the same scope is the ~1–2 h baseline
every LLM result should be read against, and the app already runs it corpus-wide for word clouds
(`WordCloudKit`). It needs a small Swift harness — an SPM executable reading the same scope and
writing the same `detected/` shape — which is real work and is deliberately not in this runbook.
Without it, a pilot can tell you a model found things; it cannot tell you the model beat the free
option.

**R-2 (mention-context embeddings) needs the embeddings store**, which does not exist yet: the
sibling runbook's Phase 3 has not run, and V-0 is not closed until the owner grades all 100 rows of
`Planning/semantic-spike/blind-panel.csv` (before opening the key) and reads the Gemma licence.

Sequencing consequence, and it is practical rather than theoretical: **do not run N-2 in the same
window as the embeddings harvest.** LM Studio would have to hold a chat model and an embedding model
at once, and the embedding pass is the priority — R-2 depends on it, and its ~6.1 h run is the one
with a measured ETA. N-0 and N-1 need no server at all and can run any time, including while the
Studio is embedding, since they are a disk read.

**The store is offsets-only, by design.** It does not copy the 705 MB of text: the text exists in
the TEI, and after Phase 3 it exists again as the semantic store's R-0 layer. A consumer re-derives
it with `harvest_embeddings.extract_documents`, and the per-volume parity assert is exactly what
makes that safe.

---

## 6. The store contract

```
frus-ner-raw/
  scope.json                  # the derived scope: rule, counts, the volume list
  marked/<vol>.jsonl.gz       # {"d","o","s","e","n","t","x","c"} per <persName>
  marked/<vol>.head.json      # done-marker + per-volume counts (written last)
  detected/<vol>.jsonl.gz     # {"d","o","s","e","n","ci"} per located candidate
  detected/<vol>.head.json    # done-marker + the §4.4 numbers
  runs.jsonl                  # per-volume log, append-only across resumes
  run-manifest.json           # provenance: both script SHAs, model id + listing, GGUF SHA,
                              # system prompt, response schema, temperature, chunking, seed
  SHA256SUMS                  # transfer integrity
```

`d`/`o` are the document's `xml:id` and its ordinal in the volume; `s`/`e` are **character offsets
into the R-0 text of that document**, half-open; `n` is the substring they cut (stored so a row is
readable on its own and so any consumer can check itself); `t`/`x`/`c` are the `type`, `xml:id` and
`corresp`/`ref` attributes when present. gzip members are written with `mtime=0`, so re-running over
the same input yields byte-identical files — the V-0 spike found gzip mtime to be the *only*
difference between five otherwise-identical text layers, and that noise is now gone.

Transfer, if the harvest ran on the Studio and the analysis happens on the Air, is the embeddings
runbook's Phase 4 unchanged: copy or `rsync` the store, then `cd <store> && shasum -a 256 -c
SHA256SUMS`, and every line must say `OK`. An unverified transfer is not a raw store.

---

## 7. Environment reference

| variable | default | note |
|---|---|---|
| `VOLUMES_DIR` | `~/frus-volumes` | a copy of `Development/frus/volumes` |
| `MANIFEST` | `./manifest.json` | copy it next to the script |
| `OUT_DIR` | `~/frus-ner-raw` | one store per detector run |
| `SCOPE_ONLY` | — | `=1` derives `scope.json` and stops |
| `VOLUMES` | — | explicit ids, overriding the derived scope |
| `DETECT` | `none` | `llm` adds the detector layer |
| `SAMPLE_DOCS` | `0` (all) | documents per volume, chosen from `(SEED, volume id)` |
| `SEED` | `234` | m1a_survey.py's seed; keep it fixed across compared runs |
| `FULL_SWEEP` | — | `=1` to override §4.3 |
| `MODEL` / `MODEL_FILE` | — | required for `DETECT=llm`; never auto-picked |
| `CHUNK_CHARS` / `OVERLAP_CHARS` | 3200 / 480 | the embeddings' chunk shape |
| `MAX_TOKENS` / `TEMPERATURE` | 1024 / 0 | recorded in provenance |
| `BATCH_SLEEP` | 0 | seconds between requests, for thermal headroom on the Air |

## 8. Related

- `Planning/People-Early-Era-Program.md` — the program, its gates, and the constraints in §5
- `Planning/early-era-people/M1a-Findings.md` — where §1's markup and POCOM figures come from
- `Planning/M2-Semantic-Pipeline-Ride-Along.md` — the stage list (R-0…R-4) and the cost model
- `Planning/semantic-spike/V0-Spike-Verdict.md` — the spike this runbook's sibling is waiting on
- `README.md` — the embeddings harvest, whose extractor and store discipline this reuses

Version history:
  1.0 — 2026-08-11: initial runbook. Scope + marked layer + sampled detector pilot, with the
        full-sweep arithmetic that argues against scheduling one, and the M2a gate restated as
        the thing no phase here can route around.
