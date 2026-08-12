# Early-era NER harvest runbook — R-1 over the no-list volumes (#234)

The corpus this covers is the one described in the comments on
[#234](https://github.com/joshbotts/FRUS-Explorer/issues/234): the FRUS volumes whose editors
published **no list of persons**, which is where the People browser, person search, person
analytics, and the co-mention graph currently see nothing at all.

This is the sibling of `README.md` (the embeddings harvest) and executes stage **R-1** of
`Planning/M2-Semantic-Pipeline-Ride-Along.md` §3. It replaces that file's placeholder line — *"the
NER pass gets its own harness in this folder once the spike numbers and the M2a ground-truth sample
exist"*. The spike numbers exist (`Planning/semantic-spike/V0-Spike-Verdict.md`), the harness is
here, the free control detector is built (§5), and M2a can now be staged, collected and scored
(§6–7) — but **M2a is not keyed**, and until it is, everything this produces is descriptive.
What that means for what you may do with the output is the first section below, because it is the
only rule in this file that cannot be worked around.

---

## 0. What this harvest is, and what it is not

**It is a candidate harvest.** Per the ride-along's seam (§2, "Does not ride", item 1): running a
detection pass to *produce* candidates is harvest; nothing derived from it may enter a shipped
artifact until the M2a prose ground truth exists and has scored it. That rule is inherited from the
archived wave plan and restated in `Planning/People-Early-Era-Program.md` §5, and it is not a
formality — **a confidently-wrong person is this app's most serious defect class**, and #259 was
closed not-planned for proposing merges that would have undone the guardrails an audit installed.

So: run every phase here whenever you like. Publish nothing from it until §6 has been keyed and §7 has scored it.

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
* **The detected layer** — candidates over the same text, from either of two detectors that write
  the same shape into their own stores: an LM Studio chat model (§4, priced sample-first, grounded
  by exact-substring location) or the free `NLTagger` control (§5).

Set **`TEXT_DIR`** to the embeddings store's `text/` on both: every volume's extracted text is then
checked character for character against the R-0 layer the vectors were computed from, which is what
makes a mention offset and a chunk span the same coordinate (§8).

The scope and marked layers come out of `harvest_ner.py`, which is stdlib-only like its sibling and runs on the stock macOS
`python3`. It **imports** `harvest_embeddings.py` rather than copying its extractor, and asserts per
volume that its own `(doc_id, ordinal, text)` list equals `extract_documents`'. A volume that
disagrees aborts the run instead of writing offsets that mean something slightly different from the
embeddings' text layer — the cross-source-join failure class this repo keeps re-learning.

Verify the harness before trusting it with machine time, exactly as the embeddings harvester was
verified against a mock server:

```
cd tools/semantic-harvest && SELFTEST=1 python3 harvest_ner.py
```

26 checks, no corpus and no server needed: R-0 parity, the R-0 *store* check below, `<persName>`
offsets surviving a nested tag and a line break, the scope rule, hallucination grounding, overlap
de-duplication, resume, byte-stable gzip, and the refusal in §4.4.

---

## 3. Phases N-0 and N-1 — scope and the marked layer (free)

Inputs, same as the embeddings runbook: a copy of `Development/frus/volumes/` at `~/frus-volumes`,
and a copy of `FRUSExplorer/Resources/manifest.json` beside the script.

```
cd ~/semantic-harvest                      # wherever the two scripts live
export TEXT_DIR=~/frus-semantic-raw/text   # the R-0 layer Phase 3 wrote; see §8
SCOPE_ONLY=1 python3 harvest_ner.py        # N-0: derive scope.json, stop
python3 harvest_ner.py                     # N-1: the marked layer over that scope
```

(On the Air, `TEXT_DIR` is wherever Phase 4 put the transferred store — `~/Development/frus-semantic-raw/text`.)

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

### 4.1 The token count, which no hardware choice changes

| | |
|---|---|
| scope text | 705 M chars ≈ 176 M tokens (at the corpus's measured 4.16 chars/token) |
| chunks at 3200 chars / 480 overlap | ~230–260 k (mean document is ~3,540 chars, so most are one chunk) |
| system prompt re-sent per chunk | ~191 tokens ⇒ **+~26%** on input |
| total through the model | ~225 M input + ~16 M generated ≈ **240 M tokens** |

**94% of that is prompt processing, not generation** — which matters more than it looks, because
those are different rates on Apple silicon. Decode is memory-bandwidth-bound and slow per token;
prefill is compute-bound and batched. The ride-along's §4.4 figure (**~350–600 tok/s** for an
8B-class model on the M1 Max Studio) is a single aggregate over a total, and for a workload this
prefill-heavy it behaves like a prefill rate. Everything below inherits that assumption, and the
pilot is what replaces it with a measurement.

### 4.2 Model size and machine, derived

Prefill cost is roughly linear in parameters, so the model band is the dominant lever — far larger
than the choice of machine. Scaled from the 8B anchor above, against the 240 M tokens:

| model band | est. tok/s, Studio | Studio wall-clock | **M5 Air**, 1.0–2.0× |
|---|---|---|---|
| 7–8B | 350–600 | 4.6–7.9 days | 4.6–16 days |
| 3–4B | 700–1,300 | 2.1–4.0 days | 2.1–8 days |
| **1.5–2B** | 1,600–2,700 | **25–42 h** | **25–84 h** |
| **0.5–0.6B** | 4,500–8,000 | **8–15 h** | **8–30 h** |

> **Every cell here is derived, none is measured.** The V-0 spike measured *embedding* throughput,
> on the Studio only, and the ride-along's Air-side questions were left open by owner decision. Two
> of them apply directly: whether llama.cpp under LM Studio drives the M5's per-core Neural
> Accelerators at all (§5.1 of the ride-along says MLX does and llama.cpp may not, which is why the
> Air band runs to 2×), and the fanless throttle on multi-hour loads (§4.0). The one thing that
> favours the Air here is the same argument §4.0 makes for encoders: its real deficit against the
> Studio is memory bandwidth (153 vs 400 GB/s), which bites *decode*, and this workload barely
> decodes. The throttle penalty grows with run length, which is an argument for several resumable
> evening runs over one continuous multi-day one — the shape the harness already has.

**So the assessment does change with the model band, and the change is real: a ≤2 B model moves the
full sweep out of the multi-day tier and into one or two overnight runs on the Air.** That is a
schedulable job in a way the 8B figure never was.

Three things it does not change, and one it makes worse:

1. **Sample first anyway** — now more cheaply than before. At 1.5 B the §4.3 pilot is minutes, not
   an hour, so there is even less reason to skip it.
2. **Nothing ships without M2a** (§0, §5). A cheap sweep produces cheap candidates, not measured
   ones.
3. **`Planning/People-Early-Era-Program.md` §5's "pilot before corpus"** is a program constraint,
   not a budget one.
4. **The case against the free control gets weaker, not stronger.** Quality is the entire reason to
   prefer an LLM over Apple `NLTagger`, and quality is exactly what degrades as the model shrinks —
   schema adherence, hallucination, and the discipline to copy a name verbatim rather than normalise
   it. At 8B the LLM route cost 60–100× NLTagger's ~1–2 h, so "is it better?" was a question about
   quality at a large price. At 0.5–2 B the gap narrows to roughly 5–20×, and **a small model that
   merely ties NLTagger has no reason to exist.** Today nothing can tell you which it is, because
   the control is not built (§5). If a small-model sweep on the Air is the plan, build the control
   first — it is the cheaper half of the comparison and the one that makes the other half mean
   something.

Two levers left unmeasured, both worth checking before a sweep: whether your LM Studio build serves
**concurrent** requests (on prompts this short, concurrency is likely the largest remaining
throughput factor — the harness sends one chunk at a time and would need a change to exploit it),
and whether the plan's own **tiering** logic (§4.4 of the ride-along, written for review) applies to
detection: a cheap model everywhere, a larger one over the uncertain band only.

### 4.3 Running the pilot

Load **one chat model** in LM Studio (server tab, server on 1234) and copy its id exactly from
`curl -s localhost:1234/v1/models` — the harvester refuses an unlisted id, because LM Studio routes
an unknown id to whatever model is loaded, which "works" while writing a fictional model into
provenance (measured on the embedding spike, 2026-08-10).

The pilot volumes are M1a's twelve — the same era-stratified sample every existing measurement in
this program was taken on, and the sample the M2a ground truth will be drawn from:

```
cd ~/semantic-harvest
DETECT=llm \
TEXT_DIR=~/frus-semantic-raw/text \
VOLUMES=frus1872p1,frus1867p2,frus1895p1,frus1904,frus1924v02,frus1929v02,frus1942v05,frus1937v02,frus1938v01,frus1948v05p2,frus1948v06,frus1949v06 \
SAMPLE_DOCS=40 \
MODEL="<id from /v1/models>" \
MODEL_FILE="/path/to/the/loaded.gguf" \
OUT_DIR=~/frus-ner-raw-pilot-<model> \
caffeinate -i python3 harvest_ner.py 2>&1 | tee ner-pilot-<model>.log
```

480 documents ≈ 600–700 chunks: **well under an hour** for an 8B-class model, and minutes for the
≤2 B band §4.2 is really about — either way the closing line replaces the estimate with a
measurement, which is the whole point of running it. `SAMPLE_DOCS` picks deterministically from `(SEED, volume id)`, so two models
scored against each other see the *same* documents. Repeat with a fresh `OUT_DIR` per model; keep
`SAMPLE_DOCS` and `SEED` identical across them or the comparison is not one.

`MODEL_FILE` pins the GGUF's SHA-256 into provenance. The embedding spike captured it for only one
of five stores and the V-0 verdict lists that as the gap to close; do not repeat it here.

On the **Air**, add `BATCH_SLEEP` if a longer run is throttling (it inserts a pause between
requests, trading throughput for sustained clock), and prefer several resumable evening runs to one
continuous one — a completed volume is skipped on re-run, so stopping costs at most the volume in
flight.

**Model choice is still an open owner decision** (ride-along §6.4: "detector shortlist sign-off").
What the harness needs of a candidate: it must be a *chat* model, it should honour
`response_format: json_schema` (the harness tolerates a bare JSON object and counts the failures if
not), and it should sit in the 7–14 B band the cost table above assumes. Two or three, scored on the
same sample, and the numbers decide.

### 4.4 The refusal

`DETECT=llm` over the whole derived scope with no sampling exits rather than running:

```
Refusing an unsampled LLM sweep over the whole scope: NER-RUNBOOK.md prices it at days of
continuous Studio time, and no ground truth exists to score it.
```

`FULL_SWEEP=1` overrides it. §4.2's fourth point, plus a keyed §6 and a §7 table with the control in it, are what should be true before you type that.

### 4.5 What to read in the output

Per volume, `detected/<vol>.head.json`:

| field | what it tells you |
|---|---|
| `mentions`, `novel`, `overlapping_marked` | how much the model adds beyond the editors' markup. M1a predicts roughly two unmarked mentions per marked one; a run where `novel` is near zero has found nothing the marked layer did not. |
| `unlocated`, `unlocated_examples` | **the grounding signal.** A name the model returns that does not occur verbatim in the passage it was shown is stored nowhere and counted here. A high rate means the model is normalising or inventing; read the examples, they say which. |
| `truncated`, `unparsable` | schema adherence. Non-zero `truncated` means `MAX_TOKENS` is clipping a dense passage. |
| `prompt_tokens`, `completion_tokens`, `secs` | the real cost per chunk, which is what replaces §4.1's assumption and §4.2's table with a measurement for the model you actually ran. |

Read a few dozen rows by hand as well — `unlocated_examples` catches invention, but only reading the
kept rows catches the opposite failure, a model returning place names and ship names with perfect
grounding. That is the same habit that caught the two `Ibid.` defects in #784: the sample is the
review artifact.

### 4.6 What the detector route cannot do, stated up front

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

## 5. Phase N-3 — the control detector

**Built** (`swift run -c release EarlyEraNERControl`, SPM-only, no `xcodegen`). It is the ~1–2 h
free baseline §4.2 argues every LLM run has to beat, and it exists so that argument can be checked
rather than asserted.

```
swift run -c release EarlyEraNERControl        # from the repo root
```

with, as needed:

| variable | |
|---|---|
| `STORE` | the NER store with `scope.json` + `marked/` (default `~/frus-ner-raw`) |
| `TEXT_DIR` | the embeddings store's `text/` (default `~/frus-semantic-raw/text`) |
| `OUT_DIR` | its own store (default `~/frus-ner-raw-control`) |
| `ONLY_DOCUMENTS` | an `m2a-ground-truth.jsonl` — restricts the pass to the annotated documents, which is what makes it scoreable in minutes rather than hours |
| `LANGUAGE` | `english` (default, matching `WordCloudKit`) or `auto` |

It reads the **R-0 text layer, not the TEI**, so its offsets are the marked layer's offsets by
construction; it runs Apple's `NLTagger` with the same walk the app already runs corpus-wide for
word clouds; and it writes the same `detected/` shape `harvest_ner.py` writes — uncompressed
`.jsonl`, which `ner_store.py` reads either way — so `score_detections.py` scores it beside the
LLM stores with no adapter.

Three things to know before quoting its numbers:

* **`NLTagger`'s output is a property of the OS build.** Every `head.json` and the run manifest
  record `operatingSystemVersionString`. Two stores from different machines are not comparable, and
  nothing else in the pipeline would tell you.
* **`detected/*.jsonl` is byte-identical across runs on one build; the head files are not** — they
  carry `secs` and the date stamp. Diff the rows, not the heads, when checking for drift.
* **It is a control, not a candidate.** It has no confidence, no identity, no roles; it answers
  only "where in the text is a person named", which is exactly the question the LLM route answers,
  which is what makes them comparable.

---

## 6. Phase N-4 — the M2a ground truth (the gate)

Nothing above can be *scored* until a human has marked every person mention in a stratified sample.
That was the ride-along's M2a, and it is now two mechanical halves around one irreducible sitting.

```
cd tools/semantic-harvest
SELFTEST=1 python3 stage_m2a.py            # 30 checks, no corpus needed — run this first
python3 stage_m2a.py                       # stage ~72 documents, era-stratified
#   ... the sitting: read M2a-INSTRUCTIONS.md in the output directory, annotate,
#       and mark each finished file `y` in progress.csv ...
COLLECT=1 python3 stage_m2a.py             # -> m2a-ground-truth.jsonl + a summary
```

**Annotation is by editing text, not by typing offsets.** Each document is written out as its exact
R-0 text with the editors' own `<persName>` mentions already wrapped in `⟦…⟧`; you wrap the ones
they left unmarked. Three properties make that safe, and each is pinned by the self-test:

* offsets are *derived* by removing the brackets, so an annotation lands in exactly the coordinate
  space the detectors and the chunk vectors use — there is no way to type a wrong number;
* the collector strips the brackets and requires the result to equal the R-0 text character for
  character, so an accidental edit to the prose is **rejected by name** instead of silently shifting
  every later span in that document;
* seeding with the editors' markup cuts the work by about a third and makes disagreement visible —
  a removed `⟦…⟧` is recorded as a rejected editor span, and that count is the only evidence anyone
  checked them rather than trusting them.

The collector refuses a `y` on a file that is **byte-identical to what was staged**: an untouched
document would otherwise collect the editors' own seed as ground truth and report the markup share
as 100%, which is a measurement of nothing phrased as the real one. If you read a document and
there is genuinely nothing to add, mark it `none`. It also refuses a duplicated `progress.csv` row,
a row naming a file that is no longer there, a stray or nested bracket, and re-staging over a
directory that already holds annotated work (`FORCE=1` if you mean it).

The seeding has a cost and the script says so: it biases an annotator toward accepting editor
markup. The instructions ask for each seeded span to be checked; `editor_spans_rejected` in the
collection summary is what shows it happened.

The collector also produces a number this program has wanted since M1a: the **measured markup
share**, seeded-kept over total. M1a's ~34% came from a bare-surname regex over de-tagged text and
called itself a lower bound. This is the real measurement, on a proper exhaustive sample, per band.

## 7. Phase N-5 — scoring

```
GROUND_TRUTH=~/frus-m2a/m2a-ground-truth.jsonl \
DETECTORS=~/frus-ner-raw-pilot-<model>,~/frus-ner-raw-control \
python3 score_detections.py
```

One table, one row per detector, plus **the editors' own markup scored as if it were a detector** —
its recall is the share of mentions the free layer already gives you, and it is the number that
says what detection is *for*. Two matching rules, and neither is the real one alone: **strict**
(exact span — what matters for anything that will later slice text by offset) and **relaxed** (a
maximum-cardinality one-to-one matching over any overlap — whether the detector found the *mention*
while disagreeing about where a title ends, the commonest boundary quarrel in this corpus).

What the scorer refuses to do, in each case because the alternative is a wrong number rather than
an error:

* it **verifies the ground truth against the R-0 text before reading any detector** — a gold file
  staged against an older copy of the corpus still parses and would score a perfect detector as a
  total failure;
* it scores a detector **only over documents it actually scanned**, and refuses a store that sampled
  without recording which (or whose run was killed mid-volume, leaving a body with no head);
* it refuses to run at all when `STORE` has no `marked/` layer, because the baseline row would
  otherwise read 0.000 recall and look like a finding.

Read `score-detections.json` afterwards for the per-band breakdown and, more usefully, the false
positives and misses it samples — a detector with good aggregate numbers and place names in its
false-positive list is telling you something the aggregate cannot.

---

## 8. The store contract

```
frus-ner-raw/                 # harvest_ner.py: the scope and the free marked layer
  scope.json                  # the derived scope: rule, counts, the volume list
  marked/<vol>.jsonl.gz       # {"d","o","s","e","n","t","x","c"} per <persName>
  marked/<vol>.head.json      # done-marker + per-volume counts (written last)
  detected/<vol>.jsonl.gz     # {"d","o","s","e","n","ci"} per located candidate
  detected/<vol>.head.json    # done-marker + the §4.5 numbers, incl. sampled_doc_ids
  runs.jsonl                  # per-volume log, append-only across resumes
  run-manifest.json           # provenance: both script SHAs, model id + listing, GGUF SHA,
                              # system prompt, response schema, temperature, chunking, seed
  SHA256SUMS                  # transfer integrity

frus-ner-raw-control/         # EarlyEraNERControl: one store per detector, same shape
  detected/<vol>.jsonl        # UNCOMPRESSED — nothing in the Swift repo speaks gzip, and
                              # ner_store.py reads either extension (it refuses when BOTH
                              # exist for one volume, since the two readers preferred
                              # opposite orders and a stale copy would score differently)
  detected/<vol>.head.json    # + the OS build, because NLTagger's output is a property of it
  run-manifest.json           # totals re-derived from every head.json, so a resumed run
                              # reports what a single run would

frus-m2a/                     # stage_m2a.py: the ground truth
  <vol>__<doc>.txt            # the R-0 text with mentions wrapped in ⟦…⟧
  progress.csv                # the owner marks each finished file `y`
  m2a-manifest.json           # per document: band, char count, text SHA-256, seeded spans
  M2a-INSTRUCTIONS.md         # the annotation rule, matching the detector prompt's definition
  m2a-ground-truth.jsonl      # COLLECT=1 output: {"v","d","s","e","n","seeded","band"}
  m2a-collection-summary.json # incl. the measured markup share, per band
```

`d`/`o` are the document's `xml:id` and its ordinal in the volume; `s`/`e` are **Unicode code-point
offsets into the R-0 text of that document**, half-open — not bytes, not characters in the Swift
sense, and not offsets into the TEI. Every producer here is Python except the control, which is why
that detector's offset arithmetic is a separately tested function rather than inline: code points,
grapheme clusters and UTF-16 units all agree on ASCII, which is exactly what would make the bug
invisible. `n` is the substring they cut (stored so a row is readable on its own and so
any consumer can check itself); `t`/`x`/`c` are the `type`, `xml:id` and
`corresp`/`ref` attributes when present. gzip members are written with `mtime=0`, so re-running over
the same input yields byte-identical files — the V-0 spike found gzip mtime to be the *only*
difference between five otherwise-identical text layers, and that noise is now gone.

**Why `TEXT_DIR` matters more than it looks.** The per-volume parity assert against
`extract_documents` catches a divergence in the *code*; pointing `TEXT_DIR` at the embeddings
store's `text/` catches one in the *corpus*, which is the failure that would actually happen. R-2
embeds a context window around each mention against chunk vectors computed from the stored text, so
if the TEI on disk has moved since Phase 3 these offsets address a document those vectors never saw
and nothing downstream could tell. A mismatch aborts naming the volume and the first differing
ordinal; a missing file aborts too, because the value of the check is that it ran.

Transfer, if the harvest ran on the Studio and the analysis happens on the Air, is the embeddings
runbook's Phase 4 unchanged: copy or `rsync` the store, then `cd <store> && shasum -a 256 -c
SHA256SUMS`, and every line must say `OK`. An unverified transfer is not a raw store.

---

## 9. Environment reference

| variable | default | note |
|---|---|---|
| `VOLUMES_DIR` | `~/frus-volumes` | a copy of `Development/frus/volumes` |
| `MANIFEST` | `./manifest.json` | copy it next to the script |
| `OUT_DIR` | `~/frus-ner-raw` | one store per detector run |
| `TEXT_DIR` | — | the embeddings store's `text/`; verifies every volume against the R-0 layer (§8) |
| `SCOPE_ONLY` | — | `=1` derives `scope.json` and stops |
| `VOLUMES` | — | explicit ids, overriding the derived scope |
| `DETECT` | `none` | `llm` adds the detector layer |
| `SAMPLE_DOCS` | `0` (all) | documents per volume, chosen from `(SEED, volume id)` |
| `SEED` | `234` | m1a_survey.py's seed; keep it fixed across compared runs |
| `FULL_SWEEP` | — | `=1` to override §4.4 |
| `MODEL` / `MODEL_FILE` | — | required for `DETECT=llm`; never auto-picked |
| `CHUNK_CHARS` / `OVERLAP_CHARS` | 3200 / 480 | the embeddings' chunk shape |
| `MAX_TOKENS` / `TEMPERATURE` | 1024 / 0 | recorded in provenance |
| `BATCH_SLEEP` | 0 | seconds between requests, for thermal headroom on the Air |

`EarlyEraNERControl` (§5) takes `STORE`, `TEXT_DIR`, `OUT_DIR`, `VOLUMES`, `ONLY_DOCUMENTS`,
`LANGUAGE`, `GENERATED_DATE`. `stage_m2a.py` (§6) takes `STORE`, `TEXT_DIR`, `OUT_DIR`, `DOCS` (72),
`VOLS_PER_BAND` (6), `MIN_CHARS`/`MAX_CHARS` (800/8000 — a stated sampling bias: it excludes both
the stubs and the long editorial notes), `SEED`, `COLLECT`. `score_detections.py` (§7) takes
`GROUND_TRUTH`, `DETECTORS`, `STORE`, `TEXT_DIR`, `OUT`.

## 10. Related

- `Planning/People-Early-Era-Program.md` — the program, its gates, and the constraints in §5
- `Planning/early-era-people/M1a-Findings.md` — where §1's markup and POCOM figures come from
- `Planning/M2-Semantic-Pipeline-Ride-Along.md` — the stage list (R-0…R-4) and the cost model
- `Planning/semantic-spike/V0-Spike-Verdict.md` — the spike this runbook's sibling is waiting on
- `README.md` — the embeddings harvest, whose extractor and store discipline this reuses
- `harvest_ner.py` / `selftest_harvest_ner.py` — the scope, marked and LLM-detected layers (26 checks)
- `stage_m2a.py` / `score_detections.py` / `ner_store.py` / `selftest_m2a.py` — the ground-truth
  loop and the scorer (30 checks, one round trip: stage → annotate → collect → score)
- `EarlyEraNERControlCore/` + `EarlyEraNERControl/` — the control detector; `swift test` covers the
  offset arithmetic on strings where code points, characters and UTF-16 units disagree

Version history:
  1.2 — 2026-08-11: the control detector is BUILT (§5, `EarlyEraNERControl`), and M2a is now
        stageable, collectable and scoreable (§6–7, `stage_m2a.py` / `score_detections.py`) — the
        sample is annotated by editing bracketed text so offsets are derived rather than typed,
        and the scorer verifies the ground truth against the R-0 text before reading any detector.
        Adversarially reviewed before landing: a mutation pass over the self-test found 16 of 23
        mutants surviving, and the checks that close them — an untouched file marked annotated,
        precision/recall denominators, scored-only-what-was-scanned — are in the suite (27).
        Still un-keyed, so §0's rule is unchanged.
  1.1 — 2026-08-11: embeddings Phase 3 is done, so §5's sequencing constraint is void and TEXT_DIR
        (new) verifies each volume against the R-0 layer the vectors were computed from. §4 is
        re-cut: the token count separated from the throughput assumption, a model-band/machine
        table for smaller models on the M5 Air, and the finding that a ≤2 B sweep is schedulable
        but makes the unbuilt NLTagger control MORE necessary, not less.
  1.0 — 2026-08-11: initial runbook. Scope + marked layer + sampled detector pilot, with the
        full-sweep arithmetic that argues against scheduling one, and the M2a gate restated as
        the thing no phase here can route around.
