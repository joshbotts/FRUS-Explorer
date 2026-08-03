# Feature & Priorities Review — what to target after the current slate

**Date:** 2026-08-03 · **Version:** 1.0 · **Status:** recommendations for owner review — no
code changes ride this document.

**Inputs:** the shipped tree at build 39 (v0.2), `Planning/Consolidated-Development-Plan-2026-08.md`
(revised 2026-08-02), `Planning/Wave-R-Research-Trail-2026-08.md`, `Planning/Eight-Issue-Plan-2026-08.md`,
the three discovery design docs (`Vector-Embeddings-Semantic-Design.md` #666,
`OS27-Semantic-Retrieval-Design.md` #636, `Lexical-Similarity-Neighbors-Assessment.md` v3.0 #647),
the BigPicture series, `Cross-Platform-Porting-Assessment.md`, `PreIndex-Feasibility.md`,
`75-Development-Backlog.md`, and all 36 open issues as of this morning (newest: #665).

**The question asked:** once the currently planned work is shipped or refuted, what should the
app target next? Recommendations are not limited to performance and technical debt, but both are
treated as candidate targets alongside features.

---

## 1. Where the app stands

**Shipped (build 39, v0.2, iOS/iPadOS/macOS 26+, TestFlight + App Store configs + notarized DMG).**
The app is far past its spec: FTS5/BM25 search with four readings of a result set (list, timeline,
KWIC concordance, collocates), a Query Inspector that shows the real FTS5 expression and honest
counts, facets, saved searches, working corpora and custom scopes; the WebKit TEI reading pipeline
with highlights, broken-ref explanations, and a multi-signal Related Documents system with honest
"why related" chips; Projects as a first-class workspace with Leads; Collections authoring with
PDF/HTML/DOCX/BibTeX/RIS export and live Zotero API write; on-device Apple Intelligence
summarization with provenance and batch runs; corpus/series analytics, the word-cloud stack with a
keyness baseline that refuses mismatched comparisons; Source Explorer resolving source notes
against five bundled offline indexes; CloudKit sync with a schema-deploy ratchet, error inspector,
and recovery ladder. Four 2026-07/08 workstreams (Settings North Star, Onboarding, Wave R research
trail, most of Q) are complete.

**The committed remainder ("current plans"), for reference — this review assumes it ships or is
formally refuted:**

- **N lane (the live lane):** N-0 keyed regen (#376, owner), N-1 parser session (#353, the biggest
  coverage lever), N-2 RG 256 routing (#354, rescoped 5→3 items), N-3 Conference Files seed +
  ranked lot curation (#375), N-5 lot-map repoint + fold (#372), **N-7 digitised-scan links (#663
  — the highest-value item, ~7,000–9,000 documents get page images)**, then N-4 (#355,
  conditions attached) and N-6 (#235) as appetite allows.
- **R-2b** — retire `ResearchSession`/`SessionEvent` (19 record types → 17); time-gated on R-2a
  field exposure, carries its own Production deploy.
- **Q discovery tail** — D-1 vocabulary explorer, reopened D-2 (#627).
- **Held owner decisions:** #586 facet sort/multi-select scope, #626 editable summaries, #560 Q1
  concurrency stepper, #597 Q4 tip sync, and the seven vector-design decisions (#666).
- **Open defects to triage regardless:** #657 (iPad kill during tab-bar rebuild), the #659
  remainder, #653/#652 (macOS project-switcher and History-window parity), #312 (UI obstruction
  test gating).

**Already refuted — do not re-litigate.** The measurement culture has closed these routes and the
closures should be treated as durable: the bundled lexical-neighbor *artifact* (dominated by a
free FTS5 query — the *axis* survives), #405 creator-org similarity (2.8% corpus reach),
namedFileSeries offline title-match (0 of 4,986), CFPF deep links (file units not digitised), the
harvest creator gazetteer (confidently wrong), Spotlight query-by-example as a similarity axis (no
pairwise API), automated lot sibling-inheritance (52.4% precision), I-9 auto-corpus from Focus,
bundling `frus.db` in the app (App Store size), and Sparkle in store builds.

---

## 2. Recommended next priorities

Ordered. The ranking weighs: user-felt pain first, the app's differentiator (offline research
depth) second, reach third — and it respects the two standing constraints the plans keep
rediscovering: one implementer, and the CloudKit Production deploy as the release gate.

### Priority 1 — Sync & data-integrity wave ("the research data must be unloseable")

**Anchor: #665** (owner-filed 2026-08-03): stop integrating in-progress CloudKit sync on the main
thread; perform sync ops concurrently in the background, integrate results into local stores, and
show a sync/local-only workspace notification the way indexing progress is already shown.

This is the freshest owner signal, and it converges with a cluster of recorded-but-unscheduled
integrity items that should ship as one wave rather than five orphans:

1. **#665 itself** — measure first (instrument a sync pass on a large store), then move
   integration onto a background actor, then the notification surface (reuse the indexing-banner
   grammar both platforms already have).
2. **The summary-sync defects recorded for "when #626 resumes":** `document_cache.summary_text`
   is last-push-wins, and the boot sync lacks an `!isHeadnoteDraft` filter. If #626 (editable
   summaries everywhere) is un-held, do it inside this wave — the provenance model
   (AI / AI-edited / human) already exists on Collection headnotes and the open design question
   (summary vs. note) is answerable: a summary is document-anchored interpretation with
   provenance; a note is free-form and project-visible. Editing surfaces without fixing
   last-push-wins would let sync eat user edits, so the two must land together.
3. **Referential integrity for UUID links.** The #406 orphaned-tags class is trigger-independent:
   tag→document/note links are plain UUIDs with no cascade. Generalize the existing
   `OrphanedTagRepair` posture into a periodic integrity sweep + report (Data & Recovery already
   has the natural home).
4. **The "not verified" debt.** Every recent wave closes with the same clause: real CloudKit
   rejections, migration against real legacy data, and multi-device races are untested. Build the
   missing protocol once — two devices/simulators, scripted concurrent edits, deliberate
   conflicts — and run it against this wave's changes. It then exists for every future schema
   deploy.
5. **R-2b rides here.** Its time-gate will have matured; the schema shrink (19 → 17) and its
   Production deploy belong in the same verification cycle.

**Why first:** the app's value proposition includes "your research data is yours, in your
iCloud." Sync jank is felt on every device pair a real researcher owns; the #488 postmortem and
six Production promotions show this is also the app's riskiest release surface. A dedicated wave
amortizes the verification cost across everything queued behind it.

### Priority 2 — One Discovery lane (merge the three semantic/similarity designs)

Three design documents now describe overlapping futures for the same two integration points
(Related Documents axes, Project Leads): the lexical FTS5 axis (approved, gated), the vector
program (#666, design-complete, V-0…V-5), and the OS-27 doc's three workstreams (#636). Run them
as **one lane with one gate sequence**, not three competing programs:

1. **Shared preconditions first** (both designs name them verbatim): finish the #645 remainder
   (parts landed as #649/#654; the assessment counts seven `IndexingPipeline` truncation sites),
   add the four missing archival route arms (~26k documents), then **re-measure the
   46,234-document zero-candidate market** — the population any new axis exists for. If the
   remeasure shrinks it dramatically, the appetite for the whole lane changes; that is the point
   of measuring before building.
2. **Settle the one shared unsolved design question before either axis builds:** the per-row
   "why related" explanation for a cosine-scored neighbor. Both docs flag it; the app's chip
   grammar ("an unexplained row is worse than an absent one") is a house principle. This is a
   design task, not an engineering one, and it is cheap to do now.
3. **Pull natural-language search forward.** The OS-27 doc's own finding: `CSUserQuery` has been
   available since iOS 18 — "any plan that schedules it behind 27 adoption is mis-sequenced."
   Its named blocker is small and self-contained: the donated Spotlight payload sets only title +
   300 characters (`attrs.textContent` never set, `Search/IndexingPipeline.swift:1669`). Fix the
   donation, re-donate via the existing `rebuildSpotlightIndex` path, adopt `CSUserQuery` as a
   search-entry enhancement. This is the cheapest genuinely new capability in the entire candidate
   set.
4. **Then the V-0 spike decides the rest.** Once the seven #666 decisions are answered, V-0 is
   days of owner-side Mac Studio time with explicit kill criteria (pre-1900 gate, blind
   era-stratified precision panel, quantization ladder). If V-0 passes, build V-1…V-3 (the axis)
   and stop for re-assessment before the discovery map (V-4 — the Metal renderer is the
   expensive tail). If V-0 fails, the lexical FTS5 axis is the approved floor and ships anyway —
   the lane produces a shipped axis on either branch.
5. **Fold #308's document-level subjects in as an axis, not a program.** The volume-grain
   decision ("noise washes out only at the volume grain") stands until an eval says otherwise;
   #261's gated regeneration path is the right vehicle. A doc-level subject axis enters the same
   blind-panel gate as the semantic axis — one eval harness, two candidate axes.

**Why second:** it is the largest capability step the app can take, every design is already
written, and the gates are cheap relative to the build. It should trail Priority 1 only because
sync pain is felt today by every user, while discovery is additive.

### Priority 3 — Corpus-completeness data programs (extend the moat)

The bundled-index + offline-resolution architecture is the app's differentiator, and the
generator + eval discipline is proven. Three programs, in value order:

1. **The People program (#234 + #259 + #260).** The owner's own framing: people coverage excludes
   the first ~70 years because it depends on editor-supplied lists. POCOM as source of truth for
   early-era officials, adversarial review of NER candidates, the +13,439 crosswalk anchor pairs
   (#260, explicitly "needs rollup-outcome eval"), and merge suggestions from the dedup clusters
   (#259). Person search, person analytics, and the co-mention graph all get better for the
   pre-1945 corpus — the era where the app currently has the least to offer. Run it eval-first,
   exactly like `SourceNoteEval`.
2. **#262 resolved-edge manifest.** 2.70M resolved cross-references measured; a bundled edge list
   makes inbound citations complete even when the citing volume isn't downloaded — the
   cross-reference graph and "cited by" views stop silently under-reporting. Needs a size/shape
   design first (the edge list is the big artifact) and must reconcile with the shipped
   `is_broken` design; both stated in the issue.
3. **Quick wins that ride any slot:** #265 corpus-wide glossary/abbreviation lookup (the terms
   table is already indexed by term string — likely under a session) and #263 batch citation
   lookup (footnote triage table).

### Priority 4 — Reach: the hosting-channel decision, then 1.0 readiness

**Make the hosted-artifact channel an explicit, one-time decision.** Four separate features have
now died or stalled against the same missing infrastructure: the approved-never-built Quick-Start
hosted index (`PreIndex-Feasibility.md`), the per-volume neighbor shards, vector Tier 2 per-volume
shards (#666's distribution plan assumes an app-owned repo), and any update channel beyond
GitHub. Either stand up an app-owned artifact host (a dedicated GitHub repo/releases bucket with
checksums and a small CI pipeline is enough — #666 already sketches blob-SHA verification) or
formally retire hosted-artifact features. Deciding **yes** converts several dead ends back into
options, including instant corpus-wide search at first launch — the single biggest first-run
experience lever the app has. Deciding **no** is also fine; it just needs to be said once, so
designs stop re-deriving it.

**Then a deliberate 1.0-readiness wave.** The app is at v0.2/build 39 with 1.0-depth features;
the gap is packaging, not capability: #106 screenshot checklist (both manuals + store), App Store
metadata and positioning, the What's New source decision deferred from S-5, the accessibility
closeout (#268 shared AXChartDescriptor; the allowlisted `MacCorpusBrowserWindow` toolbar labels;
the Dynamic Type worklist), and an explicit localization posture (the catalog is ~641 bytes —
either commit to English-only for 1.0 or schedule population; the current half-state serves
neither).

### Priority 5 — Performance & technical-debt slate (schedule these; don't backlog them)

Worth scheduling as named sessions, in order of measured value:

1. **The two-phase fetch** — already measured: the 7,500-row macOS fetch drops ~10.5 s → ~0.6 s,
   byte-identical output. The plan calls it "the largest remaining latency win… its own session."
   Do it as the app's next pure-performance session.
2. **One batched index-migration event.** An index-version bump is now a multi-hour, 552-volume
   reindex — the plan calls any bump "a scheduling event in its own right." Several wants each
   imply index-shape changes: `place_mentions`/country attention (BigPicture Analytics #10),
   Spotlight `textContent` (Priority 2.3 — if it needs indexed text rather than re-donation),
   any vector rowid alignment, and residual #645-class fixes. Collect them, land them behind one
   version bump, and pair the reindex with the shipped free-space reclaim (#648). Never pay the
   multi-hour cost twice in a season.
3. **Dead-code and inert-UI decisions** — cheap, and each is called "the worst option" to leave:
   `GlobalContextViewModel`'s unreachable reading analytics (wire or delete);
   `Project.defaultSubjectTagIds` shown in the editor while inert (remove, or reactivate with
   #308).
4. **Verification debt:** the unticked five-item manual checklist for PDF/DOCX highlight export
   (nobody has opened the DOCX in Word); #312's partially-gated obstruction test; the TipKit
   dead-anchor audit (the denylist names `BrowserView.swift:441` and `GlobalContextView.swift`).
5. **#270 GeneratorKit migration** — keep as trailing hygiene behind any session that touches a
   generator anyway (`WordCloudKit` is the worked example); not worth a dedicated slot.

---

## 3. Deliberate non-targets

- **Cross-platform port (Web/Windows/Android).** The assessment is honest about cost (4–11
  person-months for web alone) and the three hard blockers (SwiftData+CloudKit, FoundationModels,
  the SwiftUI layer). With one implementer, starting it now would freeze native momentum at v0.2.
  Revisit after a 1.0; if reach pressure grows before then, run only the 2–4 week de-risking
  spike, nothing more.
- **CloudKit sharing / live collaboration.** The standing decision (exported artifacts are the
  collaboration story) predates most of the app and nothing in the last quarter argues against it.
- **On-device ANN infrastructure.** Exact brute force at 317k vectors is the decided shape; no
  sqlite-vec/HNSW work.
- **Any refuted route in §1** unless new evidence appears — the refutations were measured, not
  vibes.

---

## 4. Suggested sequencing sketch

One implementer; the constraint remains review-and-verify bandwidth. Assumes the N lane finishes
roughly as planned.

| Slot | Work |
|---|---|
| 1 | Finish N (N-1 → N-2 → N-7 spine; N-3/N-5 halves ride along) — already the plan of record |
| 2 | **P1 sync wave**: #665 measure + background integration; summary-sync defects (+ #626 if un-held); integrity sweep; multi-device protocol; R-2b + its deploy |
| 3 | **P2 preconditions**: #645 remainder + route arms + zero-candidate remeasure; the "why related" design task; `CSUserQuery` + `textContent` fix *(small, can interleave)* |
| 4 | **P5.1 two-phase fetch** (one session) + P5.3 dead-code decisions ride along |
| 5 | **V-0 spike** (owner Mac Studio) → branch: vector V-1…V-3 **or** lexical-axis build; blind panel gates either |
| 6 | **P3**: People program eval-first; #262 size/shape design; #265/#263 as fillers |
| 7 | **P4**: hosting-channel decision → 1.0-readiness wave (screenshots, metadata, accessibility closeout, localization posture) |
| 8 | **P5.2** batched index-migration event, once its passenger list is full |

Natural pause points: after slot 2 (data layer trustworthy), after slot 5 (discovery decided by
measurement), after slot 7 (1.0 shippable).

---

## Version history

- **1.0 (2026-08-03)** — Initial review: shipped-feature inventory, current-slate summary,
  five prioritized recommendations, non-targets, sequencing sketch.
