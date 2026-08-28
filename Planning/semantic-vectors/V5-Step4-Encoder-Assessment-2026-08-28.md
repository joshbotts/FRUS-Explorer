# V-5 step 4, assessed: the on-device query encoder — costs, shape, and the one cheap spike

**Date:** 2026-08-28 · **Status:** decision document for the owner · **Basis:** the V-5
assessment (§1a/§2/§6/§7), the Gemma licence clause map (2026-08-10), and the four-way
retrieval comparison completed this week (`eval-2026-08-27/VERDICT.md`). Markers as in
V-5: **[M]** measured, **[C]** read from code/artifacts, **[I]** inference, **[U]** unknown.

## 1. What step 4 buys, on the record

The measured case is now complete and unusual in its cleanliness: on 25 owner-written,
owner-judged queries, **the Gemma route is the only tested method that answers
natural-language questions** (P 0.65 / MRR 0.77; lexical 0.07 on that register with four
zero-result queries; CSUserQuery eight zero-result queries across two runs; PRF
structurally empty exactly where lexical is). The encoder is the piece that moves that
measured capability from LM Studio on the owner's desk into the app. Nothing else on the
board does this; the alternatives were not argued away, they were measured out.

What it does NOT buy: any change to the shipped semantic features (Related axis, map,
clusters run on document vectors and need no encoder), and no rescue for terms-of-art
queries, where lexical stays decisively better — the shipping shape is a routing, not a
replacement.

## 2. What has changed since V-5 §7 was written — four unknowns retired this week

1. **The weight payload is measured, not banded.** §7's honest band was 165–280 MB [I];
   the pinned GGUF is **229,093,184 bytes** [M] — fetched from the repo whose LFS hash
   equals the artifact's `modelFileSHA256`, verified locally, and *proven to reproduce a
   stored corpus vector at cosine 1.0* through an LM Studio serve.
2. **The query prompt exists, is captured, and is human-judged.** §7 called it never
   captured, never tested, sign unknown. The evaluation ran all 25 queries under three
   prompt variants: the query template's results were judged at P 0.65 / MRR 0.77, and
   the variants materially diverge (document 63%, bare 54% top-10 agreement) — so the
   prompt matters, and the right one is now pinned by measurement, not convention [M].
3. **The kernel doorway exists with a parity pin.** `hammingCandidates(queryBits:)`
   shipped with the row form byte-identical and the external form pinned to reproduce it
   exactly — the shared prerequisite §6 named for steps 2–4 [C].
4. **The acceptance instrument is standing.** The 25-query harness plus the judged
   sitting means an encoder build has a ready-made gate: embed the same queries
   on-device, demand ≥0.995 cosine against the LM Studio vectors per query, and the
   judged verdict transfers without a new sitting [C].

Still open from §7: whether a faithful Core ML conversion exists **[U]** — but see §3,
which shows that question is now avoidable rather than decisive — and on-device latency
and resident memory **[U]**, which the spike below prices in one session.

## 3. The architecture decision, and how this week changed it

V-5 §1a framed the go/no-go as "does a faithful Core ML conversion exist," with the
HF-checkpoint trap (a −0.07 recall cliff) as the highest-leverage hazard. There are
actually two viable shapes, and the second dissolves that hazard:

**Option A — embed llama.cpp, ship the pinned GGUF as-is.** The corpus was embedded
through Q4_0 QAT weights via a llama.cpp-family runtime (LM Studio's GGUF engine), and
this week's cosine-1.0 reproduction shows that pipeline is self-consistent. Running the
*same file* through llama.cpp compiled into the app is **parity by construction** — no
conversion, no §1a spike, no quantization-grid move. Costs: a vendored C++ dependency
(llama.cpp with the Metal backend; binary cost a few MB [I]), CPU/GPU-only inference (no
ANE), and unmeasured device latency — though the arithmetic is friendly: the harvest
sustained 14,935 tok/s on desktop [M], a query is ~20–60 tokens, and a phone a few times
slower still lands in the low tens of milliseconds [I].

**Option B — Core ML, converted from the GGUF's dequantized weights.** Native, ANE-able,
no C++ dependency — and everything §1a warned about: the conversion spike is the
go/no-go (the one-hour ~300-chunk cosine distribution against stored vectors, target
≥0.995), `MLComputeUnits` must be pinned, and the tooling path for a Gemma-architecture
embedding model into Core ML is itself unverified [U].

**Not options, for the record:** `NLContextualEmbedding` and any Apple embedding API —
they embed into Apple's space, not the Gemma space the 314,483 document vectors live in;
the family rule is not a formality here, it is the geometry. `FoundationModels` exposes
generation, not embeddings [C]. `CSUserQuery` is measured out.

**Recommendation: spike Option A first.** It converts step 4's remaining unknowns —
latency, memory, binary cost — into numbers in one session, with parity free. Option B
stays as the fallback if device latency disappoints, and its §1a gate is already written.

## 4. The cost breakdown

| item | cost | notes |
|---|---|---|
| **Weights distribution** | 229 MB, opt-in download | Never bundled. `SemanticShardFetcher` is the precedent §6 already endorsed — "a model file is a shard with a bigger number": SHA-pinned against `modelFileSHA256`, #900's storage UI reports it, #926's consent gate covers it, Remove works. First-use prompt, not launch-time fetch. |
| **Resident memory while loaded** | ~250–350 MB [I], unmeasured | Implies load-on-demand and unload-after-idle; the spike measures it. On base-RAM iPhones this may gate the feature to newer devices — a disclosure, not a blocker. |
| **App binary** | +2–4 MB [I] (Option A) | llama.cpp + Metal shaders. Option B: ~0. |
| **Per-query latency** | low tens of ms [I], unmeasured | The spike's second number. Desktop reference: 14,935 tok/s [M]. |
| **Licence** | Four cumulative Gemma §3.1 conditions | The clause map (2026-08-10) resolved the engineering question: outputs are licence-free, the licence binds only shipped weights (use-policy flow-down, notice, etc.). **The owner's formal read is the one non-engineering gate**, and containment is bounded: pulling the encoder kills typed semantic search and nothing else. |
| **Engineering** | **~4 sessions to a shipped narrow feature** | s1 spike (runtime + latency + memory + trivial parity), s2 encoder store + fetch/consent/storage UI + `QueryEncoder` actor, s3 the narrow surface (below), s4 tests/docs woven throughout. |
| **The full search page** | +2–3 sessions, **deferred** | This is §2's itemized breakage budget, and it is larger than the encoder: no keywords → no snippet highlighting, Concordance and Collocates dark, `bm25Score` is the load-bearing date-sort tie-break, 11 of 12 filters need the `materializeMatchSet` wiring, and front matter (2,356 documents) is not vectorised while `includeFrontMatter` defaults true. None fatal, all owed honest UI. Not needed for the first shipped increment. |
| **Maintenance** | Low and *frozen* | The model is pinned by SHA forever against a frozen corpus; unlike CSUserQuery, no OS update changes its behavior. The vendored llama.cpp needs occasional security-level updates only. |

## 5. The recommended first surface — narrow on purpose

The sitting's own recommendation was: **offer the semantic route when the lexical
expression returns nothing** — which rescued 4 of 25 queries outright and is precisely
the register the encoder uniquely serves. As a first surface it avoids nearly all of
§2's budget: the results arrive under an explicit "semantic matches — experimental"
banner (the V-3 naming rule), no keyword snippets are promised, concordance stays out of
scope, and the encoder loads only when that path fires. The full hybrid page remains a
separately priced decision that never has to happen for step 4 to have been worth it.

## 6. Implications of not proceeding

Typed natural-language search stays unserved — including the zero-result fallback, which
has no other engine. Everything else survives untouched: the document-anchored semantic
features never needed an encoder, and the four-way comparison stands archived as the
decision record either way. There is no decay pressure: the artifacts are frozen, so
this decision keeps indefinitely and reopens at the cost of one spike session.

## 7. Decision points for the owner

1. **Green-light the s1 spike?** One session, no shipped surface, converts every
   remaining [U] to a number. This is the only decision needed now.
2. **The Gemma licence read** — formally yours, required before any weights ship;
   the clause map says the conditions are mechanical.
3. After the spike's numbers: s2–s3 (the narrow surface, ~3 more sessions), or park
   with the numbers recorded.
