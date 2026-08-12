# V-0 spike verdict — Phase 2 of the semantic runbook, measured

**Status:** Phase 2 executed 2026-08-10 on the Air, over the Studio's five spike stores.
Every number below is measured by `tools/semantic-harvest/spike_gates.py` (deterministic:
fixed seed 18610810, explicit sorts, sorted JSON keys; needs numpy — it is the Air-side
analysis half). Full machine-readable results: `spike-gates.json` in this folder.
**What remains of V-0:** the owner keys `blind-panel.csv` (100 rows — judge it BEFORE
opening `blind-panel-key.csv`, which names the model and scores and would unblind you),
and reads the Gemma licence terms. Those two acts close V-0 and green-light Phase 3.
**Related:** `Planning/Vector-Embeddings-Semantic-Design.md` §8 (the gates), §10 (the open
questions this answers), `tools/semantic-harvest/README.md` (the runbook this executes),
`Planning/M2-Semantic-Pipeline-Ride-Along.md` §4 (the cost model this tightens).

---

## 0. The verdict in four sentences

1. **EmbeddingGemma-300M-QAT is the primary recommendation**: it leads the weak-positive
   gate on every statistic, at full precision *and* at the shipping int8 config, in both
   eras the gate can measure, and its full-corpus run is ~6.1 h — well under the plan's
   8–13 h band.
2. **The quantization architecture survives measurement; the dimension cut does not get a
   free pass**: int8 storage costs <0.1% recall and the Hamming→rerank pipeline costs
   ≤0.8%, but the Matryoshka truncation itself costs 12–23% of the exact top-10 at 256
   dims — the design's "≥95% recall [U]" expectation holds for quantization, not for the
   cut, and the Tier-2 dims question (design §10.4) is now a real 256-vs-512 tradeoff
   with numbers.
3. **The forbidden-quant rule is vindicated**: the accidental Q4_K_M nomic store agrees
   with its Q8_0 twin on only 82% of rank-1 neighbors — model-level quantization moves
   results two orders of magnitude more than int8 vector storage does.
4. **Pre-1900 has no weak-positive evidence at all** — frus1861 contributes zero
   cross-reference edges (the `dN` idiom postdates 1945 corpus-wide, and this is what
   that fact does locally) — so the blind panel is not a formality: it is the *only*
   pre-1900 gate, and the design's kill criterion ("pre-1900 fails alone ⇒ era-scope or
   kill") rests entirely on the owner's 34 pre-1900 judgments.

---

## 1. Store validation (all five pass)

- `shasum -a 256 -c SHA256SUMS`: every line OK in all five stores.
- Same extraction everywhere: 2,198 docs / 6,990,358 chars in every store
  (frus1861 312, frus1938v01 955, frus1948v06 931). The per-volume `.jsonl.gz` text
  layers differ by checksum but are **byte-identical decompressed** — the gzip header
  embeds an mtime; nothing else differs.
- head/bin/meta agree everywhere (bin size = dim × 4 × chunks; meta lines = chunks).
- Contract details verified: nomic prefix `search_document: `, gemma prefix
  `title: none | text: ` (trailing space intact), bge re-chunked 1800/270, arctic is
  l-v2.0 at **dim 1024** (the runbook's ~568 M substitution, priced below), the two
  nomic stores differ only by quant tier.
- Provenance gap to close in Phase 3: only nomic-q8 captured its GGUF SHA-256
  (`MODEL_FILE` was not set on the other four spike runs). The full harvest must set it.
- Weak-positive source: the live index at the app container's `frus.db` (all 552 volumes
  indexed). **Caveat, owner-flagged:** the local app build is not current; the index was
  written 2026-08-03. Edges are index-time artifacts of the app's own page→document
  resolution, which is stable code, and the same edges score every model — fine for a
  comparative gate; re-derive before any *absolute* claim matters.

## 2. Gate A — weak positives (comparative, and read the caveat)

265 queries (one per citing document; relevant set = union of its resolved citations),
369 resolved pairs: 62 queries in frus1938v01, 203 in frus1948v06, **0 in frus1861**.
Drops: 142 cross-volume (targets outside the spike set), 122 unresolved page anchors
(roman-numeral or unmapped pages), 8 endpoints not in the store, 7 self-references.

| model | MRR@10 | hit@10 | hit@50 | hit@100 | median rank (of 2,197) |
|---|---|---|---|---|---|
| **gemma** | **0.087** | **0.226** | **0.457** | **0.615** | **62** |
| arctic | 0.076 | 0.211 | 0.423 | 0.555 | 81 |
| bge (control) | 0.068 | 0.166 | 0.393 | 0.525 | 91 |
| nomic-q8 | 0.061 | 0.174 | 0.381 | 0.536 | 86 |
| nomic (Q4, forbidden) | 0.055 | 0.159 | 0.385 | 0.532 | 87 |

Per era (float full-dim): gemma leads both — interwar MRR 0.084 vs arctic 0.052; cold-war
0.088 vs 0.083. At the shipping config (int8-256; bge at native 384) the ordering holds:
gemma 0.073/0.219, arctic 0.070/0.189, nomic-q8 0.055/0.155.

**Do not read the absolute numbers as retrieval quality.** Spot-reading hits and misses
says the labels, not the models, set the ceiling: the hits are same-thread telegrams
retrieved at rank 1–5 (`760F.62/571` → `/580`, consecutive Kennedy-from-London cables);
the misses are page-anchor noise — frus1938v01/d3 is a Bullitt telegram on Jewish
refugees whose editorial "for portions not printed, see p. 155" resolves to whichever
*Spanish-civil-war* document spans page 155; the model ranks it 254th because it *is*
unrelated. Median target rank 62 of 2,197 puts the median cited document in the top 3%.
The noise is identical for every model, which is exactly what makes the gate a fair
model-ranking instrument — and nothing more. The 33 M bge control landing within ~20% of
the 300 M primary on hit@10 is the same lesson from the other side.

A second structural finding: **the design doc's assumption that `cross_references`
supplies era-stratified weak positives fails for pre-1945** (frus1861: zero edges;
provenance-flow measured 298 of 552 volumes contribute none corpus-wide). Any future
re-run of this gate at corpus scale inherits the same skew; only the panel measures the
early corpus.

## 3. Gate B — the quantization ladder (recall@10 vs each model's own float full-dim top-10)

| rung | gemma (768) | nomic-q8 (768) | arctic (1024) | bge (384, no MRL) |
|---|---|---|---|---|
| float-512 | 0.878 | 0.908 | — (card sanctions 256 only) | — |
| float-256 | 0.773 | 0.835 | 0.884 | — |
| float-128 | 0.657 | 0.755 | — | — |
| int8-256 | 0.773 | 0.833 | 0.883 | int8-384: 0.971 |
| int8-512 | 0.877 | 0.906 | — | — |
| binary-256 raw | 0.526 | 0.464 | 0.545 | binary-384: 0.600 |
| **hamming-200 → int8-256 rerank** | **0.772** | 0.822 | 0.880 | native: 0.968 |

Three conclusions, in decreasing comfort:

1. **int8 storage is free** (float-256 vs int8-256 differs in the fourth decimal,
   every model) and **the Tier-1 Hamming→rerank pipeline is sound**: raw binary alone
   recalls only 0.45–0.60, but 200-candidate reranking recovers to within 0.8% of flat
   int8 — the two-tier architecture does exactly what the design drew.
2. **The Matryoshka cut is the entire real cost.** 768→256 loses 23% of gemma's exact
   top-10 (nomic 17%, arctic-from-1024 12%). The design's §4.2 "expected recall@10 ≥95%
   [U]" was calibrated against quantization loss and is refuted for the cut at 256.
   Whether a 0.77-recall Tier 2 is *felt* — the replaced rows are typically near-ties —
   is precisely what the panel and V-3's rendered lists show; the number here prices it.
3. **128 dims is dead** (design §10.4 wondered if the ladder might justify it: no —
   0.66–0.75), and **512 is the real alternative**: gemma-512-int8 recalls 0.877 at
   double the Tier-2 budget (~300 KB/volume, ~163 MB full corpus vs ~82 MB). 256 stays
   the recommendation; 512 is the lever if the panel shows truncation pain.

**The nomic Q4-vs-Q8 rung** (same chunks, same prefix, one model-quant tier apart):
rank-1 agreement 82.1%, mutual recall@10 85.9%. The runbook's no-Q4 rule now has a
measurement: the forbidden quant silently changes one in five top-1 neighbors, ~40× the
entire int8 storage cost. (The QAT gemma is the documented exception — quantization-aware
training makes its Q4_0 the intended artifact, and it just won the gate.)

## 4. Wall clock, extrapolated to the 1.374 B-char corpus

| model | measured chars/s | ≈ tok/s | full-corpus run |
|---|---|---|---|
| gemma (QAT) | 62,920 | 15.1 k | **6.1 h** |
| nomic-q8 | 79,981 | 19.2 k | 4.8 h |
| bge (re-chunked control) | 100,148 | 24.1 k | 3.8 h |
| arctic l-v2.0 | 28,290 | 6.8 k | 13.5 h |

Gemma comes in **under** the ride-along's 8–13 h band for the 300 M primary — a single
overnight Studio run. Arctic's l-v2.0 substitution costs a second night if it is ever
needed. (Extrapolation assumes spike-volume throughput holds corpus-wide; the harvester
prints a live ETA that corrects this within the first hour of Phase 3.)

## 5. The blind panel (staged — the owner's move)

`blind-panel.csv`: 100 rows — 34 pre-1900 / 33 interwar / 33 cold-war — each an anchor
document and its top-1 neighbor under the winning model at the shipping pipeline
(Hamming-200 → int8-256 rerank), snippets inline, verdict column empty. Grade each row
`good` / `moderate` / `garbage` against the lexical assessment's standard: *would a
historian want this?* Schedule A (frus1861/d1) and the two most digit-dense frus1861
documents are forced in per the design's structural-document instruction.
**Judge before opening `blind-panel-key.csv`** — the key names the model, both scores,
and a per-row count of how many of the five stores agree on that neighbor.

Kill criteria (lexical §0.11, adopted verbatim by design §8): overall <60% good-or-
moderate kills the axis UI; **pre-1900 failing alone while the rest passes** era-scopes
or kills it — and per §2 above, the panel is the only pre-1900 evidence there is.

> **Superseded for V-3 by owner decision 2026-08-12** (`Phase3-Store-Assessment.md` §0a):
> the panel will not be keyed before the axis ships. The axis ships **experimental,
> opt-in at weight 0.0, and unscoped**, with app-tester feedback as the quality
> instrument instead of these criteria. The consequence to state plainly wherever the
> axis is described: pre-1900 semantic quality is an **unmeasured unknown**, not a
> measured pass — Gate A reaches only 572 pre-1900 queries corpus-wide. The panel
> artifacts stay staged and un-keyed, so keying them remains the cheap fallback if
> feedback proves thin.

Noted for V-2 rather than judged here: all 100 top-1 neighbors are same-volume. With
three era-disjoint volumes that is the expected geometry, not yet the lexical
assessment's "same-volume collapse" — measure it again when cross-era candidates exist.

## 6. What this settles (design §10's open questions)

| # | question | status |
|---|---|---|
| 2 | model + licence | **gemma on the numbers**, pending the panel and the owner's licence read. Phase-3 (generation-only) use is unproblematic either way; the licence question binds only V-5 weight-bundling — clause map in `Gemma-License-V5-Implications.md` (headlines: all shipped vectors are licence-free "Outputs"; shipping weights takes a custom EULA + three notice duties; the restricted-use list is Google-updatable; a V-5 model swap costs one re-harvest night, so gemma-now does not lock V-5 in). Arctic (Apache-2.0, recall-retentive, 2× wall clock) is the clean-licence runner-up. |
| 4 | dims | **128 is refuted; 256 recommended; 512 priced** as the fallback if truncation pain shows up rendered. |
| 5 | chunk vectors | untouched — the store keeps them; pooling stayed downstream (rule pinned in `spike-gates.json`: char-length-weighted mean of unit-norm chunk vectors, L2-renormalized). |
| — | §4.2 rerank recall [U] | measured: ≥95% holds vs the *256-d* truth, not vs full-dim; the cut is the cost, quantization is free. |

Phase 3 readiness: everything Claude-side is done. The two owner acts — panel keying,
licence read — then `caffeinate -i python3 harvest_embeddings.py` with the winner and
`MODEL_FILE` set.

---

Version history:
  1.2 — 2026-08-12: Phase 3 executed (2026-08-10) and assessed — the full-corpus store
        validated clean and the gates re-ran at corpus scale; see
        `Phase3-Store-Assessment.md` + `corpus-gates.json` beside this file. Owner
        decision the same day: the panel stays un-keyed and no longer gates the axis,
        which ships experimental with tester feedback as the instrument (§5's kill
        criteria carry a superseded note).
  1.1 — 2026-08-10: owner decision — Phase 3 proceeds on gemma. The blind panel remains
        open and still gates the AXIS (V-3 shipping), not the harvest: vectors are needed
        under every panel outcome, including an era-scoped one.
  1.0 — 2026-08-10: Phase 2 executed — store validation, weak-positive gate, quantization
        ladder, Q4-vs-Q8 rung, wall-clock extrapolation, panel staged; gemma recommended
        pending panel + licence.
