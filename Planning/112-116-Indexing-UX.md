---
name: Sessions 112–116 — Indexing UX Improvements
description: Five sessions that improve the user experience during volume indexing
  and across indexing interruptions. Covers progress accuracy, live discovery feed,
  post-index summary, interrupted-state recovery, contextual FRUS content during
  wait time, and multi-volume queue visibility.
type: implementation
originSessionId: session-111
---

# Sessions 112–116 — Indexing UX Improvements

These sessions address the gap between the richness of data extracted during
indexing and the minimal feedback currently shown to users. The pipeline already
produces person counts, date coverage, cross-reference edges, and document-type
splits during the XML parse pass — none of this reaches the UI. Sessions 112–114
surface that data progressively. Session 115 closes the silent-failure gap when
indexing is interrupted mid-volume. Session 116 adds contextual FRUS content
during wait time and a queue overview when multiple volumes are downloading.

---

## Work Item Summary

| Session | Title | Effort | Risk | Depends On |
|---------|-------|--------|------|------------|
| 112 | Indexing Stage Accuracy | Low | Low | 51 |
| 113 | Live Discovery Feed | Low–Medium | Low | 112 |
| 114 | Post-Index Summary Card | Low | Low | 113 |
| 115 | Interrupted Indexing State | Medium | Low–Medium | 112 |
| 116 | FRUS Context Card + Queue Banner | Medium | Low | 113, 115 |

---

## Session 112 — Indexing Stage Accuracy

**Scope:** Rename `IndexingStage` cases to match the implementation; add a
batch-N-of-M counter to the FTS5 write phase so progress labels are honest.  
**Effort:** Low (one session).  
**Risk:** Low. UI string changes + enum rename; no logic changes.

### Background

The current four-stage sequence (`parsing`, `extractingDates`, `indexingPersons`,
`buildingFTS5`) implies four sequential passes over the data. In practice all
extraction — dates, person refs, cross-references — happens in a single XML parse
pass alongside document extraction. Only the FTS5 batch-write loop represents
real, observable elapsed time after the parse. Users who notice the first three
stages blur by in milliseconds and the fourth stage dominates will distrust the
progress indicator.

### Goal

Replace the misleading stage sequence with two honest phases and expose the
current batch number during the write phase so the progress bar never appears
stalled.

### Key Changes

**`SearchModels.swift` — `IndexingStage` enum**

Replace the four existing cases with:

```swift
public enum IndexingStage: Sendable {
    case reading                          // XML parse + all extraction
    case storingBatch(current: Int, total: Int)  // FTS5 + aux table writes
    case complete
}
```

All existing switch sites in view code and tests must be updated to handle the
new cases. The `storingBatch` associated values provide a secondary progress
signal ("batch 4 of 17") without requiring a separate count in
`IndexingProgressUpdate`.

**`IndexingPipeline.swift` — stage emission**

- At the start of `parseAndExtract()`: emit `IndexingProgressUpdate` with
  `.reading` and `completedDocuments: 0, totalDocuments: 0` (total not yet
  known).
- After `parseAndExtract()` returns and total document count is known, emit
  a second `.reading` update with `totalDocuments` set.
- In `storeIndexData()`, compute `totalBatches = ceil(documents.count / batchSize)`
  before the batch loop. Emit `storingBatch(current: n, total: totalBatches)`
  at the start of each iteration. The existing `completedDocuments` field
  continues to track documents for the progress bar; `storingBatch` is
  supplementary label text.
- Remove the spurious `.extractingDates`, `.indexingPersons` emissions.

**Progress view label updates (all four views)**

| View | Old label text | New label text |
|------|---------------|---------------|
| `IndexingBannerView` | "Parsing…" / "Building search index…" | "Reading…" / "Storing batch \(n) of \(total)…" |
| `IndexingCapsule` (SubseriesView) | stage raw text | same |
| `CorpusVolumeDetailSheet` | stage label | same |
| macOS `StatusBarView` | stage label | same |

Labels must use `String(localized:)` with interpolation for the batch numbers.

### Tests

`IndexingStageTests` — verify `.reading` is emitted before any document count
is known, then again with `totalDocuments` set; verify `storingBatch(current:total:)`
increments on each batch; verify `.complete` is the final emission.

---

## Session 113 — Live Discovery Feed

**Scope:** Emit a `VolumeMetadataDiscovered` event immediately after the XML
parse completes (before storage begins) and use it to enrich all four progress
views with person count, date coverage, cross-reference count, and
document-type split.  
**Effort:** Low–Medium (one session).  
**Risk:** Low. New event type alongside existing stream; views add new rows.

### Background

`IndexingPipeline.parseAndExtract()` already returns a `VolumeIndexData` struct
that carries every aggregate the UI needs:

- `documents.count` — total documents
- `documents.filter { $0.isEditorialNote }.count` — editorial note count
- `personMentions` — set of unique person ref IDs → count of unique persons
- `crossReferences.count` — cross-reference edges
- `documentDates.filter { $0.date_iso != nil }.count` — documents with a
  parseable date, expressed as a fraction of total
- `persons.count` — glossary persons
- `terms.count` — glossary terms

None of this is forwarded to the progress stream. The parse completes, then a
featureless progress bar runs for seconds while batches write. This session
fills that gap.

### Goal

Surface discovered-entity counts in the progress views as soon as the parse
phase ends. Make the progress display feel like watching the volume come to life
rather than watching a write operation complete.

### Key Changes

**`SearchModels.swift` — new `VolumeMetadataDiscovered` struct**

```swift
public struct VolumeMetadataDiscovered: Sendable {
    public let volumeId: String
    public let totalDocuments: Int
    public let editorialNoteCount: Int
    public let uniquePersonCount: Int
    public let crossReferenceCount: Int
    public let datedDocumentCount: Int   // documents with non-nil date_iso
    public let dateRangeMin: String?     // ISO-8601 earliest date_iso found
    public let dateRangeMax: String?     // ISO-8601 latest date_iso found
    public let glossaryPersonCount: Int
    public let glossaryTermCount: Int
}
```

**`AppState.swift`**

Add `@Published var lastDiscoveredMetadata: VolumeMetadataDiscovered?`. In
`connectIndexingProgress()`, subscribe to a new `metadataStream` (see below)
and assign values on the main actor alongside the existing `currentIndexingProgress`
assignment.

**`IndexingPipeline.swift`**

Add a second `AsyncStream<VolumeMetadataDiscovered>` property `metadataStream`
alongside the existing `progressStream`. After `parseAndExtract()` returns and
before calling `storeIndexData()`, compute the `VolumeMetadataDiscovered` struct
from `VolumeIndexData` and yield it on `metadataStream`. The pipeline actor
exposes both streams; `AppState` subscribes to both independently.

`dateRangeMin` and `dateRangeMax`: iterate `documentDates` collecting non-nil
`date_iso` strings; the min/max of that collection (lexicographic, valid because
ISO-8601 dates sort correctly as strings) form the range.

**`IndexingBannerView.swift`**

When `lastDiscoveredMetadata?.volumeId == currentIndexingProgress?.volumeId`,
show a secondary row below the progress bar:

```
312 persons · 1,247 links · 841/847 dated · 804 docs + 43 notes
```

All four counts in a single `.caption` / `.footnote`-style row. Shown from the
moment metadata arrives until the banner dismisses. If any count is zero, omit
that segment.

**`CorpusVolumeDetailSheet` (SupportingViews.swift)**

Add a `DiscoveredMetadataRow` subview below the stage label. Display the same
four counts in a two-column grid (`LabeledContent` pairs). Additionally show the
date range as a compact string: "Jan 1969 – Dec 1972" (formatted from
`dateRangeMin`/`dateRangeMax` using `DateFormatter` with `MMM yyyy` style,
falling back to raw ISO strings if parsing fails).

**`IndexingCapsule` (SubseriesView.swift)**

Too narrow for full metadata. Add a single count: unique persons only (the most
evocative signal). Format: "312 persons" in `.caption2` weight, shown below the
existing throughput line.

**macOS `StatusBarView`**

Same as `IndexingBannerView` secondary row: one-line count summary appended
after the existing ETA text, separated by " · ".

### Tests

`VolumeMetadataDiscoveredTests` — verify the struct is emitted exactly once per
`indexVolume()` call; verify field values match the parsed document set; verify
`dateRangeMin` ≤ `dateRangeMax`; verify zero-count fields are correctly zero
(not nil) for an editorial-note-only volume.

`AppStateMetadataBridgeTests` — verify `lastDiscoveredMetadata` is updated on
the main actor before the first `storingBatch` progress update arrives.

---

## Session 114 — Post-Index Summary Card

**Scope:** Show an auto-dismissing summary card after a volume finishes indexing,
recapping what was found and offering a direct search action.  
**Effort:** Low (one session; depends on Session 113 for metadata counts).  
**Risk:** Low. Additive UI only.

### Background

When indexing completes, the banner or detail sheet disappears and the user is
left with no confirmation beyond the volume gaining a checkmark. For a researcher
who just waited 60 seconds for a large volume, this is a cold ending. A brief
summary closes the loop and creates an immediate research entry point.

### Goal

Display an auto-dismissing card summarising what was indexed and offering a
"Search this volume" shortcut action.

### Key Changes

**New `IndexingSummaryCard` view**

Parameters: `VolumeMetadataDiscovered`, `onSearchVolume: (String) -> Void`,
`onDismiss: () -> Void`.

Layout:
```
✓  Foundation of Foreign Policy, 1969–1972
   847 documents · 312 persons · 1,247 links
   Earliest: Jan 20, 1969  ·  Latest: Dec 19, 1972
   [Search this volume →]
```

- Checkmark uses `Image(systemName: "checkmark.circle.fill")` tinted with
  `FRUSTheme.accentGreen` (or equivalent success color from `FRUSTheme`).
- Volume title: resolved from `ManifestStore` by `volumeId`; falls back to
  `volumeId` if not found.
- Date range row only shown when `datedDocumentCount > 0`.
- "Search this volume" button sets `AppState.pendingSearch` to a
  `SearchParameters` scoped to the volume and switches to the Search tab (iOS)
  or opens the Search window scene (macOS).
- Auto-dismiss after 6 seconds via a `Task { try await Task.sleep(...) }` in
  `.onAppear`; cancelled if the user taps anywhere on the card.

**iOS placement**

In `IndexingBannerView`: when `currentIndexingProgress?.stage == .complete`,
transition to `IndexingSummaryCard` using `.transition(.move(edge: .bottom).combined(with: .opacity))`.
The card sits above the tab bar in the same `ZStack` position as the banner.

**macOS placement**

In `StatusBarView`: same substitution when stage reaches `.complete`. The card
uses a narrower layout fitting the status bar width.

**`CorpusVolumeDetailSheet`**

When the user has the detail sheet open and indexing completes, replace the
progress section with the `IndexingSummaryCard` content inline (not floating).
The "Search this volume" button dismisses the sheet and navigates to Search.

### Tests

`IndexingSummaryCardTests` — verify card displays with correct volume title
resolution; verify auto-dismiss fires after 6 seconds; verify early dismiss
on tap cancels the timer; verify "Search this volume" produces correct
`SearchParameters.volumeId` scope.

---

## Session 115 — Interrupted Indexing State

**Scope:** Persist a sentinel when indexing begins and clear it on completion;
detect uncleared sentinels on next launch; surface partially-indexed volumes
with a distinct visual badge and a resume action; add a "Needs Attention"
section in `ReindexView`.  
**Effort:** Medium (one session).  
**Risk:** Low–Medium. New UserDefaults keys; new computed property on volume
state; no changes to existing index data.

### Background

If the app is killed while indexing (background termination, low-memory kill,
device restart), the in-flight indexing is lost and the volume silently reverts
to "not indexed." The user has no indication anything went wrong and may not
notice until a search returns no results for a volume they believed was indexed.
This session makes that failure visible and recoverable in one tap.

### Goal

Detect interrupted indexing; show a distinct "interrupted" state on affected
volumes; let the user resume with a single tap.

### Key Changes

**`AppState.swift` (or a new `IndexingStateTracker` actor)**

A new `IndexingStateTracker` actor owns a `[String: Date]` dictionary in
`UserDefaults` under key `"frus.indexingInProgress"` (JSON-encoded). The actor
exposes:

```swift
func markStarted(volumeId: String)   // writes start date to UserDefaults
func markCompleted(volumeId: String) // removes entry
func interruptedVolumeIds() -> [String]  // keys present at launch
```

`IndexingPipeline.indexVolume()` calls `markStarted` before XML parse begins
and `markCompleted` just before the final `.complete` emission. The tracker is
injected into the pipeline at construction time.

On app launch, `FRUSExplorerApp` calls `interruptedVolumeIds()` and writes the
result to `AppState.interruptedVolumeIds: Set<String>` on the main actor.

**`VolumeStatus` extension (or new computed property)**

Add `isInterrupted: Bool` to `VolumeRowLabel`'s display model, computed from
`appState.interruptedVolumeIds.contains(volumeId)`.

**`VolumeRowLabel` / `SubseriesView` (iOS)**

When `isInterrupted` is true and the volume is not currently being indexed:

- Show an amber `Image(systemName: "exclamationmark.triangle.fill")` badge
  replacing the green checkmark.
- `accessibilityLabel`: "Indexing was interrupted. Tap to re-index."
- Tapping the badge (or a contextual menu item "Re-index") calls
  `IndexingPipeline.indexVolume(volumeId)`.

The interrupted indicator takes lower visual priority than the active
`IndexingCapsule`; if a volume is actively being indexed (resumed), the capsule
shows and the amber badge is hidden.

**`CorpusVolumeDetailSheet`**

When `isInterrupted`:

- Replace the normal indexing status section with an amber alert box:
  "Indexing was interrupted and may be incomplete. Re-index to restore full
  search coverage."
- Include a "Re-index Now" button.

**macOS `ReindexView` (SettingsView.swift)**

Add a "Needs Attention" section above the existing "Reindex All Volumes" button
when `appState.interruptedVolumeIds` is non-empty. List each interrupted volume
by title (resolved from `ManifestStore`) with an individual "Re-index" button.
A "Re-index All Interrupted" button at the top of the section triggers
`IndexingPipeline.indexVolume()` for each in sequence.

**Edge cases**

- A volume that is partially indexed (some documents indexed before interruption)
  is still searchable; the amber badge communicates incompleteness, not
  unavailability.
- If a user manually triggers "Remove Volume" on an interrupted volume,
  `markCompleted` is called alongside the removal to clear the sentinel.
- The sentinel dictionary is capped at 50 entries (purge oldest by date) to
  prevent unbounded UserDefaults growth in pathological cases.

### Tests

`IndexingStateTrackerTests` — verify `markStarted` persists to UserDefaults;
`markCompleted` removes the entry; `interruptedVolumeIds` returns only uncleared
entries; sentinel purge fires at 51 entries.

`InterruptedIndexingUITests` — verify amber badge shown when `interruptedVolumeIds`
contains the volume; hidden when actively indexing; hidden after `markCompleted`;
`ReindexView` "Needs Attention" section count matches `interruptedVolumeIds.count`.

---

## Session 116 — FRUS Context Card + Multi-Volume Queue Banner

**Scope:** (A) Show a contextual information card about the volume's era and
diplomatic significance while indexing is in progress, sourced from manifest
metadata and the discovered-metadata counts. (B) When more than one volume is
queued for download + indexing, replace the single-volume banner with a queue
overview showing overall progress and a list of pending volumes.  
**Effort:** Medium (one session for both; they share the same progress-view
refactor surface).  
**Risk:** Low. Additive views; no changes to indexing logic.

### Background — Context Card

The current progress banner shows volume ID, a progress bar, and ETA. For a
researcher who just downloaded a volume for the first time, this is a cold
mechanical display. The manifest already carries `title`, `subseriesTitle`,
`startYear`, `endYear`, and `status`; the session 113 metadata stream adds
person counts and date range. Together these are enough to write one sentence of
historical context and a handful of discovery hooks.

### Background — Queue Banner

When a user has queued several volumes (e.g. downloading an entire subseries),
the banner cycles through one volume at a time with no visibility into what is
queued behind it. After returning to the app mid-queue, there is no way to see
overall progress without navigating to Downloads.

### Goal

(A) Transform idle wait time during indexing into a moment of discovery.
(B) Give users a compact queue overview when multiple volumes are in flight.

---

### Part A — FRUS Context Card

**`IndexingContextCard` view**

Shown in `CorpusVolumeDetailSheet` and on iPad/macOS below the progress bar in
the detail panel. Hidden on iPhone (insufficient space) and in `IndexingCapsule`
(too narrow). Dismissible with a chevron.

Content sections (all optional; section omitted if data is unavailable):

1. **Era header**: Volume title + year range from manifest, styled as a section
   title. Example: "Vietnam War, 1969–1976 · Volume I: Vietnam, January
   1969–July 1970".

2. **Series context**: "Part of the Nixon-Ford Subseries (14 volumes). You have
   3 downloaded." Counts resolved from `ManifestStore` by filtering
   `subseriesId`.

3. **Key persons** (only after Session 113 metadata arrives): The first 8–12
   person names from the volume's glossary, shown as chips using the existing
   subject-tag chip style. Tapping a name runs a person-ref search scoped to
   the volume.

4. **Cross-reference preview** (only after Session 113 metadata arrives and
   `crossReferenceCount > 0`): "Links to N other volumes in your library."
   "N other volumes" is a tappable link that opens the cross-reference graph
   for this volume. Count sourced from `VolumeMetadataDiscovered.crossReferenceCount`.
   The "in your library" qualifier requires filtering cross-reference target
   volume IDs against `ManifestStore.downloadedVolumeIds`; the count shown
   is the intersection, not the total edges.

**Manifest additions required**

`ManifestVolume` must carry `subseriesId: String?` to support the series-context
count. Verify this field is present in `manifest.json`; if not, add it to
`ManifestGenerator` as a separate prerequisite step within this session before
writing the view.

**Data sourcing order**

The card must render gracefully at each stage:
- Before metadata arrives: show era header + series context only.
- After `VolumeMetadataDiscovered` arrives: add persons and cross-reference
  preview.
- After indexing completes: card is replaced by `IndexingSummaryCard` (Session 114).

---

### Part B — Multi-Volume Queue Banner

**Trigger condition**

When `DownloadManager.activeDownloads.count + DownloadManager.pendingQueue.count > 1`
at the moment an `IndexingProgressUpdate` is received, the queue banner mode
is active. When the queue drains to a single item, fall back to the single-volume
banner.

**`IndexingQueueBannerView` (iOS)**

Replaces `IndexingBannerView` when queue count > 1. Same floating position
above the tab bar.

Layout:
```
[↓] Indexing volume 3 of 12           ████████░░░░  ~4 min
    frus1969-76v03 · 612 documents
```

- "3 of 12": `currentVolumeIndex` (tracked in `AppState` as a new
  `@Published var indexingQueuePosition: (current: Int, total: Int)?`) /
  total queued at session start. Increment `current` each time a new volume
  reaches `.complete`.
- Total ETA: `remainingVolumes × averageSecondsPerDocument × estimatedDocumentsPerVolume`.
  `averageSecondsPerDocument` = rolling mean of `docsPerSecond` across completed
  volumes in this queue run. `estimatedDocumentsPerVolume` = mean document count
  of completed volumes in this run, falling back to 600 (approximate corpus mean)
  until at least one volume has completed.
- A disclosure chevron expands the banner to show a list of up to 6 pending
  volumes (by title from manifest, truncated to one line each) with status icons:
  `checkmark.circle` (complete), `arrow.down.circle` (downloading),
  `clock` (queued).

**macOS**

The `StatusBarView` shows only the compact "volume N of M · ETA" line; no
expansion. Space is too constrained for a list.

**`AppState` additions**

```swift
@Published var indexingQueuePosition: (current: Int, total: Int)?
@Published var indexingQueueVolumeTitles: [String]  // ordered pending titles
```

These are set when a multi-volume download session begins (DownloadManager
notifies AppState of total queue depth) and cleared when the queue reaches
zero.

---

### Tests

**Session 116 tests:**

`IndexingContextCardTests` — verify card renders with manifest-only data before
metadata arrives; verify person chips appear after `VolumeMetadataDiscovered`;
verify cross-reference count uses downloaded-volumes intersection not raw edge
count; verify card is hidden when `horizontalSizeClass == .compact`.

`IndexingQueueBannerTests` — verify queue mode activates when `activeDownloads +
pendingQueue > 1`; verify `indexingQueuePosition.current` increments on each
`.complete` event; verify ETA formula uses rolling mean; verify fallback to
single-volume banner when queue drains to 1.

`ManifestSubseriesIdTests` (if `subseriesId` field addition is required) —
verify field is populated for all volumes in a representative fixture manifest.
