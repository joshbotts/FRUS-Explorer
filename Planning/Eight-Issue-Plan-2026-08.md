# Eight-Issue Plan — sequenced easiest-first

**Date**: 2026-08-01
**Issues**: #559, #597, #561, #553, #586, #562, #560, #626
**Status**: revised again 2026-08-01 — items 1–7 shipped plus #560 PR A; #560 PR B (sub-document
progress + settings copy) is specified and unbuilt; #586 and #626 held by the owner

Every effort estimate below was checked against code, and three claims were re-verified by hand
before this was written. Four issues turned out to be a different size than their titles suggest,
and two have a **false premise in the report itself** — those are called out, because a plan that
inherits a wrong premise builds the wrong thing.

---

## 0. Owner decisions, and what they changed

**#553 — snippets first: accepted.** No change; Step 1 was already the plan and the peek stays
deferred.

**#597 — the tip suite is back in, and my "decline" is overruled.** The owner's justification is a
real division of labour and it is now the scoping rule for the whole item:

> The research guide helps users understand **what the app can do**; the TipKit disclosures guide
> them in seeing **where and how to access** those capabilities.

That line does more work than a scope cut would have. A tip earns its place when a capability's
*access point* is invisible — an unlabelled glyph, a transparent tap zone, a context menu with no
affordance. A tip does **not** earn its place by explaining what a feature is for. Applied
strictly, a fresh inventory of every access point in the app yields **16 tips across 20 anchor
sites**, not the ~40 surfaces the decline was priced against — and the first-contact set is four
tips at four anchors. §2 now carries the phased plan.

**Honest note the owner should have:** Phase 0 + Phase 1 is materially smaller than the declined
version — about 10% of the surfaces and under 7% of the strings. The **full five-phase program is
not**. At 16 tips / 20 sites / 32 strings, plus infrastructure the declined version never priced
(a tip registry, an audit test, UI-test suppression, a new obstruction scenario, a Settings
affordance), it is roughly 50–60% of the original in engineering hours. The recommendation is to
commit to Phase 0 + 1, ship, live with it a build cycle, then re-decide phases 2–4 individually.

**#586 — sorting is first-class, and the framing is better than mine.** The owner's point is that
users may want to work with *slices* of results in different orders, which makes facets a way to
**manage** results, not just understand their shape.

That is already half-built and I under-read it: **facet rows are already tappable to narrow** —
`Button { onNarrow(narrowing) }` at `FacetPanelView.swift:445`, writing real `SearchSQLFilters`
fields and surfacing as a clearable chip. So the management capability exists; what is missing is
the ability to *reach* the slice you want. That sharpens the item rather than growing it: this is
about reachability of an existing action, not a new interaction. It also independently produced a
priority-1 tip candidate (see Phase 1, tip 4) — a narrowable row is visually identical to a
descriptive one.

---

## 0b. Second revision, 2026-08-01 — one added, two held

### Added: #597 recall — "Show Tips Again"

Scoped during the Phase-1 mechanics work and not built, because Phase 1 was the anchors. It is now
the next item.

One button in `DisplaySettingsView`, iterating `DiscoveryTipRegistry` and calling
`Tip.resetEligibility()` on each. That view has been **shared since S-5b**, so this is one edit for
both platforms — the only item in the whole plan with no parallel-implementation hazard. It already
owns `edgeTapNavigationEnabled`, the preference behind one of the Phase-1 tips, which is the right
neighbourhood.

Not `Tips.resetDatastore()`: it throws once the datastore is configured, so it would at best become
a next-launch reset. App-wide rather than per-area — per-area done honestly means listing every tip
by name in Settings, which is a feature tour inside Settings and exactly what the what-vs-where rule
rules out.

**It also removes a real friction the owner has hit twice**: every visual review of a tip so far has
needed a fresh simulator or Erase Everything, because there was no way to see a tip a second time.

### Held: #586 facet sort — the scope is expanding

The owner is widening this beyond sort and reachability to include **multi-select** (several years
or volumes at once) and **exclusion** (narrow to *not* this).

That is a materially bigger change than the one planned, and in a different place. Sorting and
truncation are display concerns in one view; multi-select and exclusion change what a narrowing
*is* — today `onNarrow` applies one value and surfaces one clearable chip, writing single-valued
`SearchSQLFilters` fields. Supporting sets and negation means the filter model, the chip vocabulary,
and the SQL all move, and the facet panel becomes a query builder rather than a breakdown that
happens to be tappable.

**Re-estimate when the shape is decided; the old "S (large)" no longer applies.** The reachability
half — raise the bucket limit, sort locally, display cap — is still worth having and is still
Effort S; it can ship first and independently if the larger design takes time, and the
**non-lazy `ScrollView { VStack { ForEach } }`** hazard applies to it either way: the display cap
must land in the same PR as the raised limit.

### Held: #626 editable summaries — collision with research notes

The owner wants to think about how a user-written summary relates to a research note before this
proceeds. That is the right question to stop on, and it is a design question rather than an
implementation one:

Both are prose the user writes about one document. A note is already free-form, already tagged,
already searchable, already exportable, and already appears in the research rail. A user-written
"summary" would be all of those things too — so what distinguishes them is not obvious, and if the
answer is "nothing much", the feature is a second inbox for the same content.

Possible distinctions worth weighing, recorded rather than resolved: a summary occupies a fixed
slot the document view renders in a known place while notes are a list; a summary is *about the
document as a whole* where a note is often about a passage; a summary carries `authorship`
provenance and participates in the AI-attribution rules while a note never does; and collection
exports treat the two completely differently.

The implementation findings stand and do not expire — zero schema cost (`authorship` already
exists), the `CollectionAIAttribution.label()` call being unconditional in three exporters, and the
`document_cache.summary_text` last-push-wins hazard. Re-read §2 item 10 when it resumes.

---

## 1. The sequence

| # | Item | Status | Effort | Schema |
|---|---|---|---|---|
| 1 | **#559** keyboard never dismisses | **shipped** (#629) | XS | none |
| 2 | **#597 Phase 0** — repair + guard | **shipped** (#630) | XS | none |
| 3 | **#553** Project Home leads, Step 1 | **shipped** (#631) | S | none |
| 4 | **#561** duplicate prompts | **shipped** (#632) | S | none |
| 5 | **#597 PR 2** — Research Guide | **shipped** (#633) | S | none |
| 6 | **#597 Phase 1** — first-contact tips | **shipped** (#634) | S | none |
| 7 | **#597 recall** — "Show Tips Again" | **next** | **S** (small) | none |
| 8 | **#562** corpus proximity axis | ready | M (small) | none |
| 9 | **#560** bulk summarization | ready | M (mid) | none |
| — | **#586** facet sort | **HELD** — scope expanding, see §0b | was S (large) | none |
| — | **#626** editable summaries | **HELD** — design question open, see §0b | was M (large) | none |

*(#597 is three items because its parts are genuinely different sizes and ship separately. Later
tip phases 2–4 are sized in §2 but deliberately not scheduled.)*

**Tie-breaks.** #559 before #597 Phase 0 — both XS, but #559 is one file and a daily irritant.
#553 before #561 — #553 Step 1 is ~20 lines and its owner decision is now made, while #561 is a
seeder split plus a lossless cleanup pass. The guide pass before the tips: it is the highest
value-per-hour item in the set, and under the owner's own division of labour the tips point *at*
capabilities the guide explains — building the signposts before the destination is written is the
wrong order. #586 after the tips because it is the larger S and carries a correctness-ordering
constraint. #562 before #560 — #562 is contained; #560 has more files and retracts a shipped
promise. #560 before #626 — #560 splits into a shippable subset; #626 has no cheap half.

**De-risking argument for slot 2.** The tip-suppression half of Phase 0
(`Tips.hideAllTipsForTesting()` under the existing `FRUS_UI_TEST_MODE` flag) protects every later
item that touches the rail or search. Without it a popover intercepts `app.buttons[…].tap()` and
the symptom is "the tap did nothing" — the exact misdiagnosis `UIObstructionTests` records having
cost three investigations. Do it early or it becomes a mystery failure during item 10.

---

## 2. Per issue

### 1 · #559 — Corpus Analytics keyboard (XS)

`AnalyticsView.swift` has no focus management at all: `grep FocusState` returns four files and this
is not one of them, `scrollDismissesKeyboard` returns zero hits app-wide, and `addTerm()` never
touches focus. Four small edits in one file: add `@FocusState`; **hoist `termField` out of
`ViewThatFits`** (it is instantiated in both candidates, and two live subtrees carrying `.focused()`
on one binding is not a supported shape); attach `.focused()` + `.submitLabel(.search)`; resign at
the end of `addTerm()`, **`#if os(iOS)`-gated** — ungated, Mac users lose focus after every Return.
Add `.scrollDismissesKeyboard(.interactively)` once on the body. Also fix the dangling
`testKeyboardPersistsAcrossTerms` reference at `AnalyticsRotationTests.swift:100`, which names a
function that does not exist.

**Acceptance.** Physical iPhone, portrait: type a term, Return → keyboard dismisses, chart renders
in the freed space. Swipe the chart with the field focused → dismisses interactively. macOS: Return
*keeps* focus so a second term needs no click. Re-run `AnalyticsRotationTests` on an iPhone
destination.

**Biggest risk — not #498.** Resigning focus means the "type then rotate" path arrives at rotation
with no first responder, which is the case that always passed. The real risk is a keyboard accessory
"Done" bar, which mounts a second hosting controller the shipped `.statusBarHidden(false)` would not
cover. **Do not ship an accessory bar in this PR.**

*Correction: sized S by the investigator on "it lands in #498 territory". Re-running an existing
suite is table stakes, not implementation cost. It is XS.*

### 2, 5, 6 · #597 — TipKit, three parts (XS → S → S)

**The premise is false, and the finding is better than the request.** TipKit shipped in Session 162
and is live — but a census of `popoverTip(` / `TipView(` over the whole tree returns exactly **two**
display sites, both inside `CrossReferenceGraphView`. **`ExploreCrossReferencesTip` has no display
site anywhere** (verified: its only non-declaration reference is the `.invalidate` at
`DocumentView.swift:779`). It died when the Research Rail redesign deleted the toolbar button its
popover was attached to; the invalidate rode along on the surviving handler. **Net first-contact
discovery today is zero.**

#### Phase 0 — repair and guard (XS)

**Delete `ExploreCrossReferencesTip`; do not re-anchor it.** Its id is burned: the orphan
`.invalidate` at `DocumentView.swift:779` has been running on every document open, so for every
existing user that id is already recorded as invalidated and would never display again. Re-anchoring
ships a tip that is dead on arrival for exactly the users who have the app. Replace it with a new
type under a new id (Phase 1, tip 1) and never reuse the name.

Also in Phase 0: `Tips.hideAllTipsForTesting()` under `FRUS_UI_TEST_MODE`; change
`FRUSExplorerApp.swift:283` from `.displayFrequency(.immediate)` to `.hourly` — that line has not
been revisited since there were three tips and two display sites, and it is the app-wide
anti-pile-on lever; a **tip registry** (`type`, id literal, platforms, anchor files), modelled on
`SettingsPane`; and `DiscoveryTipWiringAuditTests`.

**Six assertions the audit can actually make.** Every declared `Tip` is in the registry; every
registry anchor file exists, passes a size floor, and contains both `.popoverTip(` and the type
name; every `.popoverTip(` in the tree names a registered type; **the id literal is pinned** (a
refactor rename silently mints a new tip and re-fires it for every user); per-platform anchor
coverage as `(file, platform)` pairs; and an **anchor denylist**. Match on the *pair*
`.popoverTip(` + `TypeName(`, never the bare substring `Tips` — `SearchSheet` has an unrelated
`showTips` toggle for the search-syntax panel.

**Also add a `UIObstructionTests` scenario.** A tip popover on the rail toggle is a new class of
transient chrome over the navigation bar, which is what that suite exists for after #486. The
anchor already carries `.accessibilityIdentifier("researchRailToggle")`.

#### Phase 1 — first contact (S, one session)

Four tips, **four anchor sites, zero double-authoring**.

| Tip | Anchor | Scope | Why priority 1 |
|---|---|---|---|
| `ResearchRailTip` | `DocumentView.swift:986` | iOS only | One unlabelled `doc.text.magnifyingglass` gates ~10 capabilities. On iPhone #404 forces the rail closed on every open, so a user who never taps it sees a plain reader with no tools at all. Nothing else buys ten capabilities with one impression. |
| `EdgeTapNavigationTip` | `DocumentView.swift:1428` | iOS only | Literally invisible `Color.clear` strips, and the **only** iOS access point for prev/next document. A DEBUG env var exists purely so developers can see them. |
| `ExamineResultsTip` | `SearchView.swift:757` | iOS only | Four readings behind one binoculars glyph, deliberately not the glyph of any child — the doc comment records it was renamed off `chart.bar` because no symbol depicts the set. |
| `FacetNarrowTip` | `FacetPanelView.swift:273` | **SHARED** | A narrowable row renders identically to a descriptive one; the only signal is a macOS-hover-only tooltip. Reaches iPhone, iPad and both macOS search surfaces from one anchor. |

Only the iPhone rail toggle needs a tip — iPad and macOS default the rail visible, so the other
three near-identical anchors stay untouched. That drops the most expensive candidate from three
sites to one. Anchor the examine tip on the **menu label**, not its items (`.popoverTip` cannot
attach inside a `Menu`'s content), and the facet tip on the **preamble**, not the row buttons
(which would mint one popover per row).

**Cost: 4 tips · 4 anchors · 8 strings · 4 files.**

#### Phases 2–4 — sized, not scheduled

Phase 2, the document/graph surface (3 tips, 3 anchors, all shared) — remove-highlight, archival
neighbours, timeline brush, plus `TipGroup(.ordered)` to sequence the graph's four tips. This is
the only screen that will own more than one tip, which is why the grouping work belongs here and
nowhere else. Phase 3, collections and working corpora (4 tips, **8 anchors** — all the
double-authoring in the program is here). Phase 4, long tail (5 tips, 5 anchors).

**Cut outright:** the macOS History window and macOS project switching are menu-bar-only, and
TipKit cannot attach to a `CommandMenu` item. These are **UI gaps, and the fix costs less than the
tip** — add "Complete History…" to the existing "My Research" menu, and a project picker to the
macOS window chrome. File two issues. Likewise iOS search-operator syntax: macOS has a labelled
"Tips" button beside the field and iOS has nothing, and a tip cannot reveal an access point that
does not exist.

#### Mechanics — four decisions

**Fire timing: the anchor is the gate.** No `Tip.Rule`, no `@Parameter`. None of Phase 1's anchors
can render during first-run indexing — the user is behind the indexing banner and the
auto-presented `WhileIndexingSheet` — and two anchors gate themselves on capability availability
already. `@Parameter` is rejected explicitly: it persists a mirror of `AppState` in the TipKit
datastore, `ResetService.resetLocalData` would leave it stale, and it cannot be seeded from
`configureTipKit()`, which runs in `init()` before the pipeline exists.

**Recall: one app-wide "Show Tips Again" button in `DisplaySettingsView`**, iterating the registry
and calling `Tip.resetEligibility()`. That view is shared since S-5b — **one edit, both platforms**
— and already owns `edgeTapNavigationEnabled`, the preference behind Phase-1 tip 2. Do *not* use
`Tips.resetDatastore()`: it throws once the datastore is configured, so at best it becomes a
next-launch reset. App-wide, not per-area: per-area done honestly means listing 16 tips by name in
Settings, which is a feature tour inside Settings — the exact thing the owner's principle rules out.

**Sequencing: `.hourly` is the sequencer.** One tip per sitting; a user exploring across a week
still collects all four. Give `ResearchRailTip` — and only it — `IgnoresDisplayFrequency(true)`,
because it gates the capabilities the others assume the user has seen.

**Multi-window: measure once, design nothing.** Both platforms can show the same anchor in two
windows. Whether TipKit arbitrates or double-fires is **undetermined** — measure on a build. The
escape hatch (`popoverTip(_:isPresented:)`) is already in the SDK at this deployment target; do not
pre-build it.

**Flag, not a decision:** tips are per-device today. In an app that syncs everything else, a tip
dismissed on iPad will reappear on the Mac. `Tips.ConfigurationOption.cloudKitContainer(_:)` would
sync them — but whether that interacts with the R-7 schema gate is undetermined, so do not enable
it without its own investigation.

#### The one thing most likely to make this fail

**A tip ships anchored on a view the user's build never renders, and nothing notices — because that
is exactly how `ExploreCrossReferencesTip` died, and the codebase contains at least two anchor sites
that would reproduce it verbatim.** `BrowserView.swift:441` is a `ProjectPickerMenu` in
`splitLayout`, which the file's own note records as unreferenced since #238 routed every size class
through `stackLayout` — it sits 52 lines above the live copy at `:493` and looks identical.
`GlobalContextView.swift` is unpresented dead code, documented at its own `:28`. The denylist
assertion must refuse both **by name, with the reason in the failure message**.

The worse inverse: a naive "does any file contain `.popoverTip(RailTip())`?" assertion passes when
the only anchor is inside `#if os(macOS)` — reporting the tip as covered while it reaches no iOS
user. That is the same class of defect as #617 hiding a collection toggle from every Mac user, which
is why coverage is asserted as `(file, platform)` pairs.

And the part no source scan can do: every tip PR must carry a visual-review checklist naming the
device, the tap sequence and the expected popover. The audit proves the modifier is in the file;
only the owner's eyes prove the file is on screen.

### 4 · #561 — duplicate default prompts (S)

`SummarizationPromptSeeder.seed(in:)` dedups by localized name and runs from one call site inside the
once-per-process boot, so its dedup pass sees the store *as it exists at boot* — and SwiftData's
CloudKit initial import lands after that. Second device: boot → empty → seed 8 → import delivers 8 →
the user sees 16 **for the rest of the session**, collapsing only at the next cold launch. On macOS
that is days. The reporter's "probable cloud sync cause" is right.

The hook already exists and was simply not used: the debounced post-import block at
`FRUSExplorerApp.swift:1852-1865` already runs three repair passes 8 s after imports go quiet, for
exactly this reason. Split `seed` into `seed` + `collapseDuplicates(in:)` and call the collapse from
that block. Make it lossless: **re-point `GeneratedSummary.promptId` to the keeper before deleting**
the duplicate. Keep the earliest-`createdAt` keeper rule, add the `id.uuidString` tiebreak
`DuplicateRecordCleanup.stableKeeper` already uses, and promote the removal log out of `#if DEBUG` —
these are synced deletions.

**Biggest risk.** Keeper divergence. If two devices pick different keepers they delete each other's
survivor and the prompt is gone everywhere. Never rank by anything that differs mid-sync.

### 3 · #553 — Project Home leads (S) — Step 1, decision made

Both halves reproduce. `leadRow` renders only the header plus "Related to N of your documents",
because `ProjectLeadEntry` stores no body text and `ProjectLeadsService` deliberately passes
`includeSnippets: false` (it runs up to 40× per recompute). And `openDocument` calls `onNavigateAway`
— the sheet presenters pass `{ showProjectHome = false }` — then pushes onto the *Browse* stack, so
Back pops to the Browse root. One sub-claim in the report is already false: iOS **search** results
push into Search's own stack and do not dump into Browse.

**Step 1 (~20 lines).** Populate `leadSnippets` once for the ≤24 displayed leads via
`IndexingPipeline.documentSnippets(forKeys:maxLength:)` — the same point-lookup
`RelatedDocumentsEngine` already uses for shown rows — and render 2–3 lines. **Key the fetch on the
lead key set, not `projectId`**, or a recompute leaves snippets pointing at leads that are gone. Do
not flip `includeSnippets` in the service.

**Decided:** snippets first. The framing point stands as a note for later — the reporter's stated
complaint is *navigation*, and a peek sheet routes around it rather than fixing it. If richer rows
do not settle it, the fix that matches the report is pushing the document into the sheet's own
`NavigationStack`, the pattern `SearchView` already uses successfully. Not a peek.

### 7 · #586 — facet sort and reachability (large S)

**The owner's framing is the right one, and it makes this a reachability defect.** Facets are meant
to be a way to *manage* results, not just read their shape — and they already are: **facet rows are
tappable and narrow the search** (`Button { onNarrow(narrowing) }` at `FacetPanelView.swift:445`,
writing real `SearchSQLFilters` fields and surfacing as a clearable chip). I under-read that in the
first pass. The management capability exists; what is missing is the ability to **reach the slice you
want**.

And the report's premise about years is wrong in a way that makes the case stronger. Years are *not*
sorted by count — it is `ORDER BY k DESC` (year descending, verified at
`IndexingPipeline.swift:2335`), truncated to 50. On a broad query the visible head is metadata noise
(2024|1, 2023|1…) and **everything before roughly 1953 is unreachable**. So the slices a historian
most wants to work with are precisely the ones no amount of scrolling reaches today.

One product file. Raise the limit so every bucket returns (years and volumes are corpus-bounded; cap
people ~5,000), sort locally, and use the `controls:` slot that already exists on
`AnalyticsCollapsibleSection`. Add a display cap — "Show top 10 / 25 / 50 / All". Rewrite the
truncation string, which hardcodes "Showing the **top** N" — false the moment the sort is
alphabetical. Persist with `@AppStorage`, per the `SearchCollocationDefaults` precedent. Label the
people sort **"A–Z (name as filed)"**: 94.4% of rollups are already surname-first, and normalising to
a true surname would file Mao Zedong under "zedong".

**Biggest risk.** The facet list is `ScrollView { VStack { ForEach } }` — **not lazy**. 14k rows hangs
the panel on both platforms. The display cap must ship in the *same PR* as the raised limit; it is
the guard, not a nicety. And the sort control must not land before the limit rise, or you get a
correct-looking wrong list — alphabetising the top-50-by-count is not the alphabetical list.

**Still cut: explicit paging** (1-10, 11-20…) — but re-examined against the owner's justification,
not just on cost. "Work with slices in different orders" is delivered by *sort + Show top N / All*:
the user picks the order, then takes as much of it as they want, and every value stays one tap from
narrowing. Paging adds a page index that must reset on `invalidate(signature:)` or page 7 of the
previous match survives into a new one — and it makes a value's position depend on a mode the user
has to remember. If living with sort + All shows a real need to work a long list in fixed chunks,
add it then; it is additive and nothing here forecloses it.

### 8 · #562 — corpus proximity axis (small M) — **SHIPPED**

**Built, and the design changed under measurement.** The curve below is what was in this plan; what
shipped is different, because four of this section's premises turned out to be false. Recorded here
rather than overwritten, since the shape of the error is the useful part.

**What shipped.** Same volume → `0.60 + 0.40 × max(containment, print-adjacency)`; same subseries →
`0.50` unchanged; else absent.

- **containment** = `ln(N / u) / ln(N / 2)`, where `u` is the unit count of the smallest section
  holding both documents and `N` is the volume's total. Units are **sections plus documents**. It
  measures *how much of the volume the shared container excludes* — not how deep it is.
- **print adjacency** = 1.0 / ⅔ / ⅓ at a reading-order gap of 1 / 2 / 3, else 0, over whole-volume
  order.

Composed by `max`, so the axis reports the single strongest placement statement the editors made and
cannot exceed 1 without a clamp.

**Why volume-relative rather than depth-based.** This is the answer to "nesting practice varies", and
it is a better one than the depth ratio below: a single-child wrapper — a compilation holding one
chapter and nothing else, which 13–14% of corpus documents sit under (39.8% in 1950s volumes) — is
one unit here and a whole level under a depth ratio. Measured on 91,780 real same-volume candidate
pairs the shipped curve gives mean 0.756, sd 0.134, **4,650 distinct values**; the curve below puts
**57.96% of that same pool into one 0.9 bucket** and emits 13 distinct values. It was a two-value
function on the data it would actually see.

**Premises in this section that were false.**

1. **"Never build the global-ordinal version — it forces `currentDateIndexVersion` up and a corpus
   reindex."** False. Whole-volume reading order was rebuilt for all 552 volumes directly from the
   *stored* `structure_json`. No parse change, no reindex. The prohibition rested on a cost that
   does not exist, and cross-section adjacency shipped.
2. **"…to buy adjacency for 2.2% of documents."** Does not reproduce. On the real candidate pool it
   is 280 of 14,080 adjacent pairs (1.99% of adjacent pairs, 0.31% of the pool); corpus-wide the
   successor-crosses-a-boundary rate is 4.99%. The term is worth keeping because it is free, not
   because it is large.
3. **"160 volumes are flat, 449 one deep, 167 two deep."** Sums to 776 against a 552-volume manifest.
   They are non-exclusive membership counts, not a partition. The real argument is different and
   stronger: 211 of 552 volumes hang documents at more than one level *inside the same volume*, so
   depth is not even constant within a volume.
4. **"Sections holding both documents and subsections are ~0."** 267 sections (1.06%) across 73
   volumes. Harmless — 244 of the 267 have the documents as a strict prefix, so depth-first order is
   still right — but the ordering for the other 23 is an approximation, and the doc comment says so.

**One premise that held, and one doubt that was wrong.** `AxisWeights` *does* conform to
`RawRepresentable`; the conformance lives in `RelatedDocumentsView.swift`, not beside the type, which
is why it is easy to miss. `init?(rawValue:)` skips unknown tokens and no read path merges defaults,
so renaming `case subseries` would ship as a silent weight-0 for every user who has moved the slider,
and would compile clean. Only `displayName` changed — to **"Corpus proximity"**, the owner's own name
from the issue title.

**The unbuilt design that is worth not rediscovering.** Folding the two terms into one measure —
`min(lcaSpan, |Δposition| + 1)` over a single sequence — is mathematically inert. Both documents
always lie inside their container's positional range, so the interval wins 100% of the time and the
editorial-container term never fires at all. The symmetric `2d+1` variant only partly fixes it: the
container still binds just 9.44% of the time, and the axis becomes an ordinal-distance measure that
largely restates `dateProximity`.

**Degradation.** A same-volume candidate that cannot be placed scores exactly `0.60` — never `1.0`
(a silent revert to the old flat behaviour, indistinguishable from success) and never `0` (which
would strip the row's chip and drop it below the subseries tier). `0.60` is also what a genuinely
unarranged volume earns, so the degraded value states the truth rather than inventing refinement.
Coverage is currently 552/552 with the set difference empty both ways, but `storeIndexData` is
deliberately non-transactional with the structure write last, so the population is empty rather than
impossible.

**Cost.** One `cachedVolumeStructure` fetch per `rank()`, anchor volume only. No reindex, no
index-version bump, no schema change, no CloudKit deploy. Net cost may be negative: the per-call
552-entry `subseriesByVolume` map is gone, and the stale comment defending it (`entry(forVolumeId:)`
has been an O(1) dictionary hit for some time) went with it.

---

<details>
<summary>The original plan for this issue, superseded by the above</summary>

`SubseriesScorer` is a two-branch step: same volume → 1.0, same subseries → 0.5. **The enabling
finding: the full per-volume hierarchy is already indexed and queryable** — `volume_structures` is
written on every index run and read by the existing public
`IndexingPipeline.cachedVolumeStructure(forVolumeId:)`, with `VolumeSection.documentIds` giving exact
within-section order. **No reindex, no index-version bump.**

Curve: adjacent in the same leaf section → 1.0; same leaf → 0.9; same volume otherwise →
0.6 + 0.4 × (common-ancestor depth ÷ **the anchor's own path depth**); different volume, same
subseries → 0.5 unchanged.

**Biggest risk.** Silent degradation: if `cachedVolumeStructure` returns nil the axis quietly reverts
to today's flat 1.0 and nobody notices.

</details>

### 9 · #560 — bulk summarization (mid M) — **PR A SHIPPED**

**The run was reconstructed from the owner's own store, and neither this section nor the issue
described what actually happened.** `ZGENERATEDSUMMARY` timestamps identify the run exactly: 1,364
documents, 5 volumes, 313.6 minutes, starting 2026-06-03 15:26.

**It was not uniformly slow, and it was not stalled.** Only **60.8 minutes** of that run sit in gaps
of 60 s or less. **252.8 minutes — 81% — sit inside just 43 gaps longer than a minute.** Per volume
the rate collapses as the documents grow:

| volume | documents | minutes | s/document |
|---|---|---|---|
| frus1872p1 | 502 | 15.9 | 1.9 |
| frus1872p2v1 | 512 | 48.8 | 5.7 |
| frus1872p2v2 | 272 | 133.9 | 29.5 |
| frus1872p2v3 | 40 | 71.6 | 107.3 |
| frus1872p2v4 | 38 | 43.6 | 68.8 |

The stalls are **clusters of adjacent enormous documents saturating every concurrency permit** —
`frus1872p2v4` holds `d39` at **1,282,843 characters**, `d38` at 375,632, `d35` at 172,340. They are
not proportional to the document that ends them: a 194-character document sits behind a 905 s stall.
And during a stall `run()` published `currentDocumentId: nil`, so the app showed a frozen count
**with no document name and no other signal**. The owner quit fourteen documents from the end of a
run that was working.

**The issue's own premise is false.** "M1 Max should have much better multithread performance" does
not apply: generation runs in a shared system daemon and serialises. Cores are not the resource.

**What shipped (PR A — truthful accounting).**

1. **Count successes, not attempts.** `counter.increment()` sat outside the `do/catch`, whose catch
   was one `#if DEBUG print`. A run in which every document failed rendered as a green
   "Completed — 1400 documents summarized" with a matching push notification, and zero rows written.
   `BatchRunTally` now separates succeeded / failed / skipped / attemptable.
2. **Skipped documents leave the denominator.** `total` was fixed before the skip check, which then
   `continue`d without counting. A re-run over an already-summarized scope sat at 0 of 1,400 for its
   whole duration and reported "0 of 1400 documents summarized" — a no-op in the exact vocabulary of
   total failure. The skip is now resolved during enumeration, in one fetch.
3. **`.failed` became reachable.** It was declared, rendered in three places, pinned by three tests —
   and *never assigned anywhere in the app*. It now fires on mid-run model loss and on
   zero-successes-with-failures.
4. **Progress is monotonic.** Two publish sites raced; one read the counter *before* its work. There
   is now exactly one publisher, polling one consistent snapshot at 2 Hz — which also turns ~4,200
   main-actor hops into ~600.
5. **Terminal errors stop retrying.** `withRetry` retried everything non-cancellation at 30 s of
   sleep per document **holding a concurrency permit**. `SummarizationRetryPolicy` is a *blocklist*,
   so an unrecognised error keeps today's behaviour.

**Premises in this section that were false.**

- *"1,400 documents each burn 30 s while the counter marches to Completed"* — the structural hazard
  is real, but it did **not** happen in this run. The four longest `p2v4` documents were **in flight
  and cancelled**, not failed after retries: five retry passes would need ~1,095 model calls in a
  2,616 s window, i.e. 2.3 s/call, when the same volume was observably running at 4.33 s/document.
- *"Enumeration progress. A 1,400-result search spans ~157 volumes."* — this run spanned **five**.
  Enumeration cost ~1.4 s of 313 minutes, 0.007%. The real argument for changing the text source is
  peak memory, which is a different issue.
- *"`@AppStorage` the concurrency setting"* and the Stepper copy — still true, still worth doing, but
  they are PR B, not the fix.
- *"The concurrency setting is not the lever."* Too strong. Generation does serialise (mean
  inter-completion gap is invariant at ~2.2–2.6 s from C=3 to C=12), but on a **contended** machine
  concurrency hides per-call turnaround: 1.42× at C=2 rising to 1.84× at C=6. Background
  summarization is by definition the contended case. **Keep the Stepper at 1...6.**

**Still true, and the honest headline:** none of this makes the run faster. 60.8 minutes were real
work and 252.8 minutes were stalls; both remain. What changed is that the app stops claiming success
it did not achieve.

**PR B (not yet built).** Sub-document progress — thread a step callback out of `SummarizationService`
so a 131-chunk document reports "part 12 of 131" instead of a frozen count; persist the concurrency
limit; replace the false Stepper hint ("may exceed the model's rate limit" — there is no rate limit
and no rate-limit handling anywhere in the app); one honest sentence at the point of commitment.

### 10 · #626 — editable summaries on document surfaces (large M)

The affordance exists in exactly one shared place (`CollectionEntryInspector`) and every
document-facing surface is read-only and authorship-blind: `SummaryStripView` hardcodes
`Label("Summary", …)` and `SummaryBlockView` hardcodes `Label("AI summary", …)` regardless of
authorship. **`GeneratedSummary.authorship` already exists and is already deployed, so the schema cost
is zero** — that is what puts this in M rather than L.

Put the rule on `DocumentViewModel` — one `commitEditedSummary` mirroring `commitHeadnote` (trimmed
no-op guard; AI-derived seed → `.aiEdited`, else `.userWritten`) — so only *presentation* is
duplicated. It must additionally coerce `responseFormat` to `.general` when editing a `.structured`
row, and push to `IndexingPipeline.updateSummaryText` or FTS5 keeps matching the deleted AI text. Add
"Write your own summary" to **both** the no-summary branch and the Apple-Intelligence-unavailable
branch — the second is the whole point on non-AI hardware. Mint a reserved sentinel `promptId` as the
headnote path does, or the row inflates a real prompt's tallies.

**The export follow-through is not optional.** `CollectionAIAttribution.label()` is **unconditional**
and is called from the HTML, DOCX and PDF exporters. Ship the edit affordance without it and a
user-written summary exports under "AI-generated summary · Apple Intelligence (on-device)" in three
formats — exactly the defect #625 just fixed for JSON, re-created. `headnoteLabel(authorship:)` is
the template.

**Biggest risk.** `document_cache.summary_text` is one column per document while a document can own
up to 20 `GeneratedSummary` rows — last push wins. Worse, the pre-existing boot sync fetches every
`GeneratedSummary` with **no `!isHeadnoteDraft` filter**, so a collection headnote draft can already
overwrite a document's searchable summary on the next launch. Pre-existing and out of scope, but a
user-editable summary makes it visible and blameable — **file it separately**. Second: the classic
parity trap — the two views are in opposing `#if os` blocks, so the chip and commit rule get no
compiler help. Pin with a parity test, per `CollectionExportToggleParityTests`.

---

## 3. Groupings

**Ship together.** #559 + #597 PR 1 — disjoint files, both ~3-file diffs, both gated on the same
physical-device sitting. #560's five items as one PR: they are one story, "make the run tell the
truth", and splitting them makes each look arbitrary. **#626's two halves must ship together** — the
edit affordance without the export attribution change *is* a shipped mislabelling bug; if they must
split, ship the exporter change first.

**Must not ship together.** #560 and #626 — both say "summaries", and that is the trap: one touches
the provider and batch engine, the other two platform-private views plus three exporters. A combined
diff spans the whole summarization stack and is unreviewable. #562 with anything — a ranking change
needs an isolated before/after. #553 Step 1 and Step 2 — snippets are ~20 lines; bundling makes the
cheap fix wait on the expensive decision.

---

## 4. Schema gate

**None of the eight requires a CloudKit Production deploy as scoped.** Current state:
`deployedIdentifierCount = 233`, `deployedThroughBuild = "37"`, `identifiersAwaitingDeploy` empty.

That holds **only if four tempting shortcuts are refused**, each +1 identifier and an owner
round-trip that cost three PRs on the last one-boolean deploy:

| Issue | Shortcut | Instead |
|---|---|---|
| #553 | add `snippet` to `ProjectLeadEntry` | fetch live from SQLite for the ≤24 shown leads |
| #626 | add `originalAIText` to `GeneratedSummary` | mint a **second** summary; the carousel already holds 20 |
| #586 | a synced sort preference | `@AppStorage` |
| #597 | `Tips.ConfigurationOption.cloudKitContainer(_:)` | do not enable; whether TipKit's record types surface in the container is undetermined |

`CloudKitSchemaInventoryTests` is the tripwire: if it goes red on any of these, the implementation
reached for a shortcut and should be reverted, not accommodated. **Every item here can be started on
a day the owner cannot reach the CloudKit Dashboard.**

---

## 5. What I would cut

1. **#597 phases 2–4** — sized in §2, deliberately not scheduled. Commit to Phase 0 + 1, ship, live
   with it a build cycle, then re-decide each. Phase 3 is the one to interrogate hardest: it is 40%
   of the anchor sites for 25% of the tips, and it is where the shared/private split stops
   protecting you. *(Not a decline — a staging.)*
2. **Two #597 candidates that are UI gaps, not tips** — the macOS History window and macOS project
   switching are menu-bar-only and TipKit cannot attach to a `CommandMenu` item. Adding
   "Complete History…" to the existing "My Research" menu and a project picker to the macOS chrome
   costs less than the tip would. File as two issues.
3. **#560's generation controls** — defer to its own issue; the only part that can silently change
   summary quality.
4. **#553 Step 2 (the peek sheet)** — deferred by owner decision; revisit only if richer rows do not
   settle the navigation complaint.
5. **#586's explicit paging** — re-examined against the owner's justification in §2 and still cut,
   with the condition under which to add it.
6. ~~**#562's global-ordinal version** — forces a corpus reindex to buy adjacency for 2.2% of
   documents.~~ **Both halves false, and it shipped.** Whole-volume reading order is recoverable
   from the already-stored structure with no reindex; see §8.

---

## 6. Open questions for the owner

Three of the four original questions are now answered (#553 snippets-first; #597 build the
discovery layer; #586 sorting is first-class). What remains:

**Q1 — #560: what happens to the concurrency Stepper?** Measurement says 6 is 1.0–1.4× faster than
1, and the hint currently promises otherwise. *Lean: narrow to 1–3 and rewrite the hint. Removing it
outright is the most honest and least code, but retracting a shipped setting is a bigger statement
than the finding warrants.*

**Q2 — #562: normalise by the anchor's own path depth, and leave subseries at 0.5?** **ANSWERED by
measurement.** Subseries stayed at 0.5, and the monotone-safety argument held — better than expected,
since the branch *predicates* are untouched, so the set of candidates scoring above 0 is provably
identical and no row enters or leaves a result list. Anchor-relative depth was rejected: it is
asymmetric, which is incoherent when Project Leads sums the axis across many anchors, and depth
itself proved to be the wrong quantity.

**Q3 — #626: edit in place, or mint a second summary?** Both are zero-schema; storing the original
*on the row* is not. *Lean: mint a second. It costs one carousel entry and it is the only option that
lets you compare what the model wrote against what you corrected — which, for a provenance record, is
the point of the feature.*

**Q4 — #597: should tips sync across your devices?** They are per-device today, in an app that syncs
everything else, so a tip you dismiss on iPad will greet you again on the Mac. Enabling
`Tips.ConfigurationOption.cloudKitContainer(_:)` would fix that — but whether TipKit's own record
types interact with the R-7 schema-deploy gate is **undetermined**. *Lean: ship Phase 1 per-device,
and treat syncing as its own small investigation. The annoyance is mild; an unplanned schema
identifier is not.*
