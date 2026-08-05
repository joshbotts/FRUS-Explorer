# Session 153 — iOS ↔ macOS Feature Parity

## Goal
Close the functional gaps between the iOS and macOS builds identified in the
2026-06-10 settings and research-features reviews. After this session, every
research-management capability available on one platform has an equivalent
(platform-appropriate) affordance on the other. This is *feature* parity, not
UI uniformity — each item below names the platform-native surface it should
land on.

This document complements `BigPicture-iPadMacParity.md`, which covers iPad
window/inspector architecture and Stage Manager. Nothing here depends on that
work.

## Prerequisites
- Settings cleanup session complete (Session 2026-06-10 (3)) — `SearchDefaults`
  and `SettingsKeys` exist; dead toggles removed.
- Research feature fixes complete (Session 2026-06-10 (2)) — `SummaryBlockView`
  availability gating pattern established (reuse it where noted).

## Gap Inventory (verified 2026-06-10)

| Capability | iOS | macOS |
|---|---|---|
| Project delete / merge | ✗ (create/edit only) | ✓ `SettingsProjectsPane` |
| Local-only reset | ✗ (sync + full only) | ✓ `SettingsResetPane` |
| Citation styles (Chicago/Turabian) | ✗ (history.state.gov only) | ✓ popover-only, unpersisted |
| NARA API usage counter | ✗ | ✓ `SettingsNARAPane` (30-day count) |
| Volume-level connection graph | ✗ | ✓ corpus browser + graph window |

## Task 1 — Project Delete and Merge on iOS

An iPhone-only user can create projects via `ProjectPickerMenu` /
`ProjectEditorView` but can never delete or merge them; stale projects
accumulate forever.

### Requirements
- Extract the delete and merge logic from `SettingsProjectsPane`
  (`FRUSSettingsView.swift`: `projectToDelete`, `projectToMerge`, the
  confirmation dialog, and the reassignment pass) into a shared, testable
  helper — suggested: `ProjectAdminService` (struct with static funcs taking a
  `ModelContext`), since the SwiftData mutations are identical on both
  platforms:
  - `delete(_ project: Project, context:)` — must reassign or orphan-handle
    every record carrying `projectId` (ResearchNote, ReadingHistoryEntry,
    SearchHistoryEntry, GeneratedSummary, ResearchSession) and clear
    `AppState.activeProjectId` if it pointed at the deleted project. Match the
    existing macOS semantics exactly — read that pane first; do not invent new
    semantics.
  - `merge(_ source: Project, into target: Project, context:)` — reassign all
    `projectId` references, then delete `source`.
- iOS surface: a "Projects" group in the Settings Research section
  (`SettingsView.swift`), mirroring the Tags pane pattern (`UserTagsView`):
  list of projects with swipe-to-rename, context-menu Merge Into…, and
  swipe-to-delete with a confirmation that states what happens to the
  project's notes.
- macOS `SettingsProjectsPane` switches to the shared helper (no behaviour
  change).

### Testing
- Unit tests for `ProjectAdminService.delete`/`merge` covering: reassignment
  of each record type, active-project fallback, merge into self rejected.

## Task 2 — Local-Only Reset on iOS

macOS `SettingsResetPane` offers three tiers (local / full / iCloud sync);
iOS `ResetView` offers only sync and full. The local tier ("wipe this device,
keep iCloud data") is the *least* destructive option and the one a user with
a misbehaving device most likely wants.

### Requirements
- Port the macOS "Reset local data" action to iOS `ResetView`
  (`SettingsView.swift`), with the same ordering: least → most destructive
  (Sync, Local, Full).
- Reuse the existing macOS implementation path — identify it in
  `SettingsResetPane` and extract to a shared helper alongside the existing
  reset plumbing rather than duplicating. Verify it covers: SwiftData local
  store, downloaded volume XML, `frus.db`, UserDefaults keys, Keychain
  (NARA key) — and that it deliberately does NOT touch the CloudKit zone.
- Confirmation copy must state explicitly that iCloud data survives and will
  re-sync.

## Task 3 — Persisted Citation Style on Both Platforms

`CitationPopoverStyle` (history.state.gov / Chicago / Turabian) exists only in
the macOS citation popover as per-presentation `@State`, and only affects the
popover's display — Copy/Share Citation and the entire iOS app always use
`HistoryAtStateCitationFormatter`.

### Requirements
- Move the Chicago and Turabian string-building out of
  `SupportingViews.swift` into `Citation/CitationFormatter.swift` as proper
  `CitationFormatter` conformers (the protocol doc already anticipates
  `.chicagoFootnote` etc.). One formatting implementation, used everywhere.
- Add a persisted preference: `SettingsKeys.citationStyle`
  (`"frus.citation.style"`, default `"historyStateDotGov"`), with a picker in
  both Display settings panes (or a small "Citations" group). The persisted
  style drives `DocumentViewModel.formattedCitation`,
  `plainTextFormattedCitation`, `shareableCitationMessage`, the iOS
  `CitationSheetView`, and the macOS popover's initial selection (the popover
  may still switch styles per-presentation for comparison).
- BibTeX/RIS exporters are unaffected (machine formats).

### Testing
- Extend `CitationFormatterTests` with Chicago and Turabian fixtures —
  including the editorial-note/no-document-number case (regression-prone; see
  Session 2026-06-09 fix).

## Task 4 — NARA API Usage Counter on iOS

`SettingsNARAPane` (macOS) shows a 30-day call count; the iOS `NARAKeyView`
does not. Locate the counter's storage (follow `callCount` in
`FRUSSettingsView.swift` to its source) and render the same figure in
`NARAKeyView` with the same "Usage (last 30 days)" framing. Purely additive.

## Task 5 — Volume Connection Graph on iOS

`VolumeConnectionGraphView` (volume-level cross-reference graph) is reachable
only from the macOS corpus browser rows and the macOS graph window. The view
itself is plain SwiftUI — audit for AppKit-isms, then add an iOS entry point:

- `VolumeView` toolbar button (graph icon, matching the macOS corpus browser
  affordance) presenting the view in a sheet, gated on the volume being
  indexed (the graph reads `cross_references`).
- Follow the document-graph sheet's presentation pattern in `DocumentView`
  (`DocumentSheet.crossReferenceGraph`) for sizing and dismissal.

## What NOT to Do
- Do not build an iOS settings clone of the macOS pane layout — use iOS
  navigation conventions (the existing Settings tab patterns).
- Do not migrate the macOS citation popover away from popover presentation;
  parity here is about the *style capability*, not the container.

## Suggested Order & Sizing
1. Task 3 (citation styles) — touches shared code; do first so tests settle. ~0.5 session
2. Task 1 (projects) — shared service + iOS pane. ~0.5–1 session
3. Task 2 (local reset) — small once the macOS path is extracted. ~0.25 session
4. Tasks 4 + 5 — additive UI. ~0.25 session combined
