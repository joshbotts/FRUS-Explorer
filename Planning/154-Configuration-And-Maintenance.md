# Session 154 — Configuration & Maintenance Needs

## Goal
Add the app-management capabilities identified as missing in the 2026-06-10
settings review: network policy for downloads, research-data export, upstream
volume update detection, reading-behaviour preferences, index/Spotlight
maintenance actions, and a Live Activity opt-out. Each item is independent;
they can be split across sessions in the suggested order at the end.

## Prerequisites
- Background download engine in place (`BackgroundDownloadEngine`,
  Session 2026-06-09 Phase 3c) — Tasks 1 and 3 build on it.
- Settings cleanup complete (Session 2026-06-10 (3)) — `SettingsKeys` is the
  home for new preference keys; the storage limit is gone (do not resurrect it).

## Task 1 — Cellular Download Policy (highest priority)

Volume downloads (5–30 MB each; a full corpus pass ~3.4 GB) currently run on
any network. iPhone/iPad users expect a "Download over Cellular" switch.

### Requirements
- New key `SettingsKeys.allowCellularDownloads` (`"frus.downloads.allowCellular"`,
  default `true` — matches current behaviour; changing the default would
  surprise existing users mid-queue).
- Apply per-request, not per-session: `URLSessionConfiguration` is immutable
  after the background session is created, but `URLRequest.allowsCellularAccess`
  is honoured by background transfers. Set it in
  `BackgroundDownloadEngine.startDownload(volumeId:from:)` and in
  `DownloadManager.performTestDownload` (test path) from the stored preference.
- Toggle UI in both Downloads settings surfaces (iOS `DownloadsSettingsView`
  "Settings" section, macOS `SettingsAddVolumesPane` next to the concurrency
  control). Footer: applies to downloads started after the change; transfers
  already handed to the system continue under their original policy.
- iOS only; the control should be `#if os(iOS)` (macOS laptops on hotspots are
  out of scope — `allowsExpensiveNetworkAccess` is a possible follow-up).

### Testing
- Unit-test that `startDownload` builds the request with the flag from
  UserDefaults (inject via the engine? simplest: read the preference in
  `DownloadManager.processQueue` and pass to the engine as a parameter so the
  test closure path can assert on it).

## Task 2 — Research Data Export

Notes, tags, highlights, and collections exist only in SwiftData/CloudKit.
Collections export *documents*; nothing exports the user's own research
corpus. This is both a backup story and an exit ramp.

### Requirements
- Export format: a single JSON file (versioned envelope) containing:
  - `ResearchNote` (body, document/volume refs, project, tags, linked
    highlight id, timestamps)
  - `UserTag` + `DocumentTagAssignment`
  - `DocumentHighlight` (offsets, color, selected text, rendering version)
  - `Collection` + items (+ per-item annotations)
  - `SummarizationPrompt` (user prompts only)
  - `Project`
  - Optionally `GeneratedSummary` (flag-gated; can be large)
- Codable DTOs separate from the SwiftData models (the models are
  CloudKit-shaped; the export schema should be stable and documented).
- Secondary per-note **Markdown** export (one file per note, YAML front
  matter with document citation + canonical history.state.gov URL) for
  interop with Obsidian-style tools. Reuse
  `DocumentViewModel.canonicalDocumentURL` conventions.
- Entry points: iOS Settings → new "Export Research Data…" row (share sheet);
  macOS Settings → same in a Data pane (NSSavePanel). Follow the
  collection-export split pattern in `ExportSheetView`.
- Import is OUT OF SCOPE this session — but the envelope must carry a
  `formatVersion` so a future importer can be written against it.

### Testing
- Round-trip unit test: seed an in-memory container, export, decode the JSON,
  assert counts and key fields. Snapshot the envelope keys so accidental
  schema drift fails a test.

## Task 3 — Upstream Volume Update Detection

"Check for New Volumes" diffs the manifest for *new* entries, but published
volumes receive corrections upstream; a stale local XML is silently served
forever. Re-downloading is cheap now (background engine).

### Requirements
- Detection: `ManifestStore.fetchLiveManifest()` already hits the GitHub
  contents API, which returns per-file `sha` (git blob SHA) and `size`.
  Preferred: store the blob SHA of each downloaded file (sidecar table or
  UserDefaults dictionary keyed by volumeId, recorded at download completion
  — the engine can compute the git blob SHA: `sha1("blob <len>\0" + bytes)`)
  and compare against the live manifest. Fallback heuristic if SHA plumbing
  is too invasive: compare live `size` vs on-disk byte count (corrections
  virtually always change size).
- Surface: an "Updates Available" section in both Downloads settings surfaces
  listing changed volumes with an "Update" button per volume and "Update All".
  Updating = `enqueueDownload` (existing overwrite semantics) →
  `onVolumeDownloaded` re-indexes automatically; the UPSERT path preserves
  user notes/summaries/tags (Session 2026-06-09 Phase 2 guarantee — state
  this in the confirmation copy).
- Optional badge on the Settings tab row when updates exist (reuse the
  unindexed-volume dot pattern in `MainTabView`).

### Testing
- Unit test the comparison logic with fixture manifest entries (changed sha,
  changed size, unchanged).

## Task 4 — Reading Preferences

Two hardwired reading behaviours deserve switches (Display settings, both
platforms):

1. **Edge-tap page turn** — `"frus.reading.edgeTapNavigation"` (default on),
   consumed by `DocumentView.documentEdgeNavigationOverlay`. Some readers
   trigger it accidentally; accessibility reviewers flagged invisible tap
   zones.
2. **Default document mode** — `"frus.reading.defaultMode"`
   (`read` / `research` / `remember-last`, default remember-last to preserve
   today's behaviour). Today `frus.document.researchPanel.visible` silently
   persists the last choice; the preference makes intent explicit. Applies on
   document open; the in-document segmented control still overrides live.

Both are small; keep them in one "Reading" group under Display.

## Task 5 — Index & Spotlight Maintenance

The Storage pane has reindex/rebuild actions but no diagnostics.

### Requirements
- **Check Index Integrity** button (Storage pane, both platforms):
  - `PRAGMA quick_check` on `frus.db` via a new `IndexingPipeline` method.
  - FTS5 `integrity-check` on both external-content tables
    (`INSERT INTO t(t, rank) VALUES('integrity-check', 1)` — the rank=1 form
    verifies the index against the content table).
  - Result UI: green "No problems found" or the error text with a suggestion
    to run Delete Index & Rebuild.
- **Rebuild Spotlight Index** button: `CSSearchableIndex.deleteAll` followed
  by re-submission from `document_cache` (batch through the existing
  `submitSpotlightItems` shape; do NOT re-parse XML — read header/body
  prefix from the cache table).

### Testing
- Pipeline unit test: integrity check passes on a freshly indexed fixture;
  returns a failure string on a deliberately corrupted table (drop a trigger,
  modify content, run check).

## Task 6 — Live Activity Opt-Out (iOS)

Indexing Live Activities have no off switch. Add
`"frus.indexing.liveActivityEnabled"` (default on) checked at the
`Activity<IndexingActivityAttributes>.request` call site (find it via
`IndexingActivityAttributes`), plus a toggle in iOS Settings near the
indexing/storage rows. macOS: not applicable.

## What NOT to Do
- No storage limit resurrection (removed deliberately in Session 2026-06-10 (3)).
- No auto-update scheduling/daemonry for Task 3 — manual check + explicit
  update only; background refresh is a separate decision.
- No import implementation in Task 2 — schema versioning only.

## Suggested Order & Sizing
1. Task 1 (cellular policy) — ~0.25 session, ship first.
2. Task 4 (reading prefs) + Task 6 (Live Activity) — ~0.25 session combined.
3. Task 5 (maintenance) — ~0.5 session.
4. Task 3 (update detection) — ~1 session (SHA plumbing + UI).
5. Task 2 (export) — ~1 session.
