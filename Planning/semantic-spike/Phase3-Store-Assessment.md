# Phase-3 full-harvest assessment — the store is valid; corpus-scale gates measured

**Status:** executed 2026-08-12 on the Studio, over the completed full-corpus harvest
(`~/frus-semantic-raw`, run 2026-08-10). This is the Phase-5 handoff step of
`tools/semantic-harvest/README.md` — store validation plus the corpus-scale re-run of the
V-0 gates — and the go/no-go assessment for continuing the plan.
**Machine copy of every number:** `corpus-gates.json` beside this file (integrity, contract,
pool sanity, neighbor structure, quantization ladder, rerank-pool sweep, Gate A). Review
artifacts: `corpus-gates-top-pairs.jsonl` (the 30 highest-cosine pairs),
`corpus-gates-duplicate-rows.jsonl` (all 639 exact-duplicate groups). Reproducible analysis
scripts: `tools/semantic-harvest/corpus-gates/` (pinned to `spike_gates.py`'s procedures;
seed 18610810 throughout).
**Related:** `V0-Spike-Verdict.md` (the spike this extends), `spike-gates.json`,
`Planning/Vector-Embeddings-Semantic-Design.md` §§4, 8–10,
`Planning/M2-Semantic-Pipeline-Ride-Along.md` §4 (the cost model this closes out).

---

## 0. The verdict in five sentences

1. **The store is sound and is the artifact V-0 authorized — proceed to the V-1 packer.**
   All 2,208 checksums verify; every per-volume and global count reconciles to the digit;
   the model, prefix (trailing space included), and chunking match the gate-validated
   contract; and the provenance gap V-0 flagged (`MODEL_FILE` GGUF SHA) is closed.
2. **Gate A at corpus scale is strong**: 70,469 citing documents scored against all
   314,482 candidates put the median cited document at rank 36 — the top 0.011% of the
   corpus, versus the spike's top 3.05% — and the first-ever cross-volume evidence
   (15,006 queries) lands at hit@10 0.187 / median rank 290, respectable given the
   known label noise.
3. **The spike's same-volume collapse does not persist**: at corpus scale only 78% of
   top-1 neighbors are same-volume (spike: 100%) — but ~97% of top-10 slots are
   same-*era*, so the semantic space is strongly era-stratified, which is what a
   historian would want and what any cross-era discovery surface must design around.
4. **The Matryoshka cut survives 143× more candidates** (int8-256 recall 0.749 vs the
   spike's 0.773; int8-512 0.864 vs 0.877), and the new rerank-pool sweep shows the
   Hamming funnel's tax is a parameter, not a wall: widening RERANK_POOL from 200 to 800
   recovers int8-512's funnel recall from 0.816 to 0.851 at trivial on-device cost —
   so the §10.4 dims decision is now fully priced.
5. **Nothing here closes V-0's two owner acts**: the blind panel (all 100 verdicts still
   empty) remains the *only* pre-1900 quality gate, and the Gemma licence read still
   gates V-5 only. **Owner decision 2026-08-12: the panel no longer gates V-3** — see
   §0a.

## 0a. Owner decision — the axis ships experimental, unscoped, without the panel

**Decided 2026-08-12.** The blind panel is not keyed and will not be keyed before V-3.
The semantic axis ships **labelled experimental**, corpus-wide rather than era-scoped,
and **app-tester feedback replaces the panel as the quality instrument** — the owner's
judgment being that a single annotator's 100 rows is a weaker signal than a cohort of
researchers using the feature against their own questions.

This supersedes the design's §8 kill criteria and V-0 §5 for V-3 shipping. What the
decision does *not* change, and what makes it a defensible trade rather than a skipped
gate:

- **The axis is opt-in at weight 0.0** (design §6.1, unchanged). A user who never touches
  the weight UI never sees a semantic row, so a bad axis degrades nobody's Related list
  by default. This is the property that makes shipping-before-measuring survivable.
- **"Experimental" must be visible in the UI, not just in a doc** — the axis label carries
  it, and the same framing the summarization surfaces already use applies.
- **The pre-1900 evidence gap is now a stated unknown rather than a measured pass.**
  Gate A cannot speak for pre-1900 (572 queries corpus-wide; §4), and no other automatic
  instrument reaches it. Any claim about early-era semantic quality remains unevidenced
  until feedback arrives — the honest phrasing in release notes is "experimental, and we
  especially want to hear about the 19th-century volumes."
- **The panel artifacts stay staged** (`blind-panel.csv` + its key, un-keyed). If tester
  feedback is thin or contradictory, keying 100 rows is still the cheapest way to get a
  number, and nothing about the store or the pipeline has to be re-run to make it valid.
- **The feedback path has to exist for this to be a real instrument.** V-3 owes a way for
  a tester to say "this row is garbage" — at minimum the axis's presence in the tester
  checklist with the pre-1900 question named. A shipped experiment nobody can report on
  is not evidence-gathering; it is just shipping.

---

## 1. Store validation (all pass)

- `shasum -a 256 -c SHA256SUMS`: 2,208/2,208 OK; the sums file covers exactly the files
  on disk. All 552 volumes carry all four artifacts.
- Per-volume reconciliation, zero failures across 552 volumes: bin size = 768 × 4 ×
  chunks; meta lines = chunks; distinct meta doc ids = head docs = text-layer lines
  (identical id *sets*, not just counts); text chars = head chars; `runs.jsonl` rows
  match heads one-for-one.
- Global: heads, `runs.jsonl`, and `run-manifest.json` all agree at **314,483 docs /
  605,643 chunks / 1,332,974,542 chars**. The run was one continuous 552-volume
  invocation (14:21:50 → 20:19:04, no resume), so `totals_this_run` legitimately
  describes the whole store — on a resumed run it would not, and a future audit must sum
  the heads instead.
- Volume set = the app manifest's 552 volumeIds exactly.
- Contract vs what Phase 2 validated: model `text-embedding-embeddinggemma-300m-qat`
  (uniform across all 552 heads), dim 768, chunk 3200/480, prefix `title: none | text: `
  with the trailing space verified in the raw bytes, `model_file_sha256` captured
  (`5a9e0645…`).

Three provenance notes, none blocking:

- **Script drift, benign and fully explained**: the manifest's `script_sha256` matches
  the harvester as committed 2026-08-07 (PR #744), not today's repo copy (PR #811,
  committed ~2h before the run started). The diff is two fail-fast guards only —
  unlisted-model rejection and the up-front `MODEL_FILE` check — with zero change to
  extraction, chunking, prefix, or output; both guarded failure modes demonstrably did
  not occur (the model id is in the captured listing; the GGUF SHA was captured).
  Consistent with the runbook's `cd ~/semantic-harvest` copy of the script.
- **The GGUF is gone**: LM Studio's models directory no longer holds any embedding
  model, so `model_file_sha256` cannot be re-verified against the file today. The pin
  still does its job — any future re-download verifies against `5a9e0645…` — but a V-5
  weight-bundling decision would start with a re-download.
- The raw chunk vectors arrive unit-norm from the model (max deviation 7e-8), so the
  pinned pooling rule's normalize-first step is a numerical no-op — worth knowing, not
  worth changing.

## 2. What the packer inherits (the id contract, measured)

- **Store ids are a strict subset of the app's display rows**: 0 store ids missing from
  `document_cache` corpus-wide. The packer's join is a direct `(volume_id, d)` join.
- The **2,356 app rows without vectors** (316,839 − 314,483) are all structural:
  1,181 `ch*` chapter divs + 1,012 front-matter rows + 163 `comp*`/appendix divs — no
  editorial notes (all 8,467 `is_editorial_note` rows ARE embedded). The semantic axis
  must be *typed-unavailable* for these rows, never silently zero. The largest
  per-volume delta (frus1919Parisv13: app 170 / store 2) is 168 `ch*` rows — a coverage
  UI must not read it as a harvest failure.
- **idExceptions population: 949 ids (0.302%)**, all letter-suffixed (`d373a`,
  `d1190b`), matching the design's ~0.3% expectation; zero `ordN` fallbacks; zero
  `(volume, docId)` collisions; zero chunk-tiling violations (every doc's spans start at
  0, end at its text length, and overlap consecutively).
- **Exact-duplicate vectors: 1,282 rows (0.408%) in 639 groups.** In the bulk these are
  same-volume reprints, but the top of the cosine distribution is different — see §5.

## 3. Corpus arithmetic, reconciled to the digit

- **Chars, 1.374B (planning docs) vs 1.333B (store)**: the ride-along measured before
  the harvester's truncate-at-next-div rule existed. Re-running the extraction without
  that rule reproduces 1,373,922,235 exactly; with it, 1,332,974,542 exactly. The 40.9M
  chars (3.07%) are back-of-book-index bleed the truncation exists to remove.
- **Chunks, 605,643 vs the predicted ~475k**: not overlap (the prediction already
  included 15%). Per-document chunking is the cause — 66.3% of docs fit one window and
  multi-chunk docs end in remainder tails, so the realized mean chunk is 2,430 chars
  (~584 tokens) against the assumed full 800-token windows; realized overlap inflation
  is 10.4%, not 15%.
- **Tokens actually embedded ≈ 353.7M** (sum of chunk spans ÷ 4.16, plus ~5 prefix
  tokens × 605,643). The manifest's `est_tokens` 320.4M is document chars ÷ 4.16 and
  excludes overlap and prefix — don't quote it as the embed workload.
- **Wall clock 5.96h**, −2.3% vs the spike's 6.1h extrapolation (98.7% of spike
  throughput held corpus-wide).

## 4. Gate A at corpus scale (the strongest automatic evidence yet)

185,521 clean edges reduce to 124,382 retained (35,404 cross-volume) = **70,469 queries /
118,099 resolved pairs from 526 volumes**, scored against the full pool (314,482
candidates, self excluded). Drops:
33,390 unresolved page anchors, 26,359 not-in-store, 1,390 self — and **every**
not-in-store drop is a structural anchor (17,017 `dNfnM` footnote anchors, 5,650
whole-volume targets, 3,242 front-matter sources, 423 section ids, 27 URLs): zero drops
trace to a document the harvest missed.

| config | MRR@10 | hit@10 | hit@50 | hit@100 | median rank | p90 rank |
|---|---|---|---|---|---|---|
| int8-256 (shipping) | 0.197 | 0.365 | 0.535 | 0.605 | **36** | 6,660 |
| float-768 (ceiling) | 0.207 | 0.382 | 0.558 | 0.628 | 29 | 4,539 |

Splits (int8-256): same-volume-only queries hit@10 0.409 (median 22); **cross-volume-only
0.187 (median 290)** — the first cross-volume measurement this program has had; mixed
0.451. Era bands by citing volume: post-1945 hit@10 0.432 (48,349 q), 1900–1945 **0.216**
(21,548 q — the weak band, weaker than pre-1900's 0.278), pre-1900 572 queries only (the
`dN` idiom postdates 1945; treat as wide-interval — the panel remains the real pre-1900
gate). Quantization costs little at the median (36 vs 29) but fattens the tail (p90
6,660 vs 4,539; pre-1900 p90 37,956 vs 12,521).

Read against the spike (int8-256: MRR 0.073, hit@10 0.219, median 67 of 2,197): every
absolute metric improves despite a 143× larger pool — median rank-percentile goes from
3.05% to **0.011%**. The honest like-for-like is the post-1945 band (0.432 vs 0.219).
Both caveats from V-0 §2 carry forward verbatim: the labels are noisy (page-anchor
resolution maps "see p. 155" to whichever document spans the page), so these numbers
understate retrieval quality; and this is a distribution, not a verdict.

## 5. Neighbor structure and quantization at corpus scale

3,600 era-stratified queries (1,200/band; 200-char floor excluded 929 docs from sampling
only). A 12-query recomputation through the literal pinned slow path matched the fast
path exactly.

**The deferred same-volume question**: float top-1 is same-volume for 78.2% of queries
(spike: 100%), top-10 slots 60.2%; shipping config 77.0%/57.9%. Volume-mates still take
~3/4 of top-1 slots, but the collapse is not total. The stronger structure is **era
locking: 96.5–96.8% of top-10 slots are same-band**, essentially uniform across bands —
cross-era neighbors are ~3% of slots even with 314k candidates. Top-1 float cosine:
median 0.873 (p25 0.840 / p75 0.900); the shipping config's top-1 has a float cosine
median of 0.871 — replaced rows are near-ties, as the spike predicted.

**Recall@10 vs float-768 truth** (spike values in parentheses):

| config | overall | pre-1900 | 1900–1945 | post-1945 |
|---|---|---|---|---|
| int8-256 | 0.749 (0.773) | 0.766 | 0.751 | 0.731 |
| int8-512 | 0.864 (0.877) | 0.874 | 0.864 | 0.854 |
| ham200 → int8-256 | 0.728 (0.772) | 0.751 | 0.729 | 0.704 |
| ham200 → int8-512 | 0.816 (—) | 0.841 | 0.815 | 0.794 |

The cut degrades modestly at 143× scale (−0.023 at 256, −0.014 at 512), post-1945 is
consistently the hardest band, and int8 storage remains free. The funnel tax is
asymmetric — 0.021 at the 256 rerank but 0.047 at 512: the 200-candidate binary stage
binds exactly when the rerank tier is good enough to exploit a wider pool. The sweep
prices the fix:

| RERANK_POOL | → int8-256 | → int8-512 |
|---|---|---|
| 200 | 0.728 | 0.816 |
| 400 | 0.739 | 0.839 |
| 800 | 0.745 | 0.851 |
| 1600 | 0.747 | 0.858 |

At P=800 the funnel is within 0.004 of flat int8-256 and 0.013 of flat int8-512, and the
added device cost is only the wider rerank (~0.4M MACs/query at 512 dims — the Hamming
scan is unchanged). **RERANK_POOL should ship as a tuned constant ≥800, whatever the
dims decision.**

**Near-duplicates**: 1.75% of queries have a float top-1 cosine >0.98 (pre-1900 2.92%);
0.75% >0.995. The decisive finding is *who* the top pairs are: 27 of the 30
highest-cosine pairs are **cross-volume edition twins** — `frus1951-54Iran` vs
`frus1951-54IranEd2` and `frus1969-76ve15p2` vs its Ed2, same docId, cosine 1.0 — plus
1890s annual-message reprints. **Any shipped neighbor surface must suppress
edition-pair twins** (a volume-pair rule, cheap) or Ed2 twins will occupy top-1 slots.
This is a new, concrete V-3 requirement; it does not reopen the reprint-detection
non-goal (design §7.8) — the general reprint tier still wants a text-identity index,
but the Ed2 case is enumerable from the manifest.

## 6. What this changes in the design's open questions (§10)

| # | question | status after this assessment |
|---|---|---|
| 1 | Tier-1 bundling (+10.1 MB) | untouched — still the owner's app-size call. |
| 4 | dims 256 vs 512 | **fully priced**: corpus-scale recall 0.749 vs 0.864 (flat), 0.745 vs 0.851 (funnel at P=800); 512 doubles Tier 2 to ~163 MB corpus / ~300 KB per volume. The V-0 recommendation (256 now, 512 the lever if the panel shows truncation pain) stands, with the added rule that RERANK_POOL ≥800 ships either way. |
| 5 | chunk vectors | store keeps them; pooling stayed downstream, re-poolable in ~28 s. |
| — | panel + licence | **panel no longer gates V-3** (owner decision 2026-08-12, §0a — the axis ships experimental and unscoped, with tester feedback as the instrument); the artifacts stay staged. Licence gates V-5 only. |

Two follow-ups noted for whoever re-runs gates next: apply the app's `dNfnM → dN`
fallback in `load_edges` to reclaim 17,017 edges (grows the query set; the app's own
navigation already resolves these), and remember the era-locking finding when designing
any cross-era discovery surface — organic cross-era neighbors are rare, so such a
surface must be an explicit projection (the design's §6.3 slices), not a hope about
nearest neighbors.

## 7. Proceeding: what is actually next

Everything Claude-side that Phase 5 hands over is now done except the packer. In order:

1. ~~**V-1 remainder — `SemanticVectorsGenerator`**~~ — **landed 2026-08-12, same day.**
   Emits `semantic-vectors-index.json` (73 KB) + `semantic-vectors-binary.bin`
   (10.23 MB, bundled) + 552 `.vec` shards (79 MB, the download tier) + a shard
   manifest. Repack is byte-identical; the shipping-config top-10 neighbour lists are
   identical to the numpy matrices these gates were measured on for 6,000 of 6,000
   slots. **One design premise died in the building**: §2's "949-row idExceptions"
   read of the id contract was right about the *count of odd ids* and wrong about the
   *keying* — `d{ordinal+1}` mis-keys 15,097 documents (4.8%), because one suffixed id
   shifts every document behind it. Identity is now stored, not derived (1,605 run
   segments, ~14 KB). The `(volume_id, d)` join and the 2,356 typed-unavailable
   structural rows stand as measured.
2. **Tier 0's map stage is not yet run**: PCA→UMAP→HDBSCAN + c-TF-IDF labels (design
   §3.1) needs a pinned non-stdlib Python environment (`uv`-managed, per the design) —
   the one remaining Python-side build. It gates V-4 only; V-3 needs Tiers 1/2.
3. **Owner acts**: the panel is deliberately not being keyed (§0a) — V-3 instead owes an
   experimental label and a tester-feedback path naming the pre-1900 question. Read the
   Gemma licence when V-5 becomes live.
4. Decisions to settle at V-2/V-3 time, now with numbers: dims (§6), Tier-1 bundling,
   hosting channel, and the Ed2-suppression rule (§5).

The sequencing note from the design and ride-along still stands: the #645 truncation
fixes and archival route arms land before any *axis* ships; they do not gate the packer
or the substrate.

---

Version history:
  1.1 — 2026-08-12: owner decision recorded (§0a) — the blind panel no longer gates V-3;
        the axis ships experimental and unscoped with tester feedback as the quality
        instrument. §6's table and §7's owner-acts item updated to match.
  1.0 — 2026-08-12: Phase-3 store assessment executed — integrity/contract validation
        (all pass), corpus-scale Gate A (70,469 queries), neighbor structure +
        quantization ladder + rerank-pool sweep (3,600 queries), packer id contract
        measured, Ed2-twin suppression requirement identified. Verdict: proceed to V-1.
