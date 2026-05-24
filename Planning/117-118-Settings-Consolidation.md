---
name: Sessions 117–118 — iOS Settings Consolidation
description: Two sessions that reduce the Volumes section of iOS Settings from
  five sub-panes to three by merging Download Manager into Volume Management
  (→ "Downloads") and merging the standalone Reindex pane into Storage Management
  (→ "Storage & Index"). A minor label fix renames "Summarization Prompts" to
  "Summarization" to match the pane's actual scope.
type: implementation
originSessionId: session-116
---

# Sessions 117–118 — iOS Settings Consolidation

The iOS Settings Volumes section currently exposes five sub-panes whose content
overlaps in ways that force users to navigate across panes to complete a single
task. The specific problems:

- **Download Manager** and **Volume Management** both answer "how do I get more
  volumes onto my device" — the first via a scope picker, the second via a
  browseable list of all available volumes — but they are separate destinations
  with no link between them.
- **Storage Management** shows per-volume indexing status and per-volume Reindex
  buttons. The **Reindex** pane contains only the Reindex All button. These belong
  together but require two navigation trips.
- The **Summarization Prompts** pane contains both prompt management and the full
  background summarization configuration, making its name misleading.

These sessions consolidate without removing any functionality.

---

## Work Item Summary

| Session | Title | Effort | Risk | Depends On |
|---------|-------|--------|------|------------|
| 117 | Consolidate Downloads | Low–Medium | Low | 49, 51, 70 |
| 118 | Consolidate Storage & Index + Summarization label | Low | Low | 51, 67, 90 |

Both sessions are independent of each other and of the Sessions 112–116 indexing
UX track. Either can be scheduled first.

---

## Session 117 — Consolidate Downloads

**Scope:** Merge `DownloadManagerSettingsView` and `VolumeManagementView` into a
single `DownloadsSettingsView`. Update `SettingsView` to remove the "Download
Manager" row and rename "Volume Management" to "Downloads".  
**Effort:** Low–Medium (one session). View consolidation; no changes to
`DownloadManager` actor or its API.  
**Risk:** Low. Both source views are display-only consumers of `AppState` and
`DownloadManager`; merging them does not touch download or indexing logic.

### Problem

`DownloadManagerSettingsView` presents a scope picker (Entire Corpus / By
Subseries / Single Volume) plus an Enqueue button and a confirmation message.
`VolumeManagementView` presents, in order: a Concurrent Downloads picker, an
Active Downloads section, a Downloaded Volumes section with swipe-to-delete, an
Available Volumes section with live search and per-volume Download buttons, and a
Check for New Volumes button.

A user wanting to download a specific subseries may reasonably reach for either
pane. After landing in the wrong one they must back out and try the other. The
scope picker and the Available Volumes browse list serve the same intent via
different interaction styles; putting them in one scrollable view eliminates the
ambiguity.

### Goal

One navigation destination ("Downloads") that supports both the bulk/scoped
enqueue flow and the browse-and-pick-individually flow, plus surfaces download
queue state and settings.

### Key Changes

**New `DownloadsSettingsView`** (replaces both source views)

Section order and content:

1. **Active Downloads** — unchanged from `VolumeManagementView`. Volume ID rows
   with individual Cancel buttons; empty-state message when idle. Shown only when
   `appState.downloadQueue` is non-empty (use `if !downloadQueue.isEmpty` to
   suppress the section header when nothing is active rather than showing an
   empty section).

2. **Find Volumes** — merged from both source views. A `Picker` with three
   cases (Entire Corpus, By Subseries, Single Volume) above the existing dynamic
   content block from `DownloadManagerSettingsView` (subseries dropdown or
   volume-search field depending on selection), followed by the Enqueue button and
   its success/failure message. Below the picker block, a thin divider introduces
   the Available Volumes browse list from `VolumeManagementView` (search field +
   paginated results + per-row Download buttons). The heading for this combined
   section is "Find Volumes"; a short footer reads "Use the scope selector to
   enqueue a group at once, or search and download volumes individually below."

3. **Downloaded Volumes** — unchanged from `VolumeManagementView`. Swipe-to-delete
   with confirmation dialog. Empty-state message.

4. **Settings** — the Concurrent Downloads picker from `VolumeManagementView`,
   relabelled from its current Section header to fit a `LabeledContent` row for
   consistency with the rest of the pane.

5. **Check for New Volumes** button — moved here from `VolumeManagementView`.
   Placed as a plain `Button` in a trailing-footer position below the Settings
   section.

**`SettingsView.swift` — Volumes section**

Remove the `DownloadManager` `NavigationLink`. Rename the `VolumeManagement`
`NavigationLink` label from "Volume Management" to "Downloads" and update its
destination to `DownloadsSettingsView`.

Update localization keys:
- Remove `settings.row.downloadManager`
- Change `settings.row.volumeManagement` default value from `"Volume Management"`
  to `"Downloads"`
- Add `settings.downloads.findVolumes.footer` for the footer text

**`DownloadManagerSettingsView.swift`**

File can be deleted. Confirm no other call sites reference it before removal.

**`VolumeManagementView`**

Rename to `DownloadsSettingsView`. Update the navigation title string from
`"Volume Management"` to `"Downloads"` (localized key
`"downloads.navigationTitle"`). Integrate the Find Volumes scope-picker block
from `DownloadManagerSettingsView` between the Active Downloads section and the
Available Volumes section as described above.

### Tests

`DownloadsSettingsViewTests` — verify Active Downloads section is hidden when
queue is empty; verify enqueue button produces the same `DownloadScope` values
as the former `DownloadManagerSettingsView` for all three picker cases; verify
Check for New Volumes calls `manifestStore.fetchLiveManifest()`; verify
swipe-to-delete confirmation dialog appears before deletion.

---

## Session 118 — Consolidate Storage & Index + Summarization Label

**Scope:** Move the Reindex All Volumes button and its progress stream into
`StorageManagementView`; rename the pane to "Storage & Index"; remove the
standalone `ReindexView` navigation entry from `SettingsView`. Additionally,
rename the "Summarization Prompts" settings row to "Summarization".  
**Effort:** Low (one session). Reindex UI is self-contained; the move is
mechanical.  
**Risk:** Low. The Settings tab badge that directs users to reindex already
resolves to the Volumes section; after this change users land in Storage & Index
which now contains both the per-volume and all-volumes reindex controls.

### Problem

`StorageManagementView` already shows each downloaded volume's indexing status
and a per-volume "Reindex" button (added in Session 67). When a user wants to
reindex everything, they must leave this view and navigate to a separate `ReindexView`
that contains only: one paragraph of explanatory text, one button, and a progress
display. This split means the pane with the most indexing context (Storage) lacks
the bulk action, while the pane with the bulk action (Reindex) lacks all context.

Separately, `SummarizationPromptsSettingsView` contains the full background
summarization configuration (scope picker, concurrency stepper, start/stop
controls, progress view) in addition to prompt CRUD. The pane name
"Summarization Prompts" causes users configuring the background task to doubt
they are in the right place.

### Goal

All reindex controls — per-volume and all-volumes — live in one pane. The
Summarization pane label matches its actual scope.

### Key Changes

**`StorageManagementView.swift` — absorb Reindex All controls**

Add a `@State private var reindexProgress: IndexingProgress = .idle` and
subscribe to `indexingPipeline.progress` in `.task` using the same stream
subscription pattern already present in `ReindexView`. This is a direct copy of
the stream-consumer code; no new API on `IndexingPipeline` is needed.

Add a new section at the bottom of the view, below the per-volume list:

```
Section("Reindex") {
    // Explanatory footer text (moved from ReindexView's "About Reindexing" section)
    // Reindex All Volumes button (disabled while reindexProgress is .indexing)
    // Progress display: spinner + "X/Y — volumeId" label (same as ReindexView)
    // Completion: green checkmark + "Completed: X volumes, Y documents"
    // Error: red triangle + error message
}
```

The per-volume Reindex buttons remain in their current rows; they function
independently of the stream subscription used by Reindex All.

Rename the view's navigation title from `"Storage"` to `"Storage & Index"`
(localized key `"storage.navigationTitle"`, default value `"Storage & Index"`).

**`SettingsView.swift` — Volumes section**

Remove the `NavigationLink` for `ReindexView` ("Reindex" row). Update the
`NavigationLink` for `StorageManagementView` label from `"Storage"` to
`"Storage & Index"` (reuse the same localized key `settings.row.storage` with
updated default value `"Storage & Index"`).

Remove localization key `settings.row.reindex`.

**`ReindexView`**

The view can be deleted after confirming no other navigation paths reference it.
On macOS, `FRUSSettingsView` has its own `ReindexView` wiring via the Corpus
tab in `NavigationSplitView` — that path is separate and must be left unchanged.
Add a `#if os(iOS)` guard confirming the deletion is iOS-only if the type is
shared; otherwise delete the iOS-only copy.

**`SettingsView.swift` — Research section**

Change the `SummarizationPromptsSettingsView` `NavigationLink` label from
`"Summarization Prompts"` to `"Summarization"`. Update localized key
`settings.row.summarization` default value accordingly. No changes to
`SummarizationPromptsSettingsView` itself are required.

**Settings tab badge behaviour**

The badge is driven by `appState.unindexedVolumeCount > 0`. Its presence
signals the user to open Settings and take a reindex action. After this session,
the recommended flow becomes Settings → Volumes → Storage & Index → Reindex All,
which is one step shorter than the previous Settings → Volumes → Reindex path
because Storage & Index is already the most-visited pane in the Volumes section.
No code change is needed for the badge itself.

### Tests

`StorageIndexViewTests` — verify Reindex All button is disabled when
`reindexProgress == .indexing`; verify progress label updates match stream
emissions; verify green completion display appears after `.completed` event;
verify per-volume Reindex buttons still function independently during an idle
all-volumes stream state.

`SettingsStructureTests` (if present, or add to `CodingStandardsAuditTests`) —
verify `ReindexView` is not reachable from any iOS navigation path after removal;
verify `StorageManagementView` navigation title string matches `"Storage & Index"`.
