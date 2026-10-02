# Tier E assessed — level of effort and sessions, grounded in the tree

**Status:** assessment COMPLETE 2026-08-27, at the owner's request after W-2 closed. Every
estimate below was grounded by reconnaissance against the current tree and, where it mattered,
the live index — because three of the seven rows' premises did not survive that contact, and an
estimate built on a false premise prices the wrong work. Premise corrections are marked ▲.

**The headline table.** "Session" = one focused working session of the kind this wave runs
(implement → full suites → PR). Assessments are their own deliverable; builds they may recommend
are priced separately and are not commitments.

| item | what it really is | LOE | sessions | gated on |
|---|---|---|---|---|
| W-11 resolver | citation grammar + stamped link table + two panel twins; **916 docs, 79.8% linkable under four rules** | M | **2** | owner `--stamp` run at the end |
| W-12 concordance | ASSESSMENT (▲ premise corrected: no era tags; region cannot discriminate) | S–M | **1** | none |
| W-13 coverage map | per-kind key partition + corpus-list states + appendix statement (▲ named sources can't supply it as written) | M | **2** | none |
| W-14 read-aloud | speech engine + transport + highlight-follow + background audio, dual-platform (▲ "single session" sizing refuted) | M–L | **2** | device audio check is owner-lane |
| W-15 geo/toponymy | ASSESSMENT — and its empirical half is **already done below** (the placeName census) | M | **1** | none |
| W-16 dispersion | ▲ STALE — already surfaced (#579); residue is delete-or-unify | XS | **¼** (fold into any session) | none |
| W-17 lexical axis | build the approved query-time variant (scorer-shaped) | M | **2** (incl. the §0.10 incumbents) | build: none · **evaluation: W-9 step 2**, which is itself gated on the leads-or-noise verdict |

Total to clear the tier as written: **~10 sessions** (two of them assessments). If W-12's and
W-15's assessments both recommend building, add their builds: W-12's is mostly owner curation
plus ~1 tooling session; W-15's P10 is the tier's one genuinely large follow-on (~2–3 sessions
plus a curated toponym table).

---

## W-11 — Previously-published outbound resolver · M · 2 sessions

**Measured scale (live index):** 916 documents across 127 volumes carry `citation_era =
"published"` (0.35% of 264,487 source rows; the bundled provenance artifact cross-checks at 935
notes, peaking in the 1930s). The parse carries a **raw string only** — `case
previouslyPublished(citation: String)` decomposes nothing — so the "small citation grammar" is
real work, but the 22-entry `previouslyPublishedLeads` table is already ~80% of the publication
vocabulary; the grammar's job is per-lead number/date/page extractors, not re-identification.

**Four link rules cover 79.8%:** Treaty Series (331 docs, `Series No. N` — one regex covers TS +
EAS at 46.6% combined), Department of State *Bulletin* (184, date + page), *Public Papers* (114,
president + year + book + page), Executive Agreement Series (102). The tail is honest-no-link
territory (Miller's *Diary*, League of Nations, bare `42 Stat.`), 11 `Ibid.` notes need
preceding-note context (the `FootnoteCitationGrammar` inheritance shape applies), and 7 cite
FRUS itself — free internal deep links. Two grammar landmines are visible in the corpus and must
be in the fixtures: spurious spaces around unwrapped italics (`Bulletin , May 5, 1946`) and
roman-numeral volumes (`vol. iii , No. 73`).

**Every precedent exists:** `CuratedLibraryResolutions` is the record/store/rationale shape and
its panel button is the render idiom; `RepositoryLink { url, label, verifiedDate }` with "an
unstamped link does not print" is the D12 discipline; `check_repository_links.py --stamp` is the
release habit — **but it parses a Swift table, so the link table should be Swift source per the
`RepositoryFactTable` precedent, or the checker needs a second reader.** The four new outbound
hosts (HathiTrust, archive.org, govinfo, presidency.ucsb.edu) exist nowhere in the app today and
their behavior under the checker is unmeasured — verify before stamping.

**Resolution is display-time over the stored raw note — no re-index, no bump.**

**Session 1:** the grammar in SourceNoteKit (per-lead extractors + the two landmines in
fixtures) + the link-rule table with stamped dates + resolver + tests. **Session 2:** both panel
twins (iOS `previouslyPublishedPanel` + macOS GroupBox) gain the link button and the honest
no-link state; checker extended and run against the four new hosts; owner stamps.

## W-12 — Parallel-series concordance ASSESSMENT · S–M · 1 session

▲ **The founding premise is wrong and the assessment must open by correcting it.** The backlog
text says "the taxonomy already carries era/region tags." Measured: the taxonomy has **no era
tags at all** (categories are places/people/topics), and region is not a tag but the
`subcategory` field of `places`, resolved by a hard-coded Swift switch — and it **cannot
discriminate volumes**: a volume touches a mean of 4.66 of 7 regions, and 95 volumes touch all
seven. The clean key is `manifest.json`'s `dateRange` — 100% populated, precise, ISO — plus, at
best, a coarse region hint. A second shared flaw: the place vocabulary is present-day states
only (`turkey`, not `ottoman-empire`), which blurs any 19th-century series mapping.

**What the session does:** correct the premises; research the five series' actual volume
structures (DBPO/DDF/AAPD/Dodis/Wilson Center — Dodis's open API is the one machine-checkable
target); design the keying as half-open date intervals over `dateRange` (the `administrations.
json` shape) with rows in a hand-curated separate artifact carrying URL + rationale (the
`curated-library-resolutions` record and the curated-lot "no generator writes this file" rule);
sample-curate a handful of rows per series to price full curation honestly; name the UI slot
(volume-page panel vs a seventh Browse tile — note "concordance" already names the KWIC surface,
so the feature needs another word on screen); end with build/no-build. **If build:** ~1 tooling
session; the curation itself is owner-lane and the doc's job is to price it per series.

## W-13 — Coverage map / systematic-review mode · M · 2 sessions

▲ **The two named sources cannot supply the feature as written.** `ExportHistoryEntry` records
*counts only* — no document identities — so it can contribute nothing to "opened 43 of 267";
and `ProjectEngagedDocuments.keys` unions opened/annotated/collected into one flat set,
discarding exactly the split the sentence needs. The real numerators: `ReadingHistoryEntry`
(opened — **gated on research logging**, so the coverage statement owes a caveat when logging is
off), `ResearchNote` + `DocumentHighlight` (annotated — note highlights carry no `projectId`),
and collection membership. The denominator and the list surface already exist: `WorkingCorpus.
documentKeys` plus `CorpusDocumentsView`, which already renders `coverageDescription` ("N of M
documents indexed…") — the new sentence is its sibling.

**Session 1:** a per-kind key-partition service (the `ProjectLeadsService` gatherer shape, plus
the missing visits gatherer), row states in `CorpusDocumentsView` (opened / annotated /
untouched) and the corpus-level coverage line. **Session 2:** the exportable coverage statement
in `QueryMethodAppendix` — which means **all three renderers** (markdown, plainTextLines, csv)
plus `preambleLines` and a logging-off caveat, or it appears in Markdown and vanishes from a
collection PDF — plus a Project Home tile variant and both-platform polish. No schema change,
confirmed.

## W-14 — Read-aloud · M–L · 2 sessions

▲ **The archived "single session, small-to-medium" sizing does not survive the recon.** What
exists is real: `buildFlatTextBlocks(from:)` is the spoken-pass primitive (block segments sharing
the flat-text coordinate space; footnote markers already dropped — but `.footnoteBody` currently
flushes into the block list and must be filtered), and the offset engine + `buildRanges(start,
end)` JS mean **flat-offset → highlighted DOM range already works**. What does not exist: any
AVFoundation usage at all, any background-audio mode (a `project.yml` edit + the xcodegen/scheme
dance), any generic scroll-to-offset (the only scroll-to is footnote-anchored), and any reading-
position persistence. The read-mode gate has a clean precedent (edge-tap zones activate only
when the rail is closed) and speech follows the same shape. Both platforms host the reader
separately (`DocumentView` + `MacDocumentView`), so the transport UI is written twice.

**Session 1:** the speech controller (utterance queue over filtered blocks, rate/voice,
skip-footnotes by construction), iOS transport in Read mode, word-range highlight-follow via the
existing JS + a small scroll-to-offset addition. **Session 2:** macOS transport, audio session +
interruptions + background mode, lock-screen/remote commands (the commuter case implies them —
scope decision), stop-position memory. Device audio behavior (route changes, background) is
owner-verify.

## W-15 — Geographic/toponymy ASSESSMENT · M · 1 session

**The empirical half is done — this recon ran the census the assessment needed:**

- **331,639 `<placeName>` elements** across 551 volumes — and **99.91% sit inside datelines**.
  Only 0.09% occur in body text. ▲ So `place_mentions` as harvestable is a **dateline-origin
  table — where documents were written — not subject geography**; C6's "country attention"
  promise over-reaches, and P8's content-attention chart cannot come from it. This boundary is
  the assessment's most consequential sentence.
- **No `<placeName>` carries a ref or key, ever** (881 of 331,639 have any attribute; none
  identify a place). The TEI gives era-correct surface names and nothing else — the
  name-at-date/place-identity split is entirely the app's to encode. A literal `person_mentions`
  mirror is impossible (that table keys on TEI-supplied refs); `place_mentions` needs surface +
  resolved-identity columns.
- **The name-at-date pairing is free**: the authoritative `<date @when>` sits beside the place
  in the same dateline, so `(surface, date_iso, resolved_place_id?)` needs no new inference.
  And the vocabulary is tractable: 10,417 distinct strings, top 500 = 93.2% of occurrences —
  a hand-curated toponym reconciliation table (its own artifact, per the curated-resolutions
  rule) covers the corpus at a few hundred rows. Constantinople 2,123 / Istanbul 153;
  Peking 5,932 / Beijing 166; St. Petersburg 1,132 / Petrograd 458 / Leningrad 56 — the renames
  the charter names are all live in the data.
- Extraction is nearly free: one `case "placeName"` in the parser + one AST case + an extractor
  beside `extractDateline` (which today flattens the place into a string soup). But **P10 needs
  its own index bump — W-1b's is spent** (v47 shipped).
- **P11 is largely delivered**: `sharedPersons` and `sharedSubjects` ship on by default and the
  embedding blend shipped as the semantic axis; the remaining content is owned by W-17. Likely
  verdict: closed as superseded, with one check against the ranker's known one-candidate
  distortion.
- **P12 is half-shipped without any fetch**: bundled VIAF/Wikidata links already render from
  `person-authority-index.json`. What live enrichment adds is marginal against the offline-first
  posture; likely verdict: defer or narrow to on-demand-tap.
- The house gazetteer anti-precedent (the NARA creator-gazetteer trap) must be addressed head-on;
  the answer is that this table is curated against measured surface forms, not derived from a
  harvest.

**The session writes the doc**: per-priority recommendations (expected shape — P10 proceed as a
dateline-origin table with the honest boundary stated; P8 interim volume-tag form vs document
form gated on P10; P11 close; P12 defer/narrow), the `place_mentions` schema sketch, the toponym
table design, and the bump plan. **If P10 proceeds: ~2–3 build sessions** (parser + extractor +
table + bump + toponym artifact + a first surface) plus owner curation of the top-500 table.

## W-16 — Dispersion: surface or delete · XS · fold into any session

▲ **The premise is stale.** "Zero callers" is still true of `FTS5Vocabulary.
occurrencesPerDocument` specifically — but the suggestion ("the Query Inspector is the natural
home") describes work that **already shipped on 2026-07-30 (#579)**: `InspectedOperand.
corpusOccurrencesPerDocument` computes the identical ratio and the inspector renders "N
occurrences, X.X per document" gated at ≥1.5. The whole `CorpusTermProfile` family
(`termProfile`, `termProfiles`, the property) is app-dead; the OpenAPI spec names the dead state
in prose. The residue is a fifteen-minute choice: **delete the dead family** (and its tests), or
**unify** by having `SearchService.corpusTermProfile` return the real `CorpusTermProfile` so one
definition of the ratio survives. Unify is the one-definition-rule answer; either way it rides
any session as by-catch. The Q&CA plan's "Dispersion | Not shipped" row is likewise stale.

## W-17 — Lexical similarity as a query · M · 2 sessions + 1 shared, gated

**The design is already written and unusually complete** (`Lexical-Similarity-Neighbors-
Assessment.md` §0.12): scorer-shaped (never a generator — which also keeps the generator-set
test untouched), `bm25(candidate)/bm25(anchor)` self-ratio, the **four traps as code
requirements** (column-restrict MATCH to `body_text` for *correctness* — an open MATCH partly
re-derives the archival axis; never push scope ids into SQL; a df ceiling is correctness, not a
knob — 2.9 s pathological anchors without one; exclude the anchor). The chip machinery exists:
`case sharedTerms([String])` and `SemanticSharedTerms` are exactly the "display forms from the
anchor's own text, never stems" machine. The costs go on-surface via the existing `AxisWeightRow`
caption slot.

**What's genuinely new:** a column-restricted BM25 entry point in `FTS5Store` (the only BM25
query today is an unrestricted MATCH, and `renderExpression` never scopes columns — so a new
store method, not a parameter), the axis case + six switch arms + five test updates — including
an owner decision forced by `SemanticAxisTests.newAxisPropertiesAreScoped`, which pins
`.semanticSimilarity` as the *only* self-normalising axis and a self-normalising lexical axis
fails it. And §0.10's incumbents "come first": the #645 seven-site fix and the four missing
route arms — note both are parse-adjacent and may claim an index bump of their own; price that
in session 1.

**Session 1:** the incumbents (#645 + route arms) and the store entry point with its ceiling
tests. **Session 2:** the axis (scorer, weight 0, "experimental" naming per the V-3 precedent),
chip reuse, caption disclosures, the five test updates, the exclusivity decision recorded.
**Session 3 (shared, gated):** the evaluation beside W-9 step 2 — one measure judging both
routes. Two honest flags: W-9 step 2 is itself gated on the leads-or-noise verdict (not
currently unblocked), and its snippet→parent gate is *lexically contaminated* by construction —
judging a lexical axis by it flatters the axis, so the owner-written-queries half is the clean
comparator. The build need not wait for the evaluation (V-3's own precedent: ship experimental
at weight 0, evaluate after), but the PoR's "never ship un-compared" instruction makes the
pairing the plan of record.

---

## Suggested order, if the owner wants one

Cheap and premise-clearing first: **W-16** (fold-in) → **W-15 assessment** (the census is done;
the doc is a day's writing and unblocks/kills the tier's biggest build) → **W-11** (the most
user-visible payoff per session, fully unblocked) → **W-13** → **W-12 assessment** → **W-17
build** (its evaluation then waits with W-9) → **W-14**. That sequence front-loads the two
assessments whose verdicts change what the rest of the tier costs.
