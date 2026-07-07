# Build 28 Tester Feedback — Development Plan (Issues #188 & #189)

Planning doc for the two umbrella tester-feedback issues filed against build 28:

- **#188** — *Tester feedback on build 28 (bug reports)* — 5 items
- **#189** — *Tester feedback on build 28 (feature requests)* — 4 items

Investigation date: 2026-07-06 (v2 branch, HEAD `2d0081e`). No code changed yet — this is a plan.

---

## Issue #188 — Bugs

### 188-A. Analytics screens need an iPhone (compact-width) layout pass

**Report:** "New analytics screens need dedicated pass for iPhone layout — toolbar controls are cramped and/or distorted."

**Current state.** The corpus/person/cross-ref analytics screens stack every control into
`.primaryAction` toolbar slots with **no compact-width reorganization**:

- `FRUSExplorer/Analytics/AnalyticsView.swift` lines ~1534–1644 — 6+ primary-action items
  (view-mode picker, raw/% normalization picker, "Group by" axis picker, fit-line toggle,
  colors menu, info button, + iOS Done). On an iPhone in portrait these compete for
  horizontal space → truncated labels ("% of documents") and overflow.
- `FRUSExplorer/Analytics/PersonAnalyticsView.swift` lines ~898–937 — mode picker + view-mode
  picker + decade toggle + normalization picker, same flat `.primaryAction` layout.
- `FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift` lines ~508–521 — only 2 controls;
  low risk, but should be swept for consistency.
- Series dashboards (`FRUSExplorer/SeriesAnalytics/*Dashboard.swift`) put filters **inline**
  under the title (`AnalyticsYearRangeBar`) rather than in the toolbar — no cramping.

**The pattern to adopt.** `FRUSExplorer/Analytics/WordCloud/WordCloudView.swift` (lines ~470–569)
already solves this: a `.principal` segmented view-mode picker + a single **Options `Menu`**
(`.primaryAction`) that wraps all secondary toggles/pickers, so the toolbar never overflows.
`FRUSExplorer/Analytics/AnalyticsChartChrome.swift` (`AnalyticsYearRangeBar`,
`AnalyticsViewModePicker`) already drops its text label on `.compact` width.

**Proposed approach.**
1. On compact width, collapse the secondary analytics controls (normalization, axis/"Group by",
   fit-line, colors) into one `Menu` ("Options"), mirroring WordCloud. Keep the view-mode
   picker in `.principal` and the info button visible.
2. On regular width / macOS, keep the current inline toolbar buttons (they fit).
3. Gate with `horizontalSizeClass == .compact` (already read at `AnalyticsView.swift:151`).
4. Verify person + cross-ref screens with the same helper.

**Files touched:** `AnalyticsView.swift`, `PersonAnalyticsView.swift`,
`CrossReferenceAnalyticsView.swift`, likely a shared helper in `AnalyticsChartChrome.swift`.

**Note the dependency on 189-B:** the corpus-slicing feature adds *more* controls (subseries/
decade/volume filters). Do this toolbar refactor **first or jointly** so the new filters land in
the compact-width Menu instead of re-cramping the bar.

---

### 188-B. Page-based cross-references still broken in Cross-Reference Analytics

**Report:** "page-based references in cross-reference analytics still broken. use the landmark
docs list as testing anchors" (screenshot of the CA-6 landmark/PageRank list).

**This is not the same bug PR #184 fixed — it's the layer above it.** PR #184
(`c92868d`, index v21, shipped in build 28) correctly fixed *table-level* resolution:
`<ref target="#pg_427">` fragments now resolve `pg_427 → dN` in
`IndexingPipeline.resolvePageBasedCrossReferences` (lines ~4429–4507) via the shared
`PageSpanResolver`. Verified 738/999 arabic page refs resolve. **But those resolved refs still
never reach the analytics dashboard.** Root cause, verified directly:

1. Page references are **same-volume**. The parser
   (`FRUSDocumentParser.parseRefTarget`, lines ~1284–1293) returns `volumeId = nil` for any
   `#`-prefixed target, so same-volume refs — including page refs — are stored with
   **`target_volume_id = NULL`**.
2. The resolver only updates `target_document_id` (`pg_427 → d6`); it **never sets
   `target_volume_id`**, so it stays NULL.
3. Every CA-6 analytics query filters `WHERE target_volume_id IS NOT NULL`:
   - `CrossReferenceStore.topDocumentsByInDegree` (line ~617) — the **landmark docs list**
   - `resolvedInDegrees` (line ~651), `resolvedOutDegrees` (line ~673) — degree histograms
   - `resolvedCitationEdges` (line ~702) — the **PageRank** edge set
   The stated rationale is that a NULL target is "ambiguous across volumes." That's true for a
   bare `#dNN` we can't place — but for a **same-volume** ref the target volume *is* the source
   volume, so it is not actually ambiguous. Consequently every same-volume edge (all resolved
   page refs, plus all same-volume document refs) is dropped from the landmark ranking,
   degree distributions, and PageRank.

So PR #184 was necessary but not sufficient: it resolved the rows in the table but the analytics
layer discards them.

**Proposed approach (attribute same-volume edges to the source volume).**
Make same-volume references attributable to the node `(source_volume_id, target_document_id)`.
Two implementation options:

- **Option 1 — fix at the query layer (lower risk, no re-index):** in the four
  `CrossReferenceStore` queries, group/attribute on
  `COALESCE(cr.target_volume_id, cr.source_volume_id)` and treat a same-volume edge as pointing
  at `(source_volume_id, target_document_id)`. Keep the self-loop exclusion. No schema change,
  no re-index, but every read path must apply the rule identically.
- **Option 2 — fix at write time (one source of truth, needs re-index):** when a reference is
  same-volume (resolved page ref, or a `#dNN` doc ref), set
  `target_volume_id = source_volume_id` in `extractCrossReferences` /
  `resolvePageBasedCrossReferences`. Then the existing `IS NOT NULL` filters just work and the
  data is self-describing. Requires bumping `currentDateIndexVersion` (21 → 22) per the
  index-version-bump rule, forcing a one-time re-index.

**✅ DECISION (2026-07-06): all edges · write-time · re-index (Option 2).** Attribute **all**
same-volume edges (page + document refs) to the source volume at **write time** in
`extractCrossReferences` / `resolvePageBasedCrossReferences`, and **bump
`currentDateIndexVersion` 21 → 22** (one-time re-index). This makes the data self-describing so
both read paths can't diverge (the "one source of truth" lesson from PR #184). **Expected
behavior change:** CA-8 landmark rankings and PageRank will shift — within-volume citations (the
bulk of the graph, currently invisible) now count. That is intended and more correct; update the
CA-6/CA-8 disclosure copy ("resolved cross-references" now includes same-volume) and reset test
expectations accordingly.

**Testing anchors:** the tester's screenshot is the landmark docs list; use those documents plus
the PR #184 spot-checks (page 5→d6, 8→d9, 11→d11 in frus1961-63v06) to confirm the resolved page
refs now appear with non-zero in-degree.

**Files touched:** `CrossReference/CrossReferenceStore.swift` (queries), possibly
`Search/IndexingPipeline.swift` (write-time attribution + version bump),
`Analytics/CrossReferenceAnalyticsView.swift` (disclosure copy — "resolved cross-references" now
includes same-volume), and the CA-6 / `CrossReferenceStats` tests.

---

### 188-C. CloudKit `partialFailure` (error 2) — tags & collections not syncing (production)

**Report:** "CloudKit sync — still have CKErrorDomain partialFailure (error 2) on iPhone and
iPad. Still have tags and collections that are not syncing across devices using production
schema."

**Current state.** The `Collection`/`CollectionEntry` and `UserTag` models look CloudKit-clean
on inspection: `.nullify` delete rules with declared inverses, optional/defaulted attributes,
no `@Attribute(.unique)` (`Models/Collection.swift` ~250/~395; `Models/UserTag.swift` ~27–59).
The schema registers 16 model types in
`Models/ModelContainer+FRUS.swift` (lines ~54–71), including newer ones
(`PersonClusterOverride`, `SyncedPreferences`). There is already CloudKit diagnostic decoding in
`App/FRUSExplorerApp.swift` (~1361–1672, `cloudKitDiagnostic`).

**Leading hypothesis.** `partialFailure` on **production** with otherwise-valid models most often
means the **Production CloudKit schema is stale** — a record type or field exists in the
Development schema but was never promoted to Production, so those records fail per-item while the
rest of the batch succeeds. New model types (`PersonClusterOverride`, `SyncedPreferences`) are
the prime suspects; a newly-added field on `UserTag`/`Collection` would do the same.

**Proposed approach.**
1. **Diagnose the actual per-item error first.** Surface the decoded `partialFailure` sub-errors
   from `cloudKitDiagnostic` in a copyable form (log to a file / a hidden Settings diagnostics
   pane) so we see exactly which record type + which field CloudKit rejects, rather than guessing.
2. **Compare Development vs Production schema** in the CloudKit Dashboard for container
   `iCloud.bottsywattsy.FRUS-Explorer`. Confirm every one of the 16 record types and all their
   fields exist in Production. **(User action — I can't deploy the schema; this is a Dashboard
   step.)**
3. **Deploy schema changes to Production** if any drift is found. This alone likely fixes the
   reported symptom for new-record-type syncs.
4. **Defensive code:** add a schema-version note / deployment-date comment beside `frusModelTypes`
   and, optionally, a startup log line if the installed model set is newer than a known-deployed
   marker, so a future undeployed-schema regression is caught before shipping.

**Files touched:** `App/FRUSExplorerApp.swift` (diagnostics surfacing),
`Models/ModelContainer+FRUS.swift` (versioning note), possibly a small Settings diagnostics view.
**Plus an operational step in the CloudKit Dashboard (user).**

**Caveat:** this item is diagnosis-led. The plan's step 1 (get the real sub-error) may redirect
steps 2–4. Do not skip straight to a code fix.

#### 188-C.1 — Client-side CloudKit sync telemetry off production/TestFlight devices

**Motivation:** complement server-side CloudKit Console logs with a client-side timeline from
testers' devices. **Not possible in the current build in any usable way.**

**Current state (verified).** The app already captures the right signal — it observes
`NSPersistentCloudKitContainer.Event` and decodes `partialFailure` per-item sub-errors
(`App/FRUSExplorerApp.swift` `cloudKitDiagnostic`, ~1655–1672) and surfaces the message via
`appState.cloudKitSyncState`. But every CloudKit sink is a plain **`print`**
(`FRUSExplorerApp.swift` 1383/1657/1663/1672; `App/AppState.swift` 290–310), which reaches stderr
only — **visible solely when tethered to Console.app/Xcode**. On a field TestFlight device nothing
is retrievable: no unified-log entry, no `OSLogStore`, no sysdiagnose capture, no MetricKit, no
upload. The only client-side signal a tester can give today is a **screenshot of the in-app
sync-status message** (latest state, no history, no per-item detail). (`IndexingPipeline` uses
`os.Logger` and *would* appear in a sysdiagnose — but that's indexing, not CloudKit.)

**Proposed approach.**
- **A — Persisted in-app sync-event log + export (primary; no backend):** capture every container
  Event (phase setup/import/export · start/end · succeeded/failed · decoded error · timestamp ·
  device) into a **bounded local-only** ring buffer (file or a non-synced store — diagnostics must
  not themselves sync). Add a **"Sync Diagnostics"** view in Settings showing the log as
  **copyable text** (paste into TestFlight feedback) **and** a **`ShareLink` file export**
  (Mail/Files/AirDrop). Reuses the existing `ShareLink`/`fileExporter` pattern
  (`App/SupportingViews.swift` ~2194; `ResearchDataExportView`).
- **B — Route CloudKit through `os.Logger` (cheap, do with A):** replace the CloudKit `print`s with
  `Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "CloudKit")`, marking safe fields
  `.public` (unmarked redacts to `<private>`). Gives a sysdiagnose fallback and lets an optional
  `OSLogStore` reader power the same export view from the system store.
- **Skip C — MetricKit + server upload:** value only at fleet scale, needs a backend, ~daily
  cadence. Defer.

**Privacy — LOCKED: redact all user info; record only what diagnoses functionality gaps.** The
log is built from an **explicit allow-list**, never by serializing the raw `NSError`/`userInfo`
(which can embed `CKRecord`s, server records, and synced content). Everything on the allow-list is
safe by construction, so it may be marked `.public`; anything not on the list is simply not logged.

- **Record (safe — schema, error taxonomy, counts, timing, environment):**
  - Event phase (setup / import / export), start/end timestamps, duration, succeeded/failed.
  - Error domain + code + human code-name (e.g. `CKErrorDomain 2 partialFailure`).
  - Per-item sub-errors **aggregated by `(recordType, errorCode)` → count** (e.g.
    `CD_UserTag code=14 batchRequestFailed ×12`). Record **type** and **field/key names** are
    schema, not user data — keep them.
  - Coarse environment: app version/build, OS version, device model string (`iPhone15,2`).
- **Never record (redact — identifying or content):**
  - CloudKit **record names/IDs** (`CKRecord.ID.recordName`), zone **owner**/participant IDs,
    iCloud/`CKUserID`, emails. (The default private-zone name is a constant and safe; any custom
    zone/owner identifier is redacted.)
  - **Field values** / synced content (tag names, collection names, note text) — never.
  - Free-text `localizedDescription` that may interpolate a record name — prefer
    `code`+`codeName`; if description is kept, scrub IDs first.
- **Concrete change:** the current per-item line (`App/FRUSExplorerApp.swift` ~1663) logs
  `item \(itemID)` — the record name, which is identifying. The redacted version drops per-item IDs
  and emits the `(recordType, errorCode)→count` aggregate instead.

**Files touched:** `App/FRUSExplorerApp.swift` + `App/AppState.swift` (Logger swap; feed the
buffer), a new local sync-event store, a new **Sync Diagnostics** view added to **both**
`Settings/SettingsView.swift` and macOS `FRUSSettingsView` (dual-settings rule). Small–medium.

**Sequencing:** this is the enabling mechanism for **188-C step 1** — build it first within the
CloudKit session (Session 3) so the real per-item error can be collected from a tester before
attempting the schema/model fix.

---

### 188-D. Live-update user tags — new tags don't appear as search chips

**Report:** "check feasibility of live updates to user tags (current behavior is that new tags do
not show up as chips in search, etc.)."

**Feasible — straightforward.** Root cause: tags are fetched **once, imperatively**, with no
SwiftData observation.

- `Search/SearchViewModel.swift` (~263–267) `loadAvailableUserTags(context:)` does a one-time
  `context.fetch(FetchDescriptor<UserTag>)` into a plain `availableUserTags` array.
- `Search/SearchView.swift` (~201–226) calls it once inside `.task {}`.
- `Search/SearchFilterView.swift` (~340) iterates the stale `vm.availableUserTags`.
- Tag creation paths (`ResearchNoteEditor/ResearchNoteEditorViewModel.swift` ~150–161;
  `App/SupportingViews.swift` ~2507–2512) update their own local copies, never the SearchVM's.

**Proposed approach (recommended: `@Query`).** Move the available-tags list to a SwiftData
`@Query(sort: \UserTag.name)` owned by the view (`SearchView` or the filter view), and pass it
into the VM / filter panel, so newly-created tags appear live without restart. Remove the
imperative `loadAvailableUserTags`. If the VM must stay the owner, fall back to a
NotificationCenter refresh on tag create — but `@Query` is cleaner and idiomatic.

**Files touched:** `Search/SearchView.swift`, `Search/SearchViewModel.swift`,
`Search/SearchFilterView.swift`. Small.

---

### 188-E. Collection editor layout review (iPad & Mac)

**Report (iPad):** tap anywhere in a doc row should refocus the inspector (not just the info
button); change inspector heading from "Document Details" to the collection name; add a top
section for collection-level attributes so they're reachable after refocusing on a document.
**(Mac):** left blank by the tester — treat as "review for the same issues."

**Current state.**
- Row → inspector is wired **only** through the ⓘ info button
  (`Collections/CollectionEntryRows.swift` ~636–644 → `onInspect` →
  `CollectionEditorView.presentEntryInspector` ~1677–1682). The row body has no tap gesture.
- Entry inspector heading is the generic `"Document Details"` / `"Section Details"`
  (`Collections/CollectionEntryInspector.swift` ~215–222).
- Inspector content is driven by `inspectedEntryId` (`nil` → collection metadata; non-nil → entry)
  in `Collections/CollectionEditorView.swift` (~193/198, ~708–724) and mirrored on macOS in
  `Collections/MacCollectionManagerView.swift` (~438, ~553–555). When an entry is inspected,
  collection-level attributes are not reachable without clearing the selection.
- The `Collection` model already has all the collection-level fields to surface (name, note,
  subtitle, authorLine, colophon toggle, composition defaults) — `Models/Collection.swift` ~48–281.

**Proposed approach.**
1. **Whole-row tap-to-inspect:** add `.contentShape(Rectangle())` + `onTapGesture { onInspect() }`
   to `EntryRow` (respecting the six entry kinds); keep the ⓘ button as an explicit affordance.
   (`CollectionEntryRows.swift`.)
2. **Heading = collection name:** pass `collection.name` into `CollectionEntryInspector` and use it
   as the `navigationTitle` when inspecting an entry. (`CollectionEntryInspector.swift`,
   `CollectionEditorView.swift`, `MacCollectionManagerView.swift`.)
3. **Persistent collection-level section:** add a top section (name/note/subtitle/author/colophon +
   composition defaults, read or editable) that stays visible in the entry inspector, so those
   values are always reachable. (`CollectionEntryInspector.swift`.)
4. **Mac review:** confirm the same three behaviors in `MacCollectionManagerView`'s trailing
   inspector column; fill in the tester's blank with concrete Mac fixes during the session.

**Files touched:** `CollectionEntryRows.swift`, `CollectionEntryInspector.swift`,
`CollectionEditorView.swift`, `MacCollectionManagerView.swift`. Medium.

**Pairs naturally with 189-C** (both are Collections-editor / add-document UX).

---

## Issue #189 — Feature requests

### 189-A. Rescope, regenerate & revise in-app editorial content

**Report:** "It's been a while since I made a comprehensive review of the editorial content within
the app. Need to rescope inputs for EditableContent.md, regenerate, and spend a few hours
revising."

**Current state.** `Docs/EditableContent.md` is the master markdown mirror of all user-facing
editorial prose. Each block carries an HTML-comment annotation pointing back to the exact Swift
source (`<!-- SOURCE: …AboutView.swift | property: … | lines: … | key: … -->`). The prose lives in:

- `FRUSExplorer/Settings/AboutView.swift` (`frusDescriptionRaw`, ~210–243)
- `FRUSExplorer/Onboarding/OnboardingViewModel.swift` (`bundledIntroText`, ~237–247)
- `FRUSExplorer/Onboarding/IndexingEducationView.swift` — the Research Guide: 7 prose pages
  (`page1…page7`, ~582–1000+) + 4 live dashboard pages, via
  `EducationPage`/`EducationSection` structs (~514–577).

**There is no generator tool** — round-tripping is currently manual, guided by the annotations.
Last reviewed copy was approved 2026-06-06.

**Proposed approach.** This is chiefly a **content task** requiring the user's editorial input,
plus optional tooling:
1. **Rescope:** re-sync `EditableContent.md` from current code (new analytics dashboards, People
   + Cross-Reference Analytics, collections rework, etc. have landed since 2026-06-06), so the
   markdown reflects everything now shippable and flags stale/missing sections.
2. **Revise:** user edits the prose in `EditableContent.md`.
3. **Regenerate:** write the revised blocks back into the three Swift sources using the
   annotations as the map. **Consider building a small `EditableContentSync` checker** (SPM tool
   or test) that verifies each annotated block in `EditableContent.md` matches the live Swift
   literal, so drift is caught mechanically instead of by eye.
4. Follow the standing **feature-session docs rule** (Docs manuals, TestFlight, README, in-app
   guide) at the end.

**Files touched:** `Docs/EditableContent.md`, `Settings/AboutView.swift`,
`Onboarding/OnboardingViewModel.swift`, `Onboarding/IndexingEducationView.swift`; optional new
sync-checker tool. **Blocked on user's editorial pass.**

---

### 189-B. Rich era/corpus-slicing options for the analytics features

**Report:** "Ensure rich era/corpus-slicing options available for new analytics features:
subseries, decade, year, volume, other? Goal is to make these analytical tools relevant to users
trying to explore relative trends within project-specific contexts that are hidden by absolute
corpus-wide trends."

**Current state — the plumbing largely exists; the UI does not.**
- **Year range:** fully implemented (`AnalyticsChartChrome.AnalyticsYearRangeBar`, display-time
  filtering in `AnalyticsView` ~259–292).
- **Volume scope:** every `CorpusAnalyticsService.termFrequency*()` method already takes an
  optional `volumeIds: Set<String>?` (`Analytics/CorpusAnalyticsService.swift` ~414+), surfaced
  as `AnalyticsParameters.scopeVolumeIds` and a read-only scope chip
  (`AnalyticsView.swift` ~491–519). **But it can only be *set* via the Word Cloud → Analytics
  handoff — there is no in-Analytics picker to choose a subseries/volume.**
- **Subseries / decade:** exist only as *presentation* axes (`AnalyticsChartAxis.bySubseries`,
  decade bucketing), **not as filters** that restrict the analyzed document set.
- **Normalization** (raw vs % of documents) already exists for date axes.

**Proposed approach.** Add a **scope/slice picker** to the analytics toolbar (in the compact-width
Menu from 188-A) that lets the user restrict analysis to a subseries, a volume, a volume range,
or a decade/era, then derive `volumeIds` (or a date filter) and pass it through the existing
`termFrequency*()` scope parameter — reusing the Word Cloud plumbing rather than inventing a new
path. Extend the scope chip to display the active slice and a "Whole corpus" reset.

- Subseries filter → map subseries → its `volumeIds` → existing scope param.
- Volume filter → single/multi-select from indexed volumes → scope param.
- Decade/era filter → date-range constraint (compose with the existing year-range logic and the
  normalization denominators).

**Service methods to check for scope-param parity:** `termFrequencyByYear`, `…ByDecade`,
`…BySubseries`, `…ByVolume`, and the document-total methods used as normalization denominators
(`documentTotalsByYear/Decade`) — the denominators must honor the same slice or "% of documents"
will be wrong.

**Files touched:** `Analytics/AnalyticsView.swift`, `Analytics/AnalyticsChartChrome.swift`
(picker UI), `Analytics/CorpusAnalyticsService.swift` (denominator parity), possibly
`PersonAnalyticsView.swift` for parity. **Do after / with 188-A** so the new controls land in the
compact Menu.

**✅ DECISION (2026-07-06): build the full slice picker.** All four capabilities are in scope:
**subseries filter**, **volume filter**, **decade-as-filter** (a decade/era filter that excludes
other decades, in addition to the year-range bar), **and extend the picker to Person Analytics and
the Series dashboards**, not just Corpus Analytics. This is the largest single feature in the two
issues — the Person + Series reach means auditing scope-param parity across `CorpusAnalyticsService`
**and** the person/series data paths, and the decade filter must compose with the year-range logic
and the normalization denominators. Consider splitting Session 5 into 5a (corpus: subseries +
volume + decade) and 5b (Person + Series parity) if it runs long.

---

### 189-C. Add-Document search results need previews/summaries

**Report:** "collection editor > add document > search is practically unusable because there's not
enough information about search results in the view to make selection judgments. are there cheap
possibilities for previewing or succinctly displaying document contents/summaries?"

**Yes — cheap, because the data is already in the result.** The add-document Search tab
(`Collections/CollectionAddDocumentsSheet.swift`) runs the normal `SearchService.search`, whose
`SearchResult` (`Search/SearchModels.swift` ~205–287) already carries **`snippet`** (FTS5
`snippet()` with `<b>…</b>` match highlighting) and **`sourceNote`** (archival provenance). The
current `DiscoveryPickRow` (~1321–1420) shows only header, doc id, volume, ISO date, and badges —
it **discards the snippet and source note it already has**.

**Proposed approach (no extra queries).**
1. Add `snippet: String?` / `sourceNote: String?` to `CollectionDocumentPick` (~19–48) and
   populate them in `pickFrom(_:)` (~746–752) from `SearchResult`.
2. In `DiscoveryPickRow`, render a 1–2 line snippet preview (strip/style the `<b>` tags) and
   optionally an abbreviated source note under the existing header/volume/date line.
3. Adjust row spacing to stay scannable.
4. (Optional, later) if an on-device summary already exists for a result, show it — but that's a
   secondary lookup; ship the free snippet/source-note first.

**Files touched:** `Collections/CollectionAddDocumentsSheet.swift` (`CollectionDocumentPick`,
`pickFrom`, `DiscoveryPickRow`, Search-tab row construction). Small–medium.

**Pairs with 188-E** (same file cluster / Collections-editor UX session).

#### 189-C addendum — user-adjustable snippet length (1–10 lines)

**Feasible and cheap.** The snippet is **not** SQLite's fixed-budget `snippet()` function — it is
built in-process by `SearchService.makeContextSnippet` (`Search/SearchService.swift` ~336) from
`row.bodyText`, the **full** cached plain-text body already in memory. Length is a single
`contextRadius` argument, currently hardcoded `200` (≈2 lines). No extra query, no index change.

Two ways to drive length:

- **Character radius:** thread `contextRadius` through `search()` (default `200`) sized to the
  requested lines. *Downside:* "lines" is only approximate — a character window renders to a
  different line count per font/column-width/word-length (iPhone vs macOS differ); can't guarantee
  exactly N lines.
- **`.lineLimit` in the UI (recommended):** generate one generous window once
  (`contextRadius ≈ 1000–1200`, enough for 10 lines), then clamp with `.lineLimit(userLineCount)`
  in `DiscoveryPickRow`. A `Stepper`/`Slider` (1–10) in `@AppStorage` drives it — **exact** visual
  line control, **instant** (no re-query; the match-window scan already ran), free expand/collapse.

**Caveats to honor:**
1. `makeContextSnippet` centers on the **first** match only — a 10-line snippet is 10 lines around
   that first hit, not stitched across multiple match sites. Multi-window snippets are a bigger job.
2. The window must be generous enough to fill 10 lines; near a document's start/end the visible
   snippet is inherently shorter regardless of the setting.

**Extra files (on top of 189-C base):** stepper + `.lineLimit` in
`Collections/CollectionAddDocumentsSheet.swift`; optionally a defaulted `contextRadius` param on
`SearchService.search` (~118) → `makeContextSnippet` if sizing the window server-side.
Effort: small (~half again on top of 189-C base).

#### 189-C addendum 2 — make snippet length a **global setting** with per-surface overrides

**Applies to the main search window too — it's the same shared mechanism.** The main
`SearchResultRow` already renders snippets via `SearchSnippetView` with a hardcoded
`.lineLimit(3)` (`Search/SearchView.swift` ~796), fed by the same
`SearchService.makeContextSnippet(contextRadius: 200)` path. So one change covers both surfaces.

**Design — one generation change, the rest is view-layer:**
1. **Bump the generation radius once** so up to 10 lines can be filled (`200` → ~`1000–1200`) in
   `SearchService` — cheap (`row.bodyText` already in memory), only enlarges `SearchResult.snippet`.
2. **Global default:** `@AppStorage("search.snippetLineCount")`, default `2` (current behavior).
   Settings-surface change → **edit BOTH iOS `Settings/SettingsView.swift` and macOS
   `FRUSSettingsView`** (parallel per the dual-settings rule).
3. **Per-surface overrides (LOCKED: persisted):** a Menu/Stepper (1–10) in the main search
   toolbar/filter panel **and** in `CollectionAddDocumentsSheet`'s header. Each surface has its
   own **persisted** `@AppStorage` key defaulting to a sentinel (`0` = "follow global"); effective
   lines = `surfaceValue == 0 ? global : surfaceValue`. Changing the global moves any surface still
   on "follow global"; a pinned surface keeps its value across launches. Suggested keys:
   `search.snippetLineCount.mainOverride` and `search.snippetLineCount.addDocOverride` (both default
   `0`). Each override control should offer a "Follow global" choice that writes the `0` sentinel so
   the user can un-pin.
4. **Unify rendering:** add-doc row reuses `SearchSnippetView` (`SearchView.swift` ~846) so `<b>`
   highlighting matches; both apply `.lineLimit(effectiveLines)`. No re-query on change.

**Touch-list:** `Search/SearchService.swift` (~118/~336, radius), `Search/SearchView.swift` (~796,
override + effective lineLimit), `Collections/CollectionAddDocumentsSheet.swift` (display +
override), `Settings/SettingsView.swift` + macOS `FRUSSettingsView` (global default). Still small,
but now cross-cutting (search + collections + both settings surfaces) — keep in Session 6 with a
note that it reaches the main search and settings. Same two caveats as addendum 1 apply.

---

### 189-D. "Checklist mode" in search — hide reviewed results

**Report:** "can we add an optional 'checklist mode' in search that hides results as they've been
reviewed? logic could be a filter that dynamically excludes documents in the user's read history
since the applicable search query."

**Feasible — the read-history infrastructure already exists with timestamps.**
- `Models/ReadingHistoryEntry.swift` — `@Model` with `documentId`, `volumeId`, `displayTitle?`,
  `projectId?`, and **`accessedAt: Date?`** (set to `Date.now` on init).
- Written on every document open by `DocumentView/DocumentViewModel.recordReadingHistory`
  (~533–544).
- `Search/SearchModels.swift` `SearchParameters` (~45–183) has ~15 filter fields but nothing for
  read history yet.
- Results render in `Search/SearchView.swift` (`resultsList` ~688–747, `SearchResultRow`
  ~752–844).

**Proposed approach.**
1. Add a **"Checklist mode"** toggle to the search filter UI / toolbar and a
   `hideReviewedDocuments: Bool` (plus a captured query timestamp) to the search VM.
2. When active, fetch `ReadingHistoryEntry` rows with `accessedAt >=` the **checklist-mode-enable
   timestamp** (✅ DECISION: anchor = when the mode was toggled on, not when the query ran) and
   exclude those `(documentId, volumeId)` pairs from the displayed results — so a result disappears
   once the user opens it while the mode is active. Capture/reset the anchor when the toggle flips on.
3. **✅ DECISION: add the inline "Mark reviewed" affordance** on `SearchResultRow` so users can
   dismiss a result without opening it. Prefer a **lightweight reviewed-marker** rather than
   fabricating a full `ReadingHistoryEntry` (which would pollute genuine reading history / its
   analytics) — e.g. a small local "reviewed doc keys for this checklist session" set, or a
   dedicated marker model. Confirm the marker's storage during the session.
4. Consider whether "reviewed" should be scoped to the current project (`projectId`) — the model
   already records it.

**Files touched:** `Search/SearchView.swift`, `Search/SearchViewModel.swift`,
`Search/SearchModels.swift`, `Search/SearchFilterView.swift`; reads `ReadingHistoryEntry`.
Medium. **Open decision (user):** timestamp anchor (query-run vs mode-enable) and whether to add
the explicit "Mark reviewed" affordance vs. relying only on document opens.

---

## Suggested session sequencing

Grouped to minimize cross-file churn and respect dependencies. Each row is roughly one working
session; small ones can be combined.

| # | Session | Items | Notes / deps |
|---|---------|-------|--------------|
| 1 | **Live tag chips** | 188-D | Small, self-contained; quick win. |
| 2 | **Page-ref analytics visibility** | 188-B | Backend + tests; needs the same-volume-attribution decision. Standalone. |
| 3 | **CloudKit diagnosis → fix** | 188-C + 188-C.1 | Build the client-side sync-telemetry export (188-C.1) first to collect the real per-item error, then the schema/model fix. Diagnosis-led; includes a user Dashboard step. Start early (blocks production sync). |
| 4 | **Analytics compact-width toolbar** | 188-A | Do before/with #5 so new filters land in the Menu. |
| 5 | **Analytics era/corpus slicing** | 189-B | Full scope: subseries + volume + decade filters, across Corpus + Person + Series. Builds on #4; reuses `volumeIds` plumbing. Largest feature — consider splitting 5a (corpus) / 5b (Person + Series). |
| 6 | **Collections editor UX** | 188-E + 189-C | Same file cluster (`Collections/`): row-tap inspect, heading, collection section, Mac review, add-doc snippet previews. |
| 7 | **Search checklist mode** | 189-D | Uses existing `ReadingHistoryEntry`. Anchor = mode-enable; includes the inline "Mark reviewed" affordance (lightweight marker). |
| 8 | **Editorial content pass** | 189-A | Content-led; blocked on the user's editorial revision. Ends with the standing docs pass. |

**Cross-cutting reminders:** any parse-output change (188-B Option 2) must bump
`currentDateIndexVersion` in the same commit; iOS `SettingsView` and macOS `FRUSSettingsView` are
parallel (edit both for any settings-surface change); every feature session ends with the
Docs/TestFlight/README/in-app-guide docs pass.

## Decisions — status

Resolved 2026-07-06:

1. **188-B ✅** All same-volume edges (page + document), attributed at **write time**, **index
   v21 → v22**. Expect CA-8 landmark/PageRank rankings to shift (intended).
2. **189-B ✅** Full slice picker: **subseries + volume + decade-as-filter**, extended to
   **Corpus + Person + Series**. Largest feature; may split into 5a/5b.
3. **189-D ✅** Anchor = **when checklist mode is enabled**; **add** the inline "Mark reviewed"
   affordance (lightweight marker, not a fabricated `ReadingHistoryEntry`).
4. **189-C ✅** Persisted per-surface snippet-length overrides + global default (see 189-C
   addenda).
5. **Telemetry privacy ✅** Allow-list only; redact all user info (see 188-C.1).

Still outstanding (data-dependent / operational, not blocking the code plan):

6. **188-C** — once 188-C.1 telemetry identifies the failing record type/field, confirm whether
   the **Production CloudKit schema** is current in the Dashboard and deploy changes. *User step.*
7. **188-E (Mac)** — the tester left the Mac collection-editor bullet blank. **Default:** apply the
   same three iPad behaviors (row-tap inspect, collection-name heading, persistent collection
   section) on macOS. Override during Session 6 if you want Mac-specific fixes.

## User-input checkpoints (where you're in the loop)

| Session | Your input | Kind | Timing |
|---------|-----------|------|--------|
| 1 · Tag chips (188-D) | none | — | — |
| 2 · Page refs (188-B) | *resolved* — all edges / write-time / v22 | decision ✅ | done |
| 3 · CloudKit (188-C, 188-C.1) | **(a)** run a TestFlight build, reproduce the sync failure, export & send the redacted diagnostics; **(b)** compare Dev vs Prod schema in the CloudKit Dashboard and deploy | **hands-on (only you)** | mid-session, critical path |
| 4 · Analytics toolbar (188-A) | optional visual review | — | — |
| 5 · Analytics slicing (189-B) | *resolved* — full picker, Corpus+Person+Series | decision ✅ | done |
| 6 · Collections UX (188-E, 189-C) | confirm Mac behavior (default = iPad parity) during the session | decision (minor) | in-session |
| 7 · Checklist mode (189-D) | *resolved* — anchor on enable, Mark-reviewed = yes | decision ✅ | done |
| 8 · Editorial content (189-A) | **your editorial revision pass** on `EditableContent.md` (I re-sync before, regenerate after) | **hands-on (only you)** | blocks the session |

**Net:** the three quick decisions are now closed, so Sessions 2/5/7 are unblocked. Your remaining
hands-on involvement is concentrated in **Session 3** (reproduce + export sync telemetry, then
deploy the CloudKit schema) and **Session 8** (the editorial revision). Everything else I can carry
end-to-end, with optional visual review on the UI sessions.
