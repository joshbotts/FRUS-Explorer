# V-5 — the query encoder, assessed

**Status:** assessed 2026-08-16, **revised the same day (v1.1)** after a five-reader investigation
returned measurements that correct two claims in v1.0 and remove the re-embed from V-5's critical
path. Recommendation is unchanged: **do not build V-5 next.** The blocking item is not the encoder —
it is that **nothing in this programme has ever measured query→document retrieval**.

Every claim below is marked **[M]** measured, **[C]** read from code, **[I]** inferred, or **[U]**
unverified, following the OS-27 document's convention. The unverified ones are the ones that would
need a spike.

## 0. What v1.0 of this document got wrong

Both were re-verified against the artifacts before being corrected here, not taken on report.

1. **The re-embed costs 5.96 h, not "~15–16 h".** `~/frus-semantic-raw/run-manifest.json` records
   `embed_secs: 21454.3` for 320,426,572 tokens — **14,935 tok/s**, not the ~6.8 k this document
   claimed. v1.0 marked that figure **[M]**, which is the worse half of the error: an unverified
   number carrying the strongest confidence marker. The cost argument survives at 2.5× less weight.
2. **The Gemma licence read HAS happened.** v1.0 listed it as **[U]**, "a licence read that has not
   happened". `Planning/semantic-spike/Gemma-License-V5-Implications.md` (2026-08-10) is a clause map
   against the live Terms, and it resolves the question decisively: *"Outputs are not deemed Model
   Derivatives"* (§1.1(e)) and Google claims no rights in Outputs (§3.3), so **every artifact V-1
   through V-4 ships is licence-free** and the licence binds exactly one thing — bundled encoder
   weights, under four cumulative §3.1 conditions. The owner's own read is still formally
   outstanding; the engineering question is not. Containment is bounded: pulling the encoder kills
   typed search and every other semantic feature survives, because §3.3 survives termination.

A third item is not an error but an omission: **PRF's value is no longer unmeasured.** See §4.

---

## 1. The verdict

V-5 asks for three things bundled together — a Core ML query encoder shipped via Background Assets,
hybrid lexical+semantic search, and a corpus re-embed "for exact parity." The design itself titles
it *"feasible, but last, and honestly optional"* and never defines a quality gate for it: §8's gates
are all V-0's, and all of them are document-anchored **[C]**.

Three findings decide it:

1. **The compute is free; the payload is not.** The harvest embedded 320,426,572 tokens in 21,454 s
   **[M]**, so one short query is microseconds of the same arithmetic. What costs is the weights:
   EmbeddingGemma-300M is 308M parameters, and the design's "~80–150 MB quantized" budget looks
   roughly 2× optimistic **[I]**. The app has no Core ML precedent, no Background Assets extension,
   and `FoundationModels` (used for summarization) exposes generation, not embeddings **[C]**.
2. **Parity is a real risk, but "exact parity" is the wrong goal and the re-embed is avoidable.**
   See §1a — this is the finding that most changes V-5's shape.
3. **The query prompt does not exist here.** The provenance pins the *document* prompt
   (`title: none | text: `) and the harvest README knows asymmetry is real — it notes bge-small and
   arctic "embed documents bare (their prefixes are query-side only)" **[C]**. EmbeddingGemma's
   query-side prompt was never captured, never tested, and is not in the digest.

---

## 1a. The parity ladder: "exact parity" is unachievable, and ≥0.995 is free

Measured 2026-08-16 over 1,200 era-stratified queries at the shipping geometry, seed 18610810, with
the sign bits verified bit-identical to the shipped binary. The query vector is rotated
isotropically by exactly `arccos(target)` and pushed through the real funnel. Artifact:
[`parity-ladder.json`](parity-ladder.json), 110.7 s to reproduce.

| query cosine vs harvest encoder | top-10 agreement | recall@10 |
|---|---|---|
| 1.0 (baseline) | 1.0000 | 0.8642 |
| 0.99999 | 0.9921 | 0.8641 |
| 0.999 | 0.9770 | 0.8657 |
| **0.995** | **0.9527** | **0.8608** |
| 0.99 | 0.9413 | 0.8580 |
| 0.95 | 0.8736 | 0.8227 |
| 0.90 | 0.8169 | 0.7819 |

**Three consequences, and the first two are structural.**

1. **Strike "exact parity" from the design.** At cosine 0.99999 — numerically the same model — 0.8%
   of top-10 slots still change, because the corpus is thick with near-ties. Any V-5 test asserting
   list identity against the current artifacts will fail for reasons that are not defects. Recall is
   unmoved (0.8641 vs 0.8642). The honest target is **≥0.995 cosine**, which costs 0.003 recall —
   inside the estimator's noise. **That single edit removes the corpus re-embed, and its ~162 MB
   per-device re-fetch under the family rule, from V-5's critical path** [M].
2. **The dangerous conversion is the one anyone would actually build.** The corpus was embedded
   through **Q4_0 QAT GGUF weights via llama.cpp** — `V0-Spike-Verdict.md` records that
   quantization-aware training makes Q4_0 the *intended* artifact. A conversion made the normal way,
   from the HF checkpoint at fp16, is therefore not "the same weights at higher precision" but a
   **different point on the quantization grid**. The repo's one committed measurement of exactly that
   kind of move — `spike-gates.json`'s `nomic_q4_vs_q8`, rank-1 agreement **0.8207** — sits at ≈cos
   0.91 on this ladder, i.e. recall ≈0.79, a **−0.07** loss: roughly 60% of everything the 256→512
   migration just bought. And that reading is optimistic, because the nomic comparison moved query
   and corpus *together*, where V-5 moves the query alone against a frozen corpus [M].
   **So: convert from the GGUF's dequantized weights, not from the HF checkpoint.** That choice is
   the highest-leverage decision in V-5 and is invisible unless written down.
3. **Pin `MLComputeUnits` explicitly.** Core ML numerics vary with ANE/GPU/CPU selection and silicon
   generation, and the OS chooses by default. The ladder suggests fp16-class variation is free; the
   magnitude here is unmeasured **[U]**.

The go/no-go is one measurement: the cosine between a candidate conversion's output and the **stored
chunk vectors**, for ~300 chunks reconstructed from the R-0 text layer as `PREFIX + text[c0:c1]`
(verified to reconstruct exactly, 586/586, for `frus1861`). One distribution, placed on this ladder,
about an hour once a conversion exists.

---

## 2. What a semantic search page would break, which is the part nobody had costed

These are properties of the shipped search path, all read from code, and they apply to **any**
semantic query — encoder or not.

| What | Why it breaks |
|---|---|
| **The snippet** | `SearchService.search` builds the `<b>…</b>` context snippet from `positiveTerms(from:parameters)`, Porter-stemmed. No keywords, nothing to bold — results arrive as bare headers **[C]** |
| **Concordance and Collocates** | Both `guard !stems.isEmpty` and return empty/unavailable. Two of the four readings go dark on a term-less query **[C]** |
| **`bm25Score`** | `SearchResult` carries exactly one score, load-bearing as the **tie-break in both platforms' date sorts**. A cosine cannot simply be substituted — different scale, different sign convention **[C]** |
| **Filters** | Exactly **one** of the twelve `SearchParameters` filters is expressible from the artifact alone (`volumeIds`). The rest need the document set pre-resolved — the mechanism exists (the facet panel's `materializeMatchSet` temp table) but must be wired **[C]** |
| **Front matter** | **Cannot be honoured at all.** The artifact has 314,483 rows; `document_cache` has **316,839** (verified against the live index). Front matter is not vectorised, so a semantic query silently excludes ~2,356 documents that `includeFrontMatter` — which **defaults to true** — promises **[M]** |

None of these is fatal. All of them are unbudgeted, and together they are larger than the encoder.

---

## 3. The measurement gap, and why the obvious fix is unusable

**Every recall number this programme has — 0.745, 0.851, 0.864 — is measured at k=10 against a
DOCUMENT anchor** [M]. Gate A's positives are editorial cross-references *between documents*. Nothing
describes a typed query.

The obvious ground truth is `frus-subjects`' document–subject mappings: 520 named subjects over
**1,423,734 references** touching **266,845 documents (84.9% of the corpus)**, with **343 subjects**
in a usable 10–2,000-document band [M]. Subject names read exactly like queries (*Trade relations,
Export control, Prices*).

**It cannot be used for this, and the reason is not that it is noisy.**

`EraSanity.swift` records that the doc-level mappings are **~97% raw string-match**, and that TF-IDF
amplifies rare anachronisms into top-ranked entries — *"HIV/AIDS surfacing as a characteristic
subject of a 1964–68 volume"*. The owner-reviewed era gate removed 14 entries across 14 volumes
(World War I 7, EEC 3, Refugees 2, Nuclear weapons 1, AIDS 1) [C]. `VolumeSubjectProfilesIndex`
carries the standing judgement: *"The document-level subject taxonomy is NOT re-introduced as
per-document tags: at the volume grain the string-match noise washes out"* [C].

**The disqualifying property is that the noise is correlated with the baseline.** If a document is
tagged *Trade relations* because it contains the string "trade relations", BM25 finds it trivially.
The relevant set would be largely *defined by* lexical presence, so the evaluation would score
string matching against a ground truth made of string matches — and would penalise a semantic method
exactly when it succeeded at finding documents that never use the words. That is an instrument bent
toward the null hypothesis, and no amount of cleaning the tags fixes the direction of the bias.

**So the measurement waits on a relevance judgement independent of lexical overlap.** Two candidates
that do not:

- **Cross-reference weak positives** (`gate_a_corpus.py`) — editor-asserted links, not string
  matches. Document→document, so they cannot score a typed query, but they *can* score the averaging
  step of the middle option below.
- **A held-out subset** where the subject's words do **not** appear in the document text — the cases
  lexical search provably cannot reach. Given ~97% are string matches the residual is small, and
  whether it represents editorial insight or a different matching rule is **[U]** — it needs reading
  upstream's method, not assuming.

---

## 4. The middle option: pseudo-relevance feedback, no encoder

Run FTS5, average the top-*k* hits' **already-shipped** document vectors into one vector, and put it
through the existing funnel.

**Why this app is unusually well set up for it:** the bundled Tier-1 binary already carries **659
int8 centroids** — one per volume and subseries, each an average of document vectors — with
`SemanticCorpusVectors.centroid(at:)` to read them back [C]. The generator already does this
arithmetic at build time; PRF is the same operation on an arbitrary set at runtime. And the seeds
land in the high-precision tier by construction: FTS5 searches only indexed volumes, indexed implies
downloaded, downloaded implies a shard.

**What is missing is one entry point.** `hammingCandidates(queryRow:)` takes a *corpus row*, not a
vector [C]. A `[UInt64]`-taking variant is the whole new surface; `isEligible` already exists.

**What it cannot do:** rescue a query with no good lexical hits. Average three bad seeds and the
centroid points nowhere — classic query drift. PRF **amplifies** lexical search; only a real encoder
answers a query whose words appear nowhere in the corpus.

### It has now been measured — on a proxy, with a stated bias

v1.0 marked this **[U]**. Measured 2026-08-16 (150 anchors, 8-term queries). Protocol: a real
document *d* is the information need, *d*'s own shipped embedding is the ground-truth query vector,
and the typed query is simulated as *d*'s top TF-IDF terms; PRF is the centroid of the BM25 top-*k*
hits' vectors through the shipped funnel.

| method | recall@10 | mean cosine of the 10 returned |
|---|---|---|
| BM25 top-10 (ships today, free) | 0.286 | 0.751 |
| **PRF, centroid of BM25 top-5** | **0.385** | **0.781** |
| PRF k=5, **bundled sign bits only, no shards** | 0.355 | 0.776 |
| PRF, centroid of BM25 top-10 | 0.348 | 0.775 |
| perfect query encoder (ceiling) | 1.000 | 0.824 |

**Two readings, both true, and quoting only one is misleading.** On recall@10 — did it return the
same ten of 314,483 — PRF closes **13.9%** of the gap to a perfect encoder. On the quality of what it
actually returns (mean cosine to the true query point, which credits an equally-good substitute) it
closes **41.1%**: 0.751 → 0.781 against a 0.824 ceiling.

Four properties make it more than a consolation prize:

1. **It reaches past lexical range, and what it reaches is better than what BM25 returns.** 3.2 of
   PRF's 10 rows are documents BM25's top-50 never contained, and those rows score **0.768** mean
   cosine — *above* BM25's own top-10 at 0.750. Meanwhile 5.0 of a perfect encoder's 10 rows lie
   outside BM25's top-50, which is a hard **50% ceiling on any re-ranker of lexical hits**.
   Re-ranking BM25's top-50 scores 0.347 — already 69% of its own ceiling and structurally unable to
   go further. PRF is not capped that way.
2. **It works at zero downloads.** From bundled sign bits alone, recall 0.355 and returned-row
   quality 0.776 vs 0.781 — the same answer. That matters because the automatic shard fetch is gated
   on `isOnline` and on #926's user-flippable `autoDownloadSemanticShards`; a shard-only design goes
   dark for exactly the readers who turned it off.
3. **Pre-1900 is better, not worse** — the band the axis's quality is a declared unknown for.
   Measured separately at 120 anchors per band: pre-1900 BM25 0.350 → PRF **0.444**; post-1945 0.271
   → 0.358.
4. **It sidesteps the prompt problem entirely.** A centroid of document vectors lives natively in
   document-prompt space, so the query-side prompt asymmetry — the largest single unknown in V-5 —
   does not arise.

**The proxy's bias, stated because it is the same bias §3 disqualifies the subject tags for.** This
measures agreement with the vector artifact's *own* ranking — internal consistency, not whether a
historian wants the rows. `frus1861/d1` "Schedule A", a payroll table that retrieved the Pious Fund
arbitration and a 1945 Winant telegram, would score perfectly here. It removes a mechanical worry; it
does not substitute for a real instrument, and it does not make PRF shippable on its own evidence.

---

## 5. The design's own fallback is unadopted

§6.4 says to "treat OS-27 workstream B as the interim answer" for natural-language queries.
`CSUserQuery` — local, ranked, per-app semantic search over the app's own Spotlight index — **shipped
at iOS 18** and the OS-27 document marks that **[V]**, adding that any plan scheduling it behind 27
is mis-sequenced. **It appears nowhere in the app** [C].

Its blocker is one line: `IndexingPipeline.swift:1856-1858` donates a title, 300 characters and two
keywords. **`attrs.textContent` — the property semantic search matches against — is never set** [C].
Setting it to a bounded extract plus a Spotlight reindex buys the user-facing capability with no
model, no download, and no parity problem. It does **not** query the Gemma space; it is a different
retriever with different results.

---

## 6. Recommended sequence

1. **Set `textContent` and evaluate `CSUserQuery` on this corpus.** Smallest step that decides
   something. If Apple's local semantic search is good enough here, V-5's remaining claim narrows to
   "queries the Gemma space specifically", which is a much harder case to make.
2. **Build the honest instrument.** Two cheap gates, neither needing annotation, and the first
   settles the prompt question as a side effect:
   - **snippet→parent** — ~300 era-stratified 200–400-character excerpts used as pseudo-queries,
     each run through **three prompt variants** (a proper query template / the document template /
     bare), scored by MRR@10 and hit@1 of the parent document. 900 embeddings on the existing pinned
     GGUF; seconds of GPU; no licence exposure, because encoding locally is use, not distribution.
     Note its limit: verbatim overlap makes it a *mismatch* instrument, not a quality one.
   - **owner-written queries** — 20–50 real historian questions judged by eye. This is the
     absolute-quality half, and the half no proxy supplies.

   Both avoid §3's trap, and neither depends on the subject tags.
3. **Then price PRF against that instrument.** §4's proxy is encouraging but self-referential; it is
   one kernel overload away from being testable for real.
4. **V-5 last, if at all** — with §2's breakages budgeted alongside the weights, "exact parity"
   struck per §1a, and the conversion taken from the GGUF rather than the HF checkpoint.

**One prerequisite is shared by steps 2–4 and is small:** the kernel has no external-query entry
point. `hammingCandidates` needs an overload taking `query: [UInt64]`, with the existing `queryRow:`
form becoming a two-line wrapper so the shipped path stays byte-identical and its 600/600
exact-order gate still applies. The rerank half already accepts an external vector. Because the
kernel's tie-breaks *are* the measurement, a new entry point needs its own parity pin rather than an
assumption of equivalence.

**On delivery, if it ever ships:** prefer `SemanticShardFetcher` over Background Assets. It already
fetches SHA-256- and byte-length-verified artifacts from an app-owned repo and already carries
#900's storage UI and #926's consent gate; a model file is a shard with a bigger number. Background
Assets buys install-time pre-fetch and system purging, neither of which an optional,
gracefully-degrading feature needs, at the cost of a new extension target, an entitlement, a
provisioning change, and the xcodegen + scheme-restore dance.

## 7. Not knowable from here

- Whether a Core ML conversion of EmbeddingGemma-300M exists, and where its output lands on §1a's
  ladder **[U]** — needs a spike on a machine. This is now the single go/no-go.
- The weight payload. §6.4 budgets "~80–150 MB quantized"; 308M parameters at Q4_0 floors near
  165 MB, and Gemma's 262,144-token vocabulary makes the embedding table the majority of the model,
  which llama.cpp typically keeps at higher precision — so **165–280 MB** is the honest band **[I]**,
  arithmetic rather than measurement. The pinned GGUF's actual file size is recorded nowhere; the
  run manifest pins only its SHA-256. Peak resident memory while loaded is unpriced.
- EmbeddingGemma's query-side prompt string, and what using the wrong one costs **[U]**. Note the
  trap: the family rule says every provenance field must match, so an implementer obeying the
  artifact's own contract would prepend the **document** prompt to queries — exactly the error the
  model's asymmetry exists to prevent, and one that produces plausible scores and wrong documents
  with no error. §1a's ladder does **not** price this risk: it perturbs isotropically, while a prompt
  is a systematic shift correlated across every query, which could cancel in ranking or could
  concentrate results (hubness). The sign is unknown.
- Whether the ~3% non-string-matched subject pairs are editorial insight **[U]**.

*The Gemma licence was listed here in v1.0 and has been removed: it is answered — see §0.*
