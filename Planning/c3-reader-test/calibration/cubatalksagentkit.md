# Starter kit — "U.S. consideration of direct talks with Cuba, post-1961"

An agentic-loop setup for the FRUS Explorer index, following `Docs/Agentic-Analysis-Guide.md`.
Every count below was measured against the local corpus at
`~/Library/Containers/bottsywattsy.FRUS-Explorer/…/Volumes/` on 2026-08-31 by raw text scan of
the TEI (not the index), so treat them as *scan* counts, not FTS document frequencies.

---

## 0. The scoping fact to settle before the agent runs

**FRUS's Cuba record ends in January 1981.** The 1981–1988 subseries has 12 volumes in the
bundled manifest — Soviet Union ×4, Eastern Europe, START, South Atlantic, North Africa,
Foundations, Global Issues II, International Economic Development, National Security Policy —
and **none on Cuba, the Caribbean, or the American Republics.**

So the answerable window is **1961 – January 1981**. Anything an agent says about Reagan-era
contacts is coming from model memory, not from this corpus. Put that in the house rules.

## 1. The core corpus — 4,368 documents in nine volumes

| Volume | Coverage | Docs | Published | Note |
|---|---|---|---|---|
| `frus1961-63v10` | 1961–1962 | 443 | 1997 | Cuba, Jan 1961 – Sep 1962 |
| `frus1961-63v11` | 1962–1963 | 390 | 1996 | Cuban Missile Crisis and Aftermath |
| `frus1961-63v12` | 1961–1963 | 434 | 1996 | American Republics |
| `frus1961-63v10-12mSupp` | 1960–1963 | 746 | **2021** | Microfiche Supplement — see §5 |
| `frus1964-68v32` | 1963–1968 | 441 | 2005 | Dominican Republic; Cuba; Haiti; Guyana |
| `frus1969-76ve10` | 1968–1973 | 690 | 2009 | American Republics |
| `frus1969-76ve11p1` | 1973–1977 | 473 | 2015 | Mexico; Central America; Caribbean |
| `frus1977-80v23` | 1977–1980 | 379 | 2016 | Mexico, Cuba, and the Caribbean |
| `frus1977-80v24` | 1977–1981 | 372 | 2018 | South America; Latin America Region |

This is the **seed scope**, not the answer scope. Cuba policy is also transacted in the Soviet
Union, UN, Africa (Angola), and intelligence volumes — which is what the semantic layer is for
(§4), since it covers all 552 regardless of where you thought to look.

## 2. Four episode clusters, visible in the vocabulary distribution

Raw scan counts across the nine volumes:

```
Attwood            74   61 in 1961-63v11 · 4 mSupp · 4 in 1964-68v32 · 5 in 1977-80v23
Lechuga            83    9 v10 · 58 v11 · 16 mSupp
Lisa Howard        21    9 v11 · 3 mSupp · 9 in 1964-68v32
Eagleburger        44   43 in 1969-76ve11p1
Interests Section  77   72 in 1977-80v23
Tarnoff            92   53 v23 · 39 v24
Angola            305  188 in ve11p1 · 106 in v23
Vaky              525  spans all four administrations (227 in ve10, 199 in v24)
```

The distribution alone sketches the periodisation: a 1963 channel carried into 1964, a
mid-1970s channel, a Carter-era channel with an institutional form, and a rupture term
(Angola) that peaks exactly where two of the channels end.

**Vocabulary that travels across all four** (use these for the semantic seeds, not as keyword
queries): `normaliz*` 224, `dialogue` 385, `accommodation` 168, `rapprochement` 75,
`emissary` 78, `intermediary` 31, `feeler` 17, `modus vivendi` 25, `precondition` 34,
`quid pro quo` 32, `bilateral talk*` 17, `secret talk*` 7.

**Channel/intermediary terms:** `Swiss` 94, `Czech` 106, `Mexican Government` 124.

**Functional-contact terms** — decide in §3 whether these count: `hijack*` 232,
`Guantanamo` 441.

## 3. The definitional call only you can make

The question says "direct talks." The corpus contains at least four things that could satisfy
that, and the answer changes materially depending on which you admit:

1. **Authorized political channels** aimed at the relationship itself (1963, 1974–75, 1977–80).
2. **Functional/technical negotiations** that were direct and did conclude — anti-hijacking
   (`hijack*` 232, heavy in ve10/ve11p1/v23), maritime boundary, Guantánamo water.
3. **Deniable contacts through intermediaries** — Swiss/Czech protecting powers, Mexican and
   other third-government channels, journalists.
4. **Talks *about* Cuba with third parties** (chiefly Moscow) that are not talks *with* Cuba.

Write the inclusion rule into the house-rules block before the first query. An agent left to
infer it will silently blend (1) and (2) and report a continuous record of engagement.

## 4. The negative branch — the one methodological move that matters

> *"if talks were not held when U.S. government was interested, why didn't they happen?"*

**You cannot retrieve an absence.** §7.8 and §A.8 of the guide both say so from different
directions: sparse rows are not zeros, and recall@10 of 0.851 makes "no such document exists"
unprovable. An agent asked this question directly will produce a fluent causal narrative with
no retrievable support.

Convert it into **three positive retrieval targets**, all of which are dense in this corpus:

**(a) The recommendation that was not approved.** Measured in the nine volumes:
`Disapprove` 93, `Options Paper` 18, `Decision Memorandum` 43, `Action Memorandum` 103,
`Recommendation` 1,537, `Approve` 2,129. Plus the formal series — `NSSM` 258 / `NSDM` 234
(concentrated in ve10/ve11p1), `PRM/NSC` 8 and `Presidential Directive` 20 (v23/v24). These are
documents where an option to open talks was posed and the disposition is on the page.

**(b) The terminating event.** A channel that stops has a last document and usually a document
saying why. `Angola` 305 is the obvious one; the loop should find the others by taking the last
dated document in each channel cluster and reading forward 90 days in `document_dates`.

**(c) The stated precondition.** `precondition` 34 (15 of them in `frus1977-80v23`) plus
`quid pro quo` 32. These are the terms on which the U.S. would talk — and the record of which
were unmeetable.

Framing rule for the deliverable: *"the record shows the option was declined here, on these
stated grounds"* — never *"talks did not happen because X."* The second is a historian's claim
built on the first, and it is yours to make, not the agent's.

## 5. The historiographic axis you get for free

`frus1961-63v10-12mSupp` is 746 documents published in **2021**, against 1996–97 for the print
volumes it supplements — and it is dense in exactly this material (`Lechuga` 16,
`rapprochement` 29, `Castro` 1,877, `Memorandum of Conversation` 232).

That means: **an analysis run over the print volumes alone and one run over print + supplement
are different analyses of the same question, 25 years apart.** Running the loop both ways and
diffing the episode list is a publishable finding about the documentary record itself, and it
costs one extra `volume_id NOT IN (...)` clause.

## 6. The loop

**Move 1 — Curate (app).** Read 20–40 documents from the four clusters and tag them with a
project tag, e.g. `cuba-talks-seed`. Tag the *disposition* documents from §4(a) separately
(`cuba-talks-declined`). Two tags, because the agent will treat them as two different ground
truths. Your tags land in `document_cache.user_tag_ids`.

**Move 2 — Compute (agent).**
- Pull the seed set's `(volume_id, document_id)` pairs from `user_tag_ids`.
- For each seed, take its 50 nearest neighbors from `semantic-vectors-binary.bin` (§A.5) —
  corpus-wide, all 552 volumes, no model needed.
- Union, dedupe, drop anything already tagged, and **near-duplicate-filter by very small
  Hamming distance** (FRUS reprints across volumes; §A.5).
- Join into SQL for `date_iso`, `document_sources.repository` / `lot_file_norm`, and
  `person_mentions`. Rank by neighbor count × recency-of-first-appearance.
- Separately: run the §4 disposition queries as FTS, scoped to the nine volumes, and intersect
  with the date windows the clusters define.

**Move 3 — Adjudicate (app).** Open candidates, keep/reject by re-tagging. Two passes is
usually where the episode list stabilises.

**Move 4 — Situate (agent).** For the kept set: an episode table with, per episode, the date
span, the principals, the channel type (§3), the archival provenance mix from
`document_sources`, and — for the ones that didn't proceed — the §4(a) disposition document.

**Move 5 — Claim (you).** N of M, scoped to the nine volumes + whatever the neighbors added,
cited `volume_id/document_id`, and the 1981 ceiling stated.

## 7. Traps specific to this question

- **`back channel` (2) vs `backchannel` (23).** Two tokens; porter stemming does not join them.
  A keyword search for either misses most of the other. Query both.
- **Attwood is also an Africa hand.** He appears in `frus1961-63v21`, `frus1964-68v18/20/23/24`
  as ambassador to Guinea and Kenya. A person-name query without a volume scope conflates two
  careers.
- **Covert action ran concurrently.** The record supports "the U.S. explored accommodation" and
  "the U.S. pursued removal" in the same months. A date-overlap join surfaces it; an agent asked
  for a coherent narrative will resolve the contradiction rather than report it. Say explicitly
  that simultaneity is a finding, not an inconsistency to smooth.
- **Intelligence coverage is uneven** (guide §10). Silence about a channel is not evidence the
  channel did not exist; it may be evidence of what could not be printed.
- **`person_mentions` is TEI-tagged only** (§7.5), and tagging practice varies across a 1996–2021
  publication span. Use it to find, never to count.
- **`document_sources` ≠ `external_citations`** (§4.4). For this question the footnote citations
  to *unprinted* material are the archive-visit pointer — a separate and valuable output — but
  they must never be unioned into a provenance count.
- **`Guantanamo` 441 and `hijack*` 232 will dominate any unweighted retrieval.** If §3 excludes
  functional talks, exclude them explicitly rather than hoping ranking handles it.

## 8. Paste-in house rules — the §12 block plus this question's additions

```text
[Paste Docs/Agentic-Analysis-Guide.md §12 and the §A.8 semantic addendum first, then:]

QUESTION SCOPE — U.S. consideration of direct talks with Cuba after 1961

CEILING
- FRUS's Cuba/Caribbean coverage ENDS January 1981. The 1981-1988 subseries has no Cuba,
  Caribbean, or American Republics volume. Do not narrate any post-1981 episode. If you
  believe one exists, say "outside this corpus" and stop.

SEED SCOPE (nine volumes, 4,368 documents)
  frus1961-63v10, frus1961-63v11, frus1961-63v12, frus1961-63v10-12mSupp,
  frus1964-68v32, frus1969-76ve10, frus1969-76ve11p1, frus1977-80v23, frus1977-80v24
- This is where you START. Semantic neighbors may point outside it; follow them and say so.
- Report separately for the print volumes and for frus1961-63v10-12mSupp (published 2021 vs
  1996-97). Do not merge them into one undifferentiated count.

WHAT COUNTS AS "DIRECT TALKS" — use exactly this rule and state it in every summary:
  [FILL IN: e.g. "authorized bilateral political contact between USG and Cuban government
  officials, whether or not through an intermediary; EXCLUDING functional/technical
  negotiations (anti-hijacking, Guantanamo water, maritime) and EXCLUDING U.S.-Soviet talks
  about Cuba"]
- If a document is ambiguous under that rule, list it as ambiguous. Do not decide.

THE NEGATIVE BRANCH — non-negotiable
- You may NOT answer "why talks did not happen" by absence of documents. Absence is not
  evidence: the funnel's recall@10 is 0.851 and the corpus is a declassification-shaped
  selection.
- Answer it ONLY from positive documents of three kinds, cited individually:
  (a) a recommendation/options paper whose disposition was disapproval or no action;
  (b) a document terminating or suspending an existing channel;
  (c) a document stating a precondition for talks.
- Phrase findings as "the record shows the option was declined here, on these stated grounds",
  never as "talks did not happen because X".

VOCABULARY
- Query BOTH "back channel" and "backchannel" — they are separate tokens and stemming does
  not join them.
- Personal names are not unique across portfolios: Attwood appears in African volumes as an
  ambassador there. Scope person queries by volume or by date.

SIMULTANEITY
- The record may show the U.S. exploring accommodation and pursuing covert removal in the same
  weeks. Report both with dates. Do NOT resolve the contradiction into a single narrative.

OUTPUT SHAPE
- One row per candidate episode: date span, principals, channel type, initiating document,
  terminating/disposition document, archival provenance mix, and confidence.
- Every cell carries volume_id/document_id. Every count carries its denominator.
- Maintain a separate list of footnote citations to UNPRINTED archival material
  (external_citations) as archive-visit leads. Never merge it with document_sources.
```

## 9. Record for reproducibility (guide §13)

- Local library measured 2026-08-31: **552 of 552 volumes downloaded**, 552 semantic shards
  present, `frus.db` 3.2 GB — so the usual "conditional on my library" caveat is nearly moot
  here, but record it anyway.
- **Copy the database before connecting anything** (`.backup`, not `VACUUM INTO`), quit the Mac
  app first, and open read-only. The counts above came from the TEI, which is safe to read
  live; the index is not.
- Record the provenance digest from `semantic-vectors-index.json` alongside the volume list —
  a regeneration changes every neighbor list, and this question's whole discovery half runs on
  neighbors.


---

# ADDENDUM — the archival roadmap this kit was missing

**Added 2026-08-31 after an audit asked whether the run had used the app's archival source layer at
all. It had not.** Across all three scoping runs: zero record groups resolved, zero NAIDs, zero
series titles, zero entry numbers. Of fifteen bundled archival-resolution artifacts (11.83 MB of the
24.79 MB the app ships), exactly one was ever opened.

FRUS is a published *selection*. Scoping is not finished when you know which volumes hold the
question — the second half is which archival units those documents came out of, and which units
their footnotes point at. **Report both channels, always labelled, never summed.**

## What the nine Cuba volumes actually rest on

4,213 of 4,368 documents (96.5%) carry a source note; **2,823 (67.0%) resolve to a named archival
collection — against a corpus baseline of 28.3%.** This scope is more than twice as archivally
legible as the average FRUS volume. **203 archival units across both channels, 86 with a NAID.**

| Weight | Kind | Target |
|---|---|---|
| 396 | presidential library | Kennedy Library, **National Security Files** — 18 named sub-series; Countries and Meetings-and-Memoranda first |
| 370 | presidential library | **Nixon NSC Files** — 15 of 40 sub-series cited, one of them titled ***Backchannel Messages*** |
| 327 | presidential library | Carter Library, **National Security Affairs (Brzezinski and Staff Material)** |
| 310 | central file class | RG 59 Central Files — 101 of 1,164 classes |
| 165 | presidential library | Johnson Library, National Security File — 29 of 100 sub-series |
| 50 | lot file, RG 59 | **S/S Files: Lot 65 D 438**, NAID 27022950 — Executive Secretariat, Restricted-Partly |
| 46 | lot file, RG 59 | **Ball Files: Lot 74 D 272**, NAID 614703 — *unrestricted*, folder list available |
| 47 | RG 330 | OASD (C) A Files: FRC 71 A 2896 |

## The channel this kit told an agent to read, and never read

`external-citation-index.json` records where the footnotes point *outside* the printed record. This
kit twice instructs a future agent to treat it as archive-visit leads, and no number in it ever came
from that artifact. Measured now, over the 6 of 9 volumes present in it: **676 footnote pointers
into 61 archival units, 15 of which the source notes never name.**

| Refs | Target |
|---|---|
| **272** | National Security Affairs, Carter Library (Brzezinski / Staff Material) |
| 84 | National Security Files, Kennedy Library |
| 71 | National Security File, Johnson Library |
| 30 | **D Files: Lot 81D113**, Entry P-14, NAID 1487627 — Deputy Secretary |
| 15 | S/S Files: Lot 65 D 438, NAID 27022950 |
| 14 | Recordings and Transcripts, Johnson Library |

**Why this matters more here than anywhere.** The kit's §4 argues at length that you cannot
retrieve an absence, and converts the negative branch into three positive document types. That
argument is right — and the artifact whose literal subject is what the editors saw and did not print
sat unopened the whole time. For "why didn't talks happen", the unprinted record is where the answer
most plausibly lives.

**Reach limits, measured.** 19 of 105 lot files carry no NAID, but only 1.1% of total weight — the
lot route is 98.9% resolved. All 98 named clusters (the presidential libraries) carry no NAID, which
is structural: the libraries sit outside every record group. Use the curated finding-aid URLs.

## Add this to the paste-in house rules

```text
ARCHIVAL SCOPE — do not stop at what FRUS printed
- Resolve BOTH channels and label every count with which one it is:
    came-from   -> document_sources / collection-usage-index.json
    pointed-at  -> external_citations / external-citation-index.json
  They answer different questions and must never be summed.
- Resolve as far as the bundled indexes reach and report what you got:
    central-files-index.json      lot number -> record group + series NAID + entry number
    collection-authority.json     collection identity across spellings
    series-facts-index.json       creator, extent, date span, access status, facility
    lot-claimants-index.json      lots NARA divides across several series
    presidential-library-catalog.json, decimal-class-labels.json,
    curated-lot-resolutions.json, digitized-ranges-index.json
- A CORPUS-SCOPING NEGATIVE IS NOT A RESEARCH NEGATIVE. Never publish "FRUS does not print
  this" without having attempted "and here is the series that does".
- NARA's creator attribution is a decoy surface — measured at 56% precision on one route.
  Verify a series' creator heading before calling it on-topic.
- The offline stack barely reaches before 1940 (11 of 695 bundled series). Say so rather than
  reporting an empty pre-war roadmap as an archival absence.
```
