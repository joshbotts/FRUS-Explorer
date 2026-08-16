# V-5 — the query encoder, assessed

**Status:** assessed 2026-08-16. Recommendation: **do not build V-5 next.** The blocking item is not
the encoder — it is that **nothing in this programme has ever measured query→document retrieval**,
and the obvious ground truth for doing so is unusable.

Every claim below is marked **[M]** measured, **[C]** read from code, **[I]** inferred, or **[U]**
unverified, following the OS-27 document's convention. The unverified ones are the ones that would
need a spike.

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
2. **Parity is a 15–16 hour problem, not a conversion detail.** If a converted encoder is not
   numerically identical to the LM Studio GGUF, query vectors land beside the corpus rather than in
   it, and the design's own remedy is a re-embed: **~15–16 h at ~6.8 k tokens/s on the Studio**
   **[M]**, plus republishing 155 MB and a new bundle.
3. **The query prompt does not exist here.** The provenance pins the *document* prompt
   (`title: none | text: `) and the harvest README knows asymmetry is real — it notes bge-small and
   arctic "embed documents bare (their prefixes are query-side only)" **[C]**. EmbeddingGemma's
   query-side prompt was never captured, never tested, and is not in the digest.

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

**Its value is unmeasured** [U] — and by §3, it stays unmeasured until there is an honest instrument.

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
2. **Build the honest instrument** — a query→document evaluation whose positives are independent of
   lexical overlap. Everything else is guessing until this exists, including PRF.
3. **Then price PRF**, which is one kernel entry point away and rides shipped data.
4. **V-5 last, if at all**, and only with §2's breakages budgeted alongside the weights.

## 7. Not knowable from here

- Whether a Core ML conversion of EmbeddingGemma-300M exists, its size, and whether it is
  numerically faithful enough to skip the re-embed **[U]** — needs a spike on a machine.
- The Gemma licence position on redistributing converted weights in an App Store binary **[U]** —
  §10.2 asks for a licence read that has not happened.
- EmbeddingGemma's query-side prompt string, and what using the wrong one costs **[U]**.
- Whether the ~3% non-string-matched subject pairs are editorial insight **[U]**.
