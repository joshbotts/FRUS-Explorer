# Wave R — the research trail, and build-35 tester feedback

**Status:** R-0 answered 2026-07-26; **R-1 shipped 2026-07-26**. Runs **after S-6** (Settings docs closeout).
**Inputs:** `Planning/Settings-Parity-Audit-2026-07-25.md` (§B2, B3, and the deliberate-list
entry on search logging); build-35 tester feedback (not yet collected); carried work from the
2026-07-26 bug session (#486 / #488 / #498) — see *Folded in* below.

---

## The finding this wave exists for

**The app records what you read twice, through two independent systems, and the switch that
claims to control it governs only one of them.**

Open a document in `DocumentView` and two things happen about fifty lines apart:

| | `AppState.logEvent(.documentOpen)` | `DocumentViewModel.recordReadingHistory` |
|---|---|---|
| Fires at | `DocumentView.swift:397` | `DocumentView.swift:446` |
| Writes | `SessionEvent` → `ResearchSession` | `ReadingHistoryEntry` |
| Gated by `researchSessionLoggingEnabled`? | **Yes** (`AppState.swift:497`) | **No gate of any kind** |
| Read by | `SessionLogView` only | History window, Project Home, Project Leads' engaged-documents, the search checklist, the storage hub's last-opened dates |
| Carries | volume, document, title, timestamp | volume, document, title, project, timestamp |

So the switch labelled **"Log Research Sessions"** stops the recorder that nothing consumes and
leaves running the one that feeds five features. A user who turns it off to stop the app
remembering what they read has not stopped the app remembering what they read.

The same shape holds for searches, with the platforms swapped:

| | `.searchSubmit` event | `SearchHistoryEntry` |
|---|---|---|
| Producer | `SearchViewModel.swift:505` — **iOS only** | `MacSearchViewModel.swift:749` — **macOS only** |
| Gated? | Yes | No |
| Records the query text | Yes | Yes |

Net effect across two devices: an iPhone records your search text into a gated log nothing reads;
a Mac records your search text into an ungated store the History window reads. Neither device
shows you the other's searches. **Both** stores sync via CloudKit.

This is not a duplication to be tidied — it is a **privacy-honesty bug** plus a **feature gap**
wearing the same clothes, and that is why the two belong in one wave rather than being fixed
piecemeal.

---

## R-0 — Decide the model *before* writing any code

> ### ✅ ANSWERED — owner decisions, 2026-07-26
>
> **Q1 → (a) Collapse to one trail.** `ReadingHistoryEntry`/`SearchHistoryEntry` become *the* trail.
> `ResearchSession`/`SessionEvent` are retired and sessions are **derived at read time** by grouping
> entries on the 30-minute idle rule. One store, one gate. R-2 owns the migration for records already
> in users' iCloud private databases.
>
> **Q2 → Keep recording search text, and keep syncing it.** It is the user's own data, and since
> PR #503 it is visible and deletable in Settings. No sync exclusion, no count-only reduction. This
> makes R-4 (an iOS producer for search history) straightforwardly correct once R-1 has landed — but
> **the ordering trap in R-4 still applies**: R-1 must land first, or iOS starts writing search text
> into an ungated store.
>
> **Q3 → Keep the label "Log Research Sessions".** No rename. Existing testers know it and the pane
> is named to match. The `UserDefaults` key `researchSessionLoggingEnabled` was never in question and
> does not change either. **Consequence for R-1 and R-5:** the label stays engineering-flavoured, so
> the *footer* carries the whole explanatory burden — it must say plainly that the switch governs
> reading history and search history as well, since the name will not imply it.

The three questions, as originally posed:

**Q1. One trail or two?**
- **(a) Collapse.** `ReadingHistoryEntry`/`SearchHistoryEntry` become the trail; `ResearchSession`/
  `SessionEvent` are retired, with sessions derived by grouping entries on the 30-minute idle rule
  at read time. One store, one gate, one thing to explain. Cost: a migration, and the loss of the
  session grouping as stored data (it becomes a query).
- **(b) Keep both, gate both.** Sessions stay as the "what happened, in order" log; the history
  entries stay as the "what have I touched" index. Both honour the switch. Cost: two stores to
  keep honest, forever, and a switch whose scope needs explaining.
- Recommendation: **(a)**. Two records of the same event is how this drifted apart in the first
  place, and the derived-session query is a dozen lines.

**Q2. Does the trail record search *text*?**
Today it does, on both paths, and syncs it to iCloud. Options: keep it (it is the user's own data,
now visible and deletable since PR #503); keep it but exclude it from sync; or record only the
result count. This is the owner's call and should be written down wherever it lands.

**Q3. What should the switch actually promise?**
"Log Research Sessions" is engineering vocabulary. If the trail becomes one thing, the control is
better named for what it governs — **"Remember What I Read"** or similar — with the honest footer
that PR #503 already drafted. Renaming the *label* is free; the `UserDefaults` key
`researchSessionLoggingEnabled` must not change (user-data-bearing, and mirrored into a CloudKit
record via `SyncedPreferences.researchLoggingEnabled`).

---

## R-1 — Close the gate (do this regardless of Q1)

> ### ✅ SHIPPED — 2026-07-26
>
> One reader: `AppState.researchLoggingPreferenceKey` + `AppState.isResearchLoggingEnabled(in:)`
> (absent means on). All three writers route through it; `SettingsSyncCoordinator` and the
> `ResearchSessionsView` `@AppStorage` binding take the key from `AppState` rather than
> re-declaring the literal, and `SettingsView`'s orphaned `@AppStorage` (unread since S-1) is gone.
> Covered by `FRUSExplorerTests/ResearchLoggingGateTests` — behavioural for the two writers the
> iOS test bundle can reach, source-shape for the macOS one it cannot, plus a guard that fails
> when a *fourth* producer of a history entry appears. **R-4 is now unblocked.**
>
> **One correction to the finding above.** The pre-R-1 macOS footer's "searches are recorded on
> iPhone and iPad but not here" was true of the **session log** only. macOS is the sole producer of
> `SearchHistoryEntry` and does record search text — into the store the History window reads. Both
> platforms record searches; what differs is the store, and hence which surface empties when the
> switch goes off. The rewritten footers say so. Anything downstream that inherited the old
> framing (R-5's copy pass especially) should be re-read against this.
>
> **R-5 is partly pre-empted, not done.** The Manage footer no longer calls reading history
> "separate", but `ResearchSessionAdmin.deleteAll` still reaches the session log only — the copy
> now says that explicitly rather than implying otherwise. Extending the delete is still R-5's.

Make `recordReadingHistory` and `recordSearchHistory` honour the same preference `logEvent` does.

- Extract the gate to one place — `AppState.isResearchLoggingEnabled` — so there is a single
  reader of the key rather than three call sites doing `UserDefaults.standard.object(forKey:)`.
- Apply it at `DocumentViewModel.swift:529` and `MacSearchViewModel.swift:749`.
- **Test:** with the preference off, opening a document inserts neither a `SessionEvent` nor a
  `ReadingHistoryEntry`. That test does not exist today for any of the three writers.
- **Consequence to state in the PR:** turning the switch off will now visibly empty History and
  the Project Home recents over time. That is the honest behaviour, but it is a behaviour change
  and the copy must say so.

Independent of Q1, small, and it is the half of this wave that is a *correctness* fix rather than
a feature. Could ship before the rest.

## R-2 — One trail, one store

Executes Q1's answer. If (a): migrate `SessionEvent` payloads into `ReadingHistoryEntry`/
`SearchHistoryEntry`, derive sessions at read time, retire the two models from `frusModelTypes`,
and keep `SessionLogView` pointed at the derived grouping. Needs a migration story for records
already in users' iCloud private databases.

## R-3 — A History surface on iOS

`HistoryWindowView` is macOS-only (`#if os(macOS)`, reached by the `frus.history` scene and the
Research ▸ History menu). iOS has no view over the trail at all — the nearest thing is Project
Home's per-project recents, and only when a project is active.

- Shared view, per the S-programme pattern: a `HistoryView` both platforms render, macOS in its
  window, iOS pushed from the Research tab.
- Depends on R-2 if the model collapses; otherwise it must read both stores.
- This is the largest single "my Mac can do things my iPad cannot" left in the app.

## R-4 — Search history on iOS

`SearchHistoryEntry` has exactly one producer and it is macOS-only, so even after R-3 the iOS
History screen would show reading but no searches, and the Mac would show only searches made on
the Mac. Add the producer to the iOS search path. **Note the ordering trap:** doing this *before*
R-1 would start recording iOS search text into an ungated store — strictly more collection than
today. R-1 must land first.

## R-5 — Delete, export, and the copy

- `ResearchSessionAdmin.deleteAll` (PR #503) deletes sessions only. Whatever R-2 settles on, the
  delete must cover the whole trail, and Data & Recovery's **Contents** inventory should list it —
  it currently accounts for notes, tags, highlights, collections, prompts and projects, and is
  silent about the trail entirely.
- Research-data export (`ResearchDataExportView`) likewise omits the trail.
- Re-do the Research Sessions pane's copy against whatever the wave settles: the footers written
  in #502/#503 are honest about *today* and will be wrong the moment R-1 lands.

---

## Folded in — the 2026-07-26 bug session (#486 / #488 / #498)

Three items surfaced while fixing unrelated bugs. **R-6 belongs to this wave on the merits, not
just for want of a home**: Wave R exists because the app claims something it does not do — a switch
labelled "Log Research Sessions" that governs one of two recorders. R-6 is the same species one
layer down: the app reported a sync failure it had made itself unable to describe.

### R-6 — Make a CloudKit failure diagnosable

`cloudKitDiagnostic` (`FRUSExplorer/App/FRUSExplorerApp.swift:2007`) looks for the per-item error
dictionary at exactly one level:

```swift
if ..., let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
```

On a miss it falls through to domain + code only. `grep` over `FRUSExplorer/` returns **zero**
readers of `NSUnderlyingErrorKey`, `NSMultipleUnderlyingErrorsKey`, `CKErrorRetryAfterKey`, or
CloudKit's server error text — so on that path every channel that could name the rejected record
type is discarded. That is why #488's log line was a bare `CKErrorDomain partialFailure (2)` and the
diagnosis had to be reconstructed from the CloudKit Console and a `git diff` instead.

- Walk `NSUnderlyingErrorKey` / `NSMultipleUnderlyingErrorsKey` (bounded depth) for the dictionary —
  `NSPersistentCloudKitContainer` can re-vend a `partialFailure` whose sub-errors sit one level down.
- Record `hadPartialDictionary` so **"we looked and found none" is distinguishable from "we never
  looked"** — the ambiguity that cost the most time on #488.
- Extract **schema identifiers only** from the server text via a strict allow-list regex
  (`CD_[A-Za-z0-9_]+`, `_pcs_data`). **Never the raw string** — it can carry record names and field
  values, and #188-C.1's redaction contract has no mechanical gate, so a later "simplification" to
  log the description would silently become a PII leak.
- New fields on `SyncDiagnosticsEntry` must be optional-with-default: `SyncDiagnosticsLog.loaded()`
  swallows a decode failure with `try?` and would wipe the very history being kept.
- Zero test coverage today (`grep` for `cloudKitDiagnostic` / `SyncDiagnosticsEntry` across both test
  targets returns nothing). The error shapes are constructible offline with no CloudKit account.

**Runbook while this is unbuilt:** `Planning/488-CloudKit-Capture-Runbook.md`.

### R-7 — Build the schema-deploy release gate that was already specified

`Planning/188-189-Tester-Feedback-Build28-Plan.md:158` called for "a startup log line if the
installed model set is newer than a known-deployed marker, so a future undeployed-schema regression
is caught before shipping." It was never built. #488 **is** that regression: build 35 added four
CloudKit identifiers (`CD_ProjectLeadEntry`, `CD_Project.CD_leadAxisWeights`,
`CD_Project.CD_defaultUserTagIds`, `CD_Collection.CD_includeProjectProvenance`) with no deploy gate
covering them, and the last recorded gate in `DEVELOPMENT-PLAN.md` is for build 33.

Pair it with the inventory test: pin `frusModelTypes` to a checked-in list so adding a `@Model`
fails the suite until the list, the version-history block in `ModelContainer+FRUS.swift` (**still
says "16 record types" when the list holds 18**), and a deploy-gate line are all updated. A gate
nobody is forced to update is theatre — the failure message must carry the checklist.

### R-8 — iPad: the analysis toolbar button reads its SF Symbol name aloud

On iPad the Browse analysis-menu button's accessibility label resolves to the raw symbol name
`chart.bar.xaxis` rather than "Analysis Tools", so VoiceOver announces "chart bar xaxis".

- **Verified:** the label is wrong on iPad — found because it broke an XCUITest element lookup that
  worked on iPhone; the button is only reachable there after expanding the toolbar overflow.
- **Inferred, not confirmed:** that the overflow re-hosting is what drops it. `ControlHelp.swift:51`
  does apply `.accessibilityLabel(label)` on iOS, so the modifier is present — something downstream
  is overriding or discarding it. Confirm the mechanism before choosing a fix.
- Cheap and worth doing regardless: the same `.controlHelp` pattern is used across the app, so if
  overflow drops the label generally, this is not a one-button bug. Audit the other overflow-prone
  toolbars before scoping.

### R-9 — "Index Required" on an indexed volume, and a mute "Index Now"

At the compilation level the app can show **"Index Required"** for a volume that is fully indexed,
with an **"Index Now"** button that does nothing — no progress, no error, no log line.

**The trigger is not what it first looked like.** It was reported as "after a successful download +
index", which is wrong and would have sent someone hunting in the indexing pipeline. Reproduced on
unmodified `v2` (`7a9370e`), iPhone 17 Pro, one install, one database:

| Launch | Browse → volume → Chapter 1 |
|---|---|
| Normal | "Documents (5)" — healthy |
| `FRUS_UI_TEST_MODE=1` | **"Index Required"**; "Index Now" is inert |
| Normal again | "Documents (28)" — healthy |

Ground truth across all three: `SELECT COUNT(*) FROM document_cache WHERE volume_id='frus1989-92v31'`
→ **250**. The volume was indexed every time; the banner is simply lying. The real trigger is
**launching with `ContentView`'s onboarding gate bypassed**, which is what every UI test does.

**Root cause (verified in source).** `BrowserViewModel.indexingPipeline` is captured once and never
back-filled — `BrowserViewModel.swift:147` (`let`), copied by `bootstrapViewModel()` at
`BrowserView.swift:563-576` from `.onAppear`, before `FRUSExplorerApp.swift:1317` has assigned it.
Two guards then fail *silently*:

```swift
guard let pipeline = indexingPipeline else { return false }   // :345 → "Index Required"
guard let pipeline = indexingPipeline else { return }         // :359 → "Index Now" no-ops
```

`indexingError` is never set, so `CompilationView.swift:432`'s error line stays hidden and the
button is completely mute. Only the compilation level asks `isIndexed`, which is why nothing higher
looks wrong: `loadVolumeStructure` falls back to parsing the XML when the pipeline is nil.

**This is the unfixed half of closed issue #324.** That fix added `attachDownloadManagerIfNeeded`
plus an `onChange` back-fill — **for `downloadManager` only**. `indexingPipeline` never got the
equivalent, so the same defect simply moved one level down (VolumeView "Download Required" →
CompilationView "Index Required"). No open issue covers it.

**Why it is not a shipping-user emergency, and the one path where it is.** In the normal path the
`ContentView` gate requires `hasVolumes`/`hasActiveDownloads`, both of which need
`appState.downloadManager`, assigned *after* the pipeline — so users do not reach the browser in the
bad state. **But** `FTS5Store` and `IndexingPipeline` are both built with `try?`
(`FRUSExplorerApp.swift:1309-1311`) while `DownloadManager` is created outside that block. If either
throws, the pipeline stays nil for the session, the gate still opens, and **every** compilation shows
"Index Required" with a dead button and no error surfaced anywhere. That path was not forced in
testing — worth forcing before deciding the priority.

macOS is unaffected: `MacCorpusBrowserWindow.swift:888` reads the pipeline live and `.disabled`s its
button — a disabled control rather than a mute one, which is the behaviour to copy.

**Cost today:** it blocks UI-test coverage of everything below the volume level — the same class of
blocker #324 was filed for.

**Fix shape:** mirror #324 (`attachIndexingPipelineIfNeeded` + `onChange` back-fill), or read the
pipeline from `AppState` live. Independently, the `indexVolume` guard should set `indexingError` so
the button can never be silently mute again.

---

## Tester feedback — build 35

Not yet collected. Slot it here rather than in a separate wave: the settings programme touched
every pane in the app across S-0…S-6, and build 35 is the first build testers see all of it in.
Expect the feedback to cluster on surfaces this wave already opens.

**Intake checklist when the feedback arrives:**
1. Trailer through the existing triage shape (`Planning/Issues-207-219-Remediation-Plan.md` is the
   precedent for a tester-feedback wave: group by surface, not by reporter).
2. Cross-reference against `Planning/Settings-Parity-Audit-2026-07-25.md` — several audit entries
   are things a tester will independently report, and they should be merged rather than fixed
   twice. Likely candidates: the macOS hub's hover-only explanations (§D1), "Check Console.app"
   (§D2), the missing macOS settings search (§B4), and the inert precompute toggle (§B5).
3. Anything a tester reports about "the app remembers/doesn't remember what I read" belongs in
   R-1, not in a separate bug.

**Known-unverified items worth pointing testers at**, all from this session:
- The iOS Volume Scopes swipe-delete guard (shipped but not exercised on device — a scope would
  not persist in the simulator).
- The populated Notes list and All Notes screen on iOS.
- `ResearchSessionAdmin.deleteAll` end-to-end (unit-tested only; the log on the dev machine is
  real research history).

---

## Suggested order

**R-1 → (Q1 answer) → R-2 → R-3 → R-4 → R-5**, with tester feedback triaged into whichever step it
lands on. R-1 can go early and alone; R-3 is the item with the most user-visible value and should
not start before Q1 is settled, or it will be built against a model that then changes.

The folded-in items are independent of that chain and of each other, so they can be slotted wherever
they fit. If any of them go early, take **R-6 and R-7 together** — they are one story (the app could
not describe the failure, and the gate that would have caught it before shipping was never built),
and doing either alone leaves the other looking optional. **R-8** is small and unblocked.

**R-9 has a claim on going first**, for a reason that is not its user impact: it blocks UI-test
coverage of everything below the volume level, so any later work that wants a test at document grain
pays for it anyway. Its fix is also already written down — #324 solved the identical problem on the
sibling field, so this is applying a known pattern rather than designing one. Force the `try?`
failure path described in the entry before deciding whether it is also a shipping-user bug.

## Standing constraints

- Do not change the `researchSessionLoggingEnabled` key string. It is user-data-bearing, untested,
  and mirrored into CloudKit via `SyncedPreferences.researchLoggingEnabled`.
- `ResearchSession.events` is `.nullify`, so any deletion path must remove events explicitly or
  orphan them (`ResearchSessionAdmin` documents this; a test pins it).
- Both stores are in `frusModelTypes` and therefore CloudKit-mirrored — any schema change needs a
  migration story for records already in users' private databases.
- House rules as ever: implementer ≠ reviewer, PRs base `v2`, visual-review checklist in every UI
  PR body, `build-for-testing` before claiming green.
