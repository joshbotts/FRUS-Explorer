// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Network
import Observation
import SwiftData
import SwiftUI   // OpenWindowAction (provenance routing convenience)
import CloudKit
import os              // shared `cloudKitLog` for redacted health-check telemetry (#188-C.1)
#if os(iOS)
// @preconcurrency suppresses region-based sending errors for Activity<T>, whose async
// methods (update/end) are nonisolated and have not yet been annotated for Swift 6.
@preconcurrency import ActivityKit
#endif

/// AppState is the root observable state object for FRUS Explorer.
///
/// It holds application-level state that must be accessible across the entire view hierarchy
/// and persists across launches via `UserDefaults`. Injected into SwiftUI's environment at
/// the `App` level so any view can read it without explicit parameter passing.
///
/// Project context: AppState serves as the bridge between the user's active research focus
/// (`activeProjectId`) and the SwiftData/CloudKit layer that stores all user-generated content.
/// Views observe AppState to react to project switching without requiring data migration —
/// switching projects is a state change, never a data migration.
///
/// ## Network Monitoring
/// AppState owns an `NWPathMonitor` and keeps `isOnline` accurate in real time.
/// `FRUSExplorerApp` observes `isOnline` to enable/suspend the `DownloadManager`.
///
/// ## Download Manager
/// `downloadManager` is set once at app launch by `FRUSExplorerApp`. Views that
/// need to trigger or inspect downloads access it via `@Environment(AppState.self)`.
///
/// ## Tag Stores
/// `volumeLevelTagStore` resolves volume-level tag slugs and provides volume-by-tag
/// index queries, loaded synchronously at init from the app bundle. (The former
/// document-level `subjectTagStore` was retired in Session 09 — see the
/// `volume-subject-profiles-index.json` lazy store for the successor volume-level
/// subject feature.)
///
/// Version history:
///   1.0 — Session 01: initial implementation
///   1.1 — Session 04: SwiftData container injected at App level
///   1.2 — Session 05: NWPathMonitor, downloadManager, downloadQueue wired up
///   1.3 — Session 08: volumeLevelTagStore, subjectTagStore wired up
///   1.4 — Session 10: manifestStore wired up
///   1.5 — Session 19: summarizationService added
///   1.6 — Session 21: backgroundSummarizationService and backgroundSummarizationProgress added
///   1.7 — Session 30: citationMatchingEngine added
///   1.8 — Session 32: added `showSettingsSheet` and `pendingOnboardingAfterReset` for
///          safe post-reset navigation; onboarding flag cleared only after sheet animates out
///   1.9 — Session 40: pendingSearch for cross-view person-mention navigation
///   2.0 — Session 43: AppTab enum; activeTab (iOS); pendingBrowseDocument;
///          showSearch and showCitationLookup promoted from BrowserView local state
///          (showSearch removed in 4.0 — never set to `true` anywhere; the
///          `#if os(macOS)` branch in BrowserView that owned it was dead code)
///   2.1 — Session 44: showSettingsSheet and pendingOnboardingAfterReset guarded to macOS
///   2.2 — Session 45: lastActivityTabVisit and unindexedVolumeCount (iOS)
///   2.3 — Session 46: showSettingsSheet and pendingOnboardingAfterReset removed;
///          Settings is now a Settings scene on macOS (no sheet needed)
///   2.4 — Session 49: pendingDownloadScope added for onboarding → DownloadManager handoff
///   2.5 — Session 50: filterDownloadedOnly (UserDefaults-persisted); showAbout (macOS)
///   2.6 — Session 51: currentIndexingProgress (iOS); connectIndexingProgress(pipeline:)
///   2.7 — Session 61: showAbout removed; About is now a Window scene (F-014)
///   2.8 — New UI scaffolding: currentIndexingProgress and connectIndexingProgress promoted to
///          cross-platform (removed #if os(iOS) guard) for macOS StatusBarView
///   2.9 — Session 100: logEvent(_:) + loggingContext + ResearchSession management
///   3.0 — Session 101: logEvent(_:) gated on researchSessionLoggingEnabled UserDefaults key
///   3.1 — Session 114: completedIndexingMetadata for post-index summary card
///   3.2 — Session 115: interruptedVolumeIds; cleared on .complete from connectIndexingProgress
///   3.3 — Session 116: indexingQueuePosition + indexingQueueVolumeTitles for multi-volume queue banner;
///          indexingQueueAverageDocsPerSecond + indexingQueueAverageDocumentCount for queue ETA
///   3.4 — Session 130: cloudKitSyncEnabled + cloudKitInitError for sync-state diagnostics
///   3.5 — Session 130: CloudKitSyncState enum + cloudKitSyncState for real-time event monitoring
///   3.6 — Session 130: cloudKitDiagnostic() now extracts per-item errors from CKPartialErrorsByItemIDKey
///   3.7 — Session 130: documentTaggingGeneration counter (removed in 3.8 — superseded by
///          @Query allTagAssignments in ResearchView which is reactive natively)
///   3.8 — Session 130: DocumentTagAssignment model; direct tag associations now live in
///          SwiftData and sync via CloudKit
///          so CKError.partialFailure (code 2) surfaces actionable sub-error codes instead of
///          the useless "Some items failed." localizedDescription
///   3.9 — Session 2026-06-07: pendingAnalytics (AnalyticsParameters) for two-way
///          Search ↔ Corpus Analytics handoff
///   4.0 — Session 2026-06-07: removed orphaned `showSearch` — it was only ever
///          set from a dead `#if os(macOS)` branch in `BrowserView` (unreachable
///          since the file became iOS-only in Session 60) and never read or set
///          to `true` anywhere; `showCitationLookup` remains in active use
///   4.1 — Word Cloud fixes: connectIndexingProgress flushes the word-cloud
///          result cache on each volume's `.complete` event (its in-memory key
///          carries no index fingerprint, so stale pre-index results otherwise
///          persist for the whole session)
///   4.1 — Corpus Analytics cache fix: connectIndexingProgress flushes
///          `CorpusAnalyticsService`'s result caches on each volume's `.complete`
///          event (cache keys are bare query terms with no index fingerprint, so
///          stale pre-index counts otherwise persist for the whole session)
///   4.1 — Session 2026-07-02: pendingCollectionSelection (UUID) for the open-with
///          `.fruscollection` import → Collections window hand-off on macOS
///   4.2 — Authoring Phase 3 review: connectIndexingProgress notifies
///          `citationMatchingEngine.noteVolumeDownloaded(_:)` on each volume's
///          `.complete` event so citation resolution sees newly downloaded volumes
///          without an app relaunch
///   4.3 — Session 2026-07-04 (macOS UI audit B2/B3/B4): pendingBrowseVolume
///          (cross-volume provenance rows → browser hand-off) and pendingNARALookup
///          (selected text → Source Explorer window's NARA Lookup mode) added;
///          showCitationLookup removed — Citation Lookup is a Window scene on macOS
///          (`frus.citationLookup`) and local sheet state on iOS, so the cross-view
///          flag had no remaining reader
///   4.4 — Session 2026-07-04 (macOS UI audit B6): pendingVolumeGraph added — the
///          Corpus Browser's per-volume graph buttons hand the volume to the
///          frus.crossReferenceGraph window's volume-connections stage instead of
///          presenting VolumeConnectionGraphView in a local sheet
///   4.5 — Session 2026-07-04 (macOS UI audit C1): pendingNoteComposer added — the
///          macOS research-note editor is the frus.noteComposer utility window
///          (document stays readable while composing) instead of a modal sheet
///   4.6 — Session 09: retired the document-level subjectTagStore (and its 9 MB
///         synchronous bundle parse at init); the volume-level successor loads
///         lazily via `VolumeSubjectProfilesStore`, not on AppState.
///   4.7 — Wave R-1: `researchLoggingPreferenceKey` + `isResearchLoggingEnabled(in:)`
///         become the single reader of the research-logging preference. `logEvent`'s
///         inline `UserDefaults` read is gone, and the two previously ungated writers
///         (`DocumentViewModel.recordReadingHistory`, `MacSearchViewModel
///         .recordSearchHistory`) now honour the same switch. `logEvent` gained a
///         `defaults:` parameter so the gate is testable without global state.
///   4.8 — R-5 P3: `revisionReviewToken`, the review-write signal the P2 readers reload on.
///   4.8 — Wave R-2a: `logEvent(_:defaults:)`, `loggingContext`, `currentResearchSession`,
///         `lastEventDate` and `sessionExpiryInterval` removed. `AppState` no longer writes
///         the research trail at all — the three typed writers do, sessions are derived by
///         `ResearchTrailSessions`, and the idle interval moved to `ResearchTrailSessions
///         .idleInterval`. `isResearchLoggingEnabled(in:)` stays: it is still the one gate.
///   4.9 — Wave R-6: `checkCloudKitHealth()`'s two `catch` blocks run the error through
///         `CloudKitErrorInspector`, so an account or zone failure records the retry-after hint
///         and the "looked for per-item detail" fact instead of a bare domain and code.
///   4.10 — R-5 P3b-7: `summarizeAgainFailure` and its `SummarizeAgainFailure` payload — a
///          Summarize Again that failed after its sheet was dismissed, addressed to one document
///   4.11 — #1299: `pendingSearchTips` and `openSearchTips(from:)` — the Find menu's Search Tips request, a
///          one-shot hand-off addressed as `openSearch(_:from:)` addresses a query (the iPadOS Search tab's sheet,
///          the macOS Search window's panel)
///   4.12 — `checkCloudKitHealth()` skips the private-zone check when the account is not `.available`
///          (`zoneCheckApplies(afterAccountStatus:)`), leaving `cloudKitZoneVerified` `nil`: a signed-out
///          device read as "zone missing". The four iCloud facts are shown through `iCloudStatusSummary`
///   4.13 — `checkCloudKitHealth()` no longer writes an unavailable account into `cloudKitSyncState` (it
///          titled the iOS banner "iCloud Sync Failed" and went stale after sign-in), and a FAILED zone
///          listing records `nil` rather than `false` (`zoneVerification(listedZoneNames:)`)
///   4.14 — #1368: closing an iPad aux window brings a main window forward. `AuxWindowClosing`,
///          `AuxWindowCloseAction` and the `AuxWindowClose` wrapper every such Done reads;
///          `mainWindowSessions` + `registerSceneSession(_:for:)`; `AuxWindowDestination`'s rule; and
///          `front(_:)`, the app's one scene-activation call. `AuxWindowOriginModifier` publishes the
///          close payload and gains a close-only form for the six analytics windows. Review round 1:
///          an aux window launched from another aux window goes back to it on Done
///          (`auxWindowSessions`, `pendingAuxWindowLauncherRaw`, `recordAuxWindowLaunch(from:)`,
///          `SceneID.borrowingWindow`, `AuxWindowDestination.launchingAuxWindow`), and a hand-off
///          close with no target is still a hand-off
///   4.15 — #1356 review: `downloadedVolumes`, Volumes & Storage's measurement and the removal in
///          progress, held here so a hub the reader leaves and re-enters mid-removal reads the same
///          mark and receives the re-measure
///   4.16 — #1462: `pendingArchiveVisitSelection` (macOS), the plan the Archives Visits window is asked
///          to show; set through `openArchiveVisitWindow(on:using:)`, declared beside the window
///   4.17 — #1522: the citation engine is built over the volumes directory, which it reads at each
///          lookup, so `connectIndexingProgress` no longer tells it that a volume finished indexing
///   4.18 — Lane STOR (#1526): `indexAllVolumes(with:)` and `rebuildSearchIndex(pipeline:)` re-read
///          the indexed-volume set after a whole-index pass (`reseedIndexedVolumeIds`), every write to
///          it goes through `markVolumeIndexed` / `markVolumeUnindexed` / `clearIndexedVolumeIds`,
///          which journal while a re-read is in flight, and `reconcileSideloadedVolumes()` reads the
///          side-loaded volumes' sidecars, which boot now calls
///   4.19 — #1531: `unrecoveredExport`, an upload failure remembered across launches, which the
///          status summary resolves to `.stopped` and Fix iCloud Sync warns about
///   4.20 — #1660: `keepingCurrent`, Keeping Current's list and where each volume's update stands
///   4.21 — #1695: one Live Activity follows a whole indexing queue and ends with it, through
///          `LiveActivityHosting`; a pass that throws (`IndexingStage.failed`) clears the progress the
///          banner shows, and its queue no longer waits for that volume (`IndexingBatch.failedVolumeIds`)
///   4.22 — 2026-10-20: `connectIndexingProgress` is documented as the progress stream's one reader,
///          to be called once for a pipeline (it had been called safe to call again), and
///          `currentIndexingProgress` as the source Browse's Index Now reads. Comment only
///   4.23 — #1757: the indexing queue counts every volume it holds, its downloads included
///          (`downloadQueue`'s `didSet`, `indexingQueueTransferDidFinish(_:outcome:)`,
///          `IndexingBatch.count(_:)`), and its Live Activity shows a new count at once
///          (`refreshIndexingLiveActivityQueue()`); the FRUS Research Guide's first-queue sheet is
///          claimed by one window (`claimIndexingGuide(for:keyboardIsVisible:)`) and counts as shown
///          only once it is on screen (`indexingGuideDidAppear()`)
///   4.24 — #1766: `followedPageLink`, the page a page link was to when it opened its volume's page
///          in Browse, which `openBrowseVolume(_:from:)` clears

// MARK: - CloudKitSyncState

/// Live status of the CloudKit sync channel, updated from
/// `NSPersistentCloudKitContainer.eventChangedNotification` events.
///
/// Version history:
///   1.0 — Session 130: initial implementation
enum CloudKitSyncState: Sendable {
    /// No sync event has been received yet since app launch.
    case unknown
    /// An import or export operation is currently in flight.
    case syncing
    /// The most recent sync event completed successfully.
    case succeeded(Date)
    /// The most recent sync event failed; `message` is `NSError.localizedDescription`.
    case failed(String)
}

// MARK: - AppTab

/// The five top-level tabs available on iOS.
///
/// `rawValue` is persisted to `UserDefaults` so the active tab survives app relaunch.
/// The `.research` rawValue differs from the former `.activity` rawValue ("activity"),
/// so devices upgrading from Activity will fall back to `.browse` on first launch —
/// an acceptable one-time reset.
#if os(iOS)
enum AppTab: String, CaseIterable, Sendable {
    case browse      = "browse"
    case search      = "search"
    case research    = "research"
    case collections = "collections"
    case settings    = "settings"
}
#endif

// MARK: - NARALookupRequest

/// A cross-window NARA-lookup hand-off (`AppState.pendingNARALookup`): the user-selected
/// `text` plus, for a footnote selection, the enclosing note body (`blockContext`) whose
/// archival citations the lookup surfaces as quick-fills (#269). `Equatable` so the Source
/// Explorer window's `.onChange` hand-off consumer fires on each new request. Defined here
/// (not in the macOS-only `MainWindowView`) because it types a cross-platform `AppState`
/// property, so it must compile on iOS too.
struct NARALookupRequest: Equatable {
    /// The user-selected text (pre-populates the lookup query field).
    let text: String
    /// The enclosing footnote body for a footnote selection, else `nil`.
    var blockContext: String? = nil
}

@Observable
@MainActor
final class AppState {

    // MARK: - Active Project

    /// The ID of the currently active research project, or `nil` for global context.
    ///
    /// Persisted across launches via `UserDefaults`. Changing this property is instantaneous —
    /// it does not trigger data migration. All content is global; the active project is a lens
    /// that filters what the user sees.
    var activeProjectId: UUID? {
        didSet {
            UserDefaults.standard.set(activeProjectId?.uuidString, forKey: Keys.activeProjectId)
            #if DEBUG
            print("[FRUSExplorer] Active project changed to: \(activeProjectId?.uuidString ?? "nil (global context)")")
            #endif
        }
    }

    // MARK: - Onboarding

    /// `true` once the user has tapped "Get Started" on the final onboarding screen.
    ///
    /// Persisted via `UserDefaults` so subsequent launches skip onboarding even before
    /// the first volume finishes downloading. `ContentView` routes to `BrowserView`
    /// when this is `true` or when at least one volume is already on disk.
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding) {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    /// `true` when the user finished onboarding **with nothing to download** — and is therefore
    /// entitled to use the app in that state instead of being sent back to the wizard.
    ///
    /// ## The trap this exists to close
    /// `ContentView` leaves onboarding only when the flag above is set AND a volume is on disk
    /// or queued. That AND is deliberate and still right for the case it was written for: a user
    /// who deleted every volume should be re-onboarded rather than dropped into an empty app.
    /// But the wizard also offers **Skip** on the download step, and Skip enqueues nothing — so
    /// Skip → Finish wrote `hasCompletedOnboarding`, created the default project, and returned
    /// the reader to the Welcome page **with no way past it, ever**. Measured on an iPad
    /// simulator: both values are written, so the button works and the routing sends them back.
    ///
    /// ## Why this is keyed on the outcome, not on the Skip button
    /// Skip is the obvious way to reach that state but not the only one. Choosing a scope and
    /// tapping Continue while the enqueue yields nothing — offline, or a scope that resolves to
    /// no volumes — lands in exactly the same place. So this is set whenever onboarding
    /// completes and there is nothing on disk and nothing queued, which is the condition that
    /// actually traps someone rather than the gesture that usually causes it.
    ///
    /// ## Why the app is worth entering empty
    /// A great deal of FRUS Explorer needs no downloads at all: the bundled volume manifest the
    /// Browse tab lists (and downloads from), the word-cloud vectors, the semantic map's 314,616
    /// placements, and every archival-analytics index. Declining the 3.5 GB is a reasonable
    /// first-run choice, and it should not cost the reader the app.
    ///
    /// Cleared wherever onboarding is re-triggered (Settings reset, data recovery), so a reset
    /// user's next pass through the wizard is judged on its own outcome.
    var hasFinishedOnboardingWithoutVolumes: Bool =
        UserDefaults.standard.bool(forKey: Keys.hasFinishedOnboardingWithoutVolumes) {
        didSet {
            UserDefaults.standard.set(hasFinishedOnboardingWithoutVolumes,
                                      forKey: Keys.hasFinishedOnboardingWithoutVolumes)
        }
    }

    // MARK: - Browser Filter

    /// When `true`, the Browser volume list shows only volumes that have been downloaded.
    ///
    /// Persisted across launches via `UserDefaults` so the user's preference survives
    /// app restarts. `BrowserView.onChange` syncs this value into `BrowserViewModel`
    /// whenever it changes.
    var filterDownloadedOnly: Bool = UserDefaults.standard.bool(
        forKey: Keys.filterDownloadedOnly
    ) {
        didSet {
            UserDefaults.standard.set(filterDownloadedOnly, forKey: Keys.filterDownloadedOnly)
        }
    }

    /// The custom volume scope the Browse hierarchy is narrowed to, or `nil` for the
    /// whole corpus (#1051 B-3, owner decision Q-3).
    ///
    /// A LIVE REFERENCE, deliberately: the id is stored and the scope's membership is
    /// re-resolved at render, so edits reflect immediately and a scope deleted on another
    /// device becomes an explicit unavailable state (`ScopeAxis.filterState`) — never a
    /// silent whole-corpus fallback (#258). Device-local UserDefaults, following
    /// `filterDownloadedOnly`: a browse filter is this device's concern, and a stored
    /// property on a synced `@Model` would trip the CloudKit schema-deploy gate.
    var browseScopeFilterId: UUID? = UserDefaults.standard.string(
        forKey: Keys.browseScopeFilterId
    ).flatMap(UUID.init(uuidString:)) {
        didSet {
            UserDefaults.standard.set(browseScopeFilterId?.uuidString,
                                      forKey: Keys.browseScopeFilterId)
        }
    }

    // MARK: - Pending Download Scope

    /// Set by onboarding or `DownloadManagerSettingsView` when the user confirms a
    /// download scope. `FRUSExplorerApp.bootDownloadManager` (or a `.onChange` watcher
    /// on `ContentView`) enqueues the scope with `DownloadManager` and clears this
    /// property immediately after enqueueing.
    var pendingDownloadScope: DownloadScope? = nil

    // MARK: - iCloud Sync State

    /// Whether the app's SwiftData container was successfully initialised with CloudKit sync.
    ///
    /// Starts `true` (optimistic) and is corrected to the real value by
    /// `FRUSExplorerApp.bootApp()` immediately after the first `.task` fires.
    /// When `false` the app is running against a local-only SQLite store — no data
    /// changes will sync across devices until the underlying problem is resolved
    /// (sign in to iCloud, CloudKit schema migration, entitlement configuration, etc.).
    ///
    /// Observed by `StatusBarView` (macOS) and the Settings → Storage panel to surface
    /// a "Local Only" warning with actionable guidance.
    var cloudKitSyncEnabled: Bool = true

    /// Human-readable diagnostic for the error that prevented CloudKit initialisation,
    /// formatted by `FRUSExplorerApp.cloudKitDiagnostic(_:)` from the actual `NSError`
    /// `ModelContainer.makeFRUSContainer()` caught — e.g. `"CKErrorDomain
    /// serverRejectedRequest: …"` — so the CloudKit error *domain and code name* are
    /// always visible in the running app, not just in a console only developers can see.
    ///
    /// `nil` when CloudKit initialised successfully. Set alongside `cloudKitSyncEnabled = false`
    /// by `FRUSExplorerApp.bootApp()`. Displayed in the Settings → iCloud "Local Only" row
    /// and in `StatusBarView`'s "Local Only" tooltip so users — and testers reporting sync
    /// problems — can self-diagnose the failure (e.g. recognising `serverRejectedRequest` /
    /// `incompatibleVersion` as "an undeployed CloudKit schema change" per the migration
    /// note on `ModelContainer.frusModelTypes`) without attaching a console.
    var cloudKitInitError: String? = nil

    /// The record-type difference between the store on disk and this build, when the container
    /// fell back to local-only and there was a store to inspect.
    ///
    /// `nil` on a healthy launch, and also `nil` when the fallback had no store to compare against
    /// (a first launch) — those are different facts from "the lists agree", which is a non-`nil`
    /// value with `isMismatch == false` and rules out a stale store as the cause.
    ///
    /// Set by `FRUSExplorerApp.bootApp()`. Read by the debug launch alert, which exists because a
    /// silent fallback ran for 31 launches over four days behind nothing but a small orange chip.
    var storeSchemaMismatch: StoreSchemaDiagnostic? = nil

    /// Real-time CloudKit sync state, updated by observing
    /// `NSPersistentCloudKitContainer.eventChangedNotification`.
    ///
    /// `.unknown` at startup; transitions to `.syncing` when an import or export begins,
    /// `.succeeded` when it completes cleanly, or `.failed` when it errors. A `.failed`
    /// state surfaces the error message in the macOS status bar and iOS Settings so
    /// developers and users can see exactly what is preventing data from syncing.
    var cloudKitSyncState: CloudKitSyncState = .unknown

    /// An upload that failed with no upload succeeding since, remembered across launches (#1531).
    ///
    /// The mirror of ``SyncExportFailureMemory``'s stored run, which ``SyncEventMonitor`` writes
    /// from the moment the container starts — before this object exists. `FRUSExplorerApp` reads
    /// it in when it attaches to the monitor, and the monitor hands it over again whenever the run
    /// changes: after each ended export, which starts, extends or ends it, and when a system-log
    /// read adds names to it. Imports, setups and started events leave it as it was. A container
    /// that fell back to local-only reads it once instead. `nil` until then, and on every test
    /// `AppState`, which never reads the device's memory.
    ///
    /// Views read it through `iCloudStatusSummary` — a run begun in an earlier launch resolves to
    /// `.stopped` — except Data & Recovery, whose Fix iCloud Sync warning reads it directly, since a
    /// run begun in THIS launch puts the same unsent changes at risk.
    var unrecoveredExport: UnrecoveredExport? = nil

    /// True once the first CloudKit **import** has finished this launch, so the local `Project`
    /// store is stable. Until then the macOS "Switch Project" menu shows a "Syncing…" placeholder
    /// instead of a list that would churn/reshuffle as records arrive one batch at a time — a native
    /// menu handles live content mutation poorly, which made the menu hard to use during the initial
    /// sync of a fresh launch. Session-only (not persisted): a relaunch re-shows the placeholder only
    /// while its own import runs, and an already-synced launch (no import work) never shows it because
    /// the sync state never reaches `.syncing`. (#377 Phase 5)
    var hasInitialProjectSyncSettled = false

    /// Whether the bundled word-cloud vectors have finished decoding.
    ///
    /// An OBSERVABLE mirror of `BundledCloudVectors.isCoreReady`, which is static state on a plain
    /// `@MainActor enum` and therefore invisible to Observation. Every cloud surface's appearance
    /// depends on that flag turning true after the first frame, and nothing re-evaluated a `body`
    /// when it did — so a surface acquired its cloud only when some unrelated change happened to
    /// re-render its host. `CloudSurfaceArbiter.resolve(appState:)` and `PendingCloudBackdrop` read
    /// this; the store stays the single source of the DATA and this is the single source of the
    /// EVENT. Set once, in the root scene's `.task`, immediately after `prepareCore()` returns.
    var areCloudVectorsReady = false

    /// Debounce handle for the settings pull that follows a successful CloudKit event (#665).
    ///
    /// Rescheduled on every success, so the pull runs once a couple of seconds after sync goes
    /// quiet rather than on every batch. Undebounced it re-ran a fetch, a possible save, and a
    /// UserDefaults write — which fans out to every `@AppStorage`-bound view — for each event of
    /// a large import. `@ObservationIgnored` because it is transient plumbing, not observable UI
    /// state, matching ``orphanedTagRepairDebounce``.
    @ObservationIgnored
    var settingsPullDebounce: Task<Void, Never>? = nil

    /// Debounce handle for the boot-time orphaned-tag repair (#406).
    ///
    /// `FRUSExplorerApp.bootApp()`'s CloudKit event observer reschedules this on every successful
    /// import so `OrphanedTagRepair` runs once, a few seconds after imports go quiet — i.e. only
    /// against a *settled* store, never mid-import where a not-yet-arrived tag would look like an
    /// orphan. `@ObservationIgnored` because it is transient plumbing, not observable UI state.
    @ObservationIgnored
    var orphanedTagRepairDebounce: Task<Void, Never>? = nil

    /// Whether the iCloud private zone required for CloudKit sync exists on the server.
    ///
    /// `nil` = not yet verified, or unknowable — the account is not `.available` (a private
    /// database cannot be listed without one) or the listing itself failed; `true` = zone found
    /// and sync should work;
    /// `false` = zone missing — records cannot be uploaded or downloaded until
    /// NSPersistentCloudKitContainer recreates it (typically on next cold launch).
    ///
    /// Views read it through `iCloudStatusSummary`, never directly.
    ///
    /// Set by `checkCloudKitHealth()`, called at launch and on every foreground transition.
    var cloudKitZoneVerified: Bool? = nil

    /// The current iCloud account status.
    ///
    /// `nil` = not yet checked. `.available` = signed in and sync enabled.
    /// Any other value means data will not sync (not signed in, restricted, etc.).
    var cloudKitAccountStatus: CKAccountStatus? = nil

    // MARK: - CloudKit health check

    private static let ckContainerIdentifier = "iCloud.bottsywattsy.FRUS-Explorer"
    /// The zone name created by NSPersistentCloudKitContainer for the private database.
    private static let ckZoneName = "com.apple.coredata.cloudkit.zone"

    /// Checks iCloud account status and private zone existence, then updates
    /// `cloudKitAccountStatus` and `cloudKitZoneVerified`.
    ///
    /// It does NOT touch `cloudKitSyncState`, which is the sync-EVENT channel. It used to write an
    /// unavailable account's description there as `.failed`, so the account problem reached the
    /// iOS banner titled "iCloud Sync Failed" and outlived the problem: once the user signed in,
    /// the stale text stayed until the next sync event, and Settings showed "Sync Error — Not
    /// signed in" to a signed-in user. Every surface now reads the account through
    /// `iCloudStatusSummary`, so the write carried nothing the surfaces lacked. The zone is checked
    /// only when `zoneCheckApplies(afterAccountStatus:)` says the account can answer, and its result
    /// is read through `zoneVerification(listedZoneNames:)`.
    ///
    /// Safe to call repeatedly — idempotent apart from logging. Call at launch
    /// (from `FRUSExplorerApp.bootApp()`) and on every foreground transition so
    /// the status bar/settings reflect fresh state after the user signs in or out.
    ///
    /// - Note: No-op when `cloudKitSyncEnabled == false` (container fell back to local).
    @MainActor
    func checkCloudKitHealth() {
        guard cloudKitSyncEnabled else { return }
        Task { @MainActor in
            let container = CKContainer(identifier: Self.ckContainerIdentifier)

            // ── Account status ──────────────────────────────────────────────────
            // Telemetry rows carry only the phase, domain/code, and status raw value — never a
            // `localizedDescription` (which can embed identifiers) or account identity (#188-C.1).
            do {
                let status = try await container.accountStatus()
                cloudKitAccountStatus = status
                if status != .available {
                    cloudKitLog.notice("account status not available: \(status.rawValue, privacy: .public)")
                    Task { await SyncDiagnosticsLog.shared.record(
                        phase: "account", startDate: nil, endDate: Date.now, succeeded: false,
                        errorCodeName: "accountStatus(\(status.rawValue))") }
                }
            } catch {
                let ns = error as NSError
                cloudKitLog.error("account status check failed: \(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)")
                // Wave R-6: the health checks used to record a bare domain + code, so a rate-limit
                // rejection looked the same as an outage. The inspection adds the retry-after hint
                // and the "we looked for per-item detail" fact, all allow-listed scalars.
                let inspection = CloudKitErrorInspector.inspect(ns)
                Task { await SyncDiagnosticsLog.shared.record(
                    phase: "account", startDate: nil, endDate: Date.now, succeeded: false,
                    errorDomain: ns.domain, errorCode: ns.code,
                    hadPartialDictionary: inspection.hadPartialDictionary,
                    partialDictionaryDepth: inspection.partialDictionaryDepth,
                    schemaIdentifiers: inspection.schemaIdentifiers.isEmpty
                        ? nil : inspection.schemaIdentifiers,
                    retryAfterSeconds: inspection.retryAfterSeconds,
                    chainTruncated: inspection.chainTruncated) }
            }

            // ── Private zone verification ────────────────────────────────────────
            // Only when the account can answer it. A signed-out device has no private database to
            // list, so the listing throws and the catch below used to record the zone as MISSING —
            // a second, red status row (and a failed "zone" telemetry row) for what was only ever
            // the account. Unknowable is `nil`, not `false`.
            guard Self.zoneCheckApplies(afterAccountStatus: cloudKitAccountStatus) else {
                cloudKitZoneVerified = nil
                return
            }
            do {
                let zones = try await container.privateCloudDatabase.allRecordZones()
                cloudKitZoneVerified = Self.zoneVerification(
                    listedZoneNames: zones.map { $0.zoneID.zoneName })
                if cloudKitZoneVerified == false {
                    cloudKitLog.notice("private zone not found — records will not sync until recreated")
                    Task { await SyncDiagnosticsLog.shared.record(
                        phase: "zone", startDate: nil, endDate: Date.now, succeeded: false) }
                } else {
                    Task { await SyncDiagnosticsLog.shared.record(
                        phase: "zone", startDate: nil, endDate: Date.now, succeeded: true) }
                }
            } catch {
                // A listing that FAILED says nothing about the zone. This used to record `false`,
                // so a transient network error at launch read as a deleted zone — a red status row
                // on both platforms, and, now that the workspace banner announces a missing zone,
                // a red banner too. The failure still reaches Sync Diagnostics just below.
                cloudKitZoneVerified = Self.zoneVerification(listedZoneNames: nil)
                let ns = error as NSError
                cloudKitLog.error("zone verification failed: \(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)")
                let inspection = CloudKitErrorInspector.inspect(ns)   // Wave R-6; see above.
                Task { await SyncDiagnosticsLog.shared.record(
                    phase: "zone", startDate: nil, endDate: Date.now, succeeded: false,
                    errorDomain: ns.domain, errorCode: ns.code,
                    hadPartialDictionary: inspection.hadPartialDictionary,
                    partialDictionaryDepth: inspection.partialDictionaryDepth,
                    schemaIdentifiers: inspection.schemaIdentifiers.isEmpty
                        ? nil : inspection.schemaIdentifiers,
                    retryAfterSeconds: inspection.retryAfterSeconds,
                    chainTruncated: inspection.chainTruncated) }
            }
        }
    }

    /// Whether the private-zone check can say anything, given the account status just read.
    ///
    /// `false` for every status but `.available`: without a usable account the private database
    /// cannot be listed, and a failed listing is not evidence that the zone is missing. `nil` —
    /// the account check itself threw — still runs the zone check, as it always has, because an
    /// unknown account is not evidence either way. Internal so `ICloudStatusSummaryTests` can pin
    /// it; `checkCloudKitHealth()` is its only caller.
    static func zoneCheckApplies(afterAccountStatus status: CKAccountStatus?) -> Bool {
        guard let status else { return true }
        return status == .available
    }

    /// What a private-zone listing establishes about the sync zone.
    ///
    /// `nil` when the listing failed (`listedZoneNames == nil`): a failed listing is not evidence
    /// of absence, and a missing zone is only ever a listing that SUCCEEDED without it. Otherwise
    /// whether the listing names `com.apple.coredata.cloudkit.zone`. Internal so
    /// `ICloudStatusSummaryTests` can pin it; `checkCloudKitHealth()` calls it on both paths.
    static func zoneVerification(listedZoneNames: [String]?) -> Bool? {
        guard let listedZoneNames else { return nil }
        return listedZoneNames.contains(ckZoneName)
    }

    /// Human-readable description of a `CKAccountStatus` value for display and logging.
    static func accountStatusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .noAccount:
            return String(localized: "cloudkit.account.noAccount",
                          defaultValue: "Not signed in to iCloud — notes, highlights, and collections won’t sync. Sign in via Settings → Apple ID.")
        case .restricted:
            return String(localized: "cloudkit.account.restricted",
                          defaultValue: "iCloud access is restricted on this device (parental controls or MDM policy).")
        case .couldNotDetermine:
            return String(localized: "cloudkit.account.couldNotDetermine",
                          defaultValue: "Could not determine iCloud account status. Check your network connection and try again.")
        case .temporarilyUnavailable:
            return String(localized: "cloudkit.account.temporarilyUnavailable",
                          defaultValue: "iCloud is temporarily unavailable. Data will sync when it comes back online.")
        @unknown default:
            return String(localized: "cloudkit.account.unknown",
                          defaultValue: "iCloud account status unknown.")
        }
    }

    // MARK: - Network State

    /// Whether the device currently has network connectivity.
    ///
    /// Kept accurate in real time by the private `NWPathMonitor`. Views can observe
    /// this property directly without importing Network.framework.
    var isOnline: Bool = true

    // MARK: - Download Manager

    /// The shared download manager. Set once at app launch by `FRUSExplorerApp`.
    /// `nil` only during the brief window between app init and the first `.task {}` fire.
    /// Views that need to trigger downloads should guard against `nil` gracefully.
    var downloadManager: DownloadManager?

    // MARK: - Semantic Vectors

    /// The Tier-2 semantic shard store, once the bundled index has loaded.
    ///
    /// `nil` until `BundledSemanticVectors.prepare()` succeeds, and permanently `nil` on a build
    /// whose bundled artifacts are missing or provenance-mismatched — the store cannot exist without
    /// the pin it validates shards against. Callers treat `nil` as *semantic scoring unavailable*,
    /// never as *no similar documents*.
    var semanticShardStore: SemanticShardStore?

    /// Fetches Tier-2 shards from the app-owned vectors repository. `nil` under the same conditions
    /// as `semanticShardStore`, plus a bundled shard manifest that disagrees with the bundled index.
    var semanticShardFetcher: SemanticShardFetcher?

    /// Whether a shard may be fetched without the reader asking (`SettingsKeys.autoDownloadSemanticShards`).
    ///
    /// Defaults to **true**, which is what the app has always done. Flipping the default would
    /// quietly stop filling libraries that are being filled today, and a setting whose introduction
    /// changes behaviour for people who never touched it is a worse trade than one extra request per
    /// volume — the bytes are already being spent, and this makes them declinable rather than
    /// retroactively withheld.
    /// `nonisolated` because it reads `UserDefaults` and nothing else — the same shape
    /// `DownloadManager.processQueue()` uses for its cellular twin. Isolating a policy read to the
    /// main actor would force every background caller to hop for a Bool.
    nonisolated static var automaticSemanticShardDownloads: Bool {
        (UserDefaults.standard.object(forKey: SettingsKeys.autoDownloadSemanticShards) as? Bool)
            ?? true
    }

    /// Progress of a manual shard download, or `nil` when none is running.
    ///
    /// **A count, not a byte figure**, and the distinction is the same one #925 made: a shard is
    /// one `URLSession.download(from:)` with no progress callback, so bytes-within-a-file are not
    /// observable. Across *many* files the completed count is, and it is what a reader actually
    /// wants from a bulk action.
    var semanticShardDownload: SemanticShardDownloadProgress?

    /// A manual bulk shard download in flight.
    struct SemanticShardDownloadProgress: Equatable, Sendable {
        /// Shards finished, successfully or not.
        var completed: Int
        /// Shards this run set out to fetch.
        var total: Int
        /// Shards that failed; their diagnoses are in the fetcher and reach the screen through
        /// `semanticStorageReport()` like any other failure.
        var failed: Int
        /// Set when the reader asks to stop; the loop checks it between shards.
        var isCancelled: Bool = false

        /// Fraction done, for a determinate progress view.
        var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    }

    /// Volume ids whose shard could be fetched right now: published, absent from disk, and
    /// belonging to a volume this device actually has.
    ///
    /// **Restricted to downloaded volumes on purpose.** A shard for a volume the reader does not
    /// hold would still score in the funnel — the vectors are independent of the XML — but the
    /// neighbour it produced could not be opened, so fetching it spends bytes on a result the app
    /// would have to withhold.
    /// Which volumes a shard sweep should consider.
    ///
    /// The default is the whole of #926's refusal expressed as a type: a count over volumes the
    /// reader does not have would tell a twelve-volume library it was missing 544, which is a
    /// number about the corpus rather than about them. `entireCorpus` exists only for the explicit
    /// button that names its own cost before it runs (W-19 row L-6) — never for an automatic path,
    /// and never for the count the section shows by default.
    enum SemanticShardScope: Sendable {
        /// Volumes already downloaded — the shipped behaviour, and every automatic path.
        case downloadedVolumesOnly
        /// Every volume the manifest knows, whether or not its text is on this device.
        case entireCorpus
    }

    func semanticShardsAwaitingDownload(
        scope: SemanticShardScope = .downloadedVolumesOnly
    ) async -> [String] {
        guard let store = semanticShardStore, let fetcher = semanticShardFetcher,
              let downloads = downloadManager else { return [] }
        let onDisk = Set(await store.volumeIDsOnDisk())
        let known = manifestStore.diffResult?.known ?? manifestStore.bundledEntries
        var awaiting: [String] = []
        for entry in known where scope == .entireCorpus
                                 || downloads.isVolumeDownloaded(entry.volumeId) {
            // R-1a: a REFUSED shard is on disk and unusable, so `onDisk` alone hides it from
            // every repair route. `SemanticShardStore.refuse` records a shard whose header failed
            // its provenance, count or length check — exactly what a corrected volume produces —
            // and `volumeIDsOnDisk()` does not filter those out. Before this, neither "Download
            // Missing Vectors" nor the whole-corpus button could replace one, while `diskUsage()`
            // went on counting its bytes as present; it was repaired only by accident, when a
            // reader happened onto a surface for an axis that shipped at weight zero (0.5 since
            // 2026-09-10; the sentence is kept in the past tense because it describes why the
            // guard was written, and the guard is still right for a reader who zeroes the axis).
            let refused = await store.refusal(for: entry.volumeId) != nil
            guard refused || !onDisk.contains(entry.volumeId) else { continue }
            guard await fetcher.hasShard(for: entry.volumeId) else { continue }
            awaiting.append(entry.volumeId)
        }
        return awaiting.sorted()
    }

    /// Fetches every shard the device is missing for the volumes it holds.
    ///
    /// Serial, deliberately: 553 shards at ~294 KB are many small requests rather than a few large
    /// ones, and the app's own volume downloads are already queued through `DownloadManager` with a
    /// concurrency limit the reader controls. Racing an unbounded fan-out against that would
    /// contend with the downloads this feature exists to accompany.
    ///
    /// Ignores ``automaticSemanticShardDownloads`` — see its note.
    func downloadAllSemanticShards(scope: SemanticShardScope = .downloadedVolumesOnly) async {
        guard let store = semanticShardStore, let fetcher = semanticShardFetcher else { return }
        // A remembered failure blocks a re-request for the session, which is right for the lazy
        // path and wrong for someone who just pressed a button.
        await fetcher.clearFailures()

        let awaiting = await semanticShardsAwaitingDownload(scope: scope)
        guard !awaiting.isEmpty else { return }
        semanticShardDownload = SemanticShardDownloadProgress(
            completed: 0, total: awaiting.count, failed: 0)

        for volumeID in awaiting {
            if semanticShardDownload?.isCancelled == true { break }
            do {
                try await fetcher.fetchShard(for: volumeID, into: store)
            } catch {
                semanticShardDownload?.failed += 1
            }
            semanticShardDownload?.completed += 1
        }
        semanticShardDownload = nil
    }

    /// Asks a running manual download to stop after the shard in flight.
    func cancelSemanticShardDownload() {
        semanticShardDownload?.isCancelled = true
    }

    /// What the storage screens show about semantic vectors (#900).
    ///
    /// Assembled here rather than in either hub because the two are hand-maintained twins: a figure
    /// computed in one and re-derived in the other is a figure that will eventually disagree.
    ///
    /// Returns ``SemanticStorageReport/unavailable`` when the semantic stack has not booted — the
    /// store and fetcher are `nil` together, and on a build with missing or provenance-mismatched
    /// bundled artifacts they stay `nil`. The screens distinguish that from "nothing downloaded",
    /// because they are different facts about the app.
    func semanticStorageReport() async -> SemanticStorageReport {
        // **The two guards are separate, and collapsing them hides bytes the reader owns.** The
        // fetcher is `nil` under a strictly WIDER condition than the store: the store exists
        // whenever the bundled index loads, while the fetcher additionally requires a shard
        // manifest of the same generation (`FRUSExplorerApp`, where the mismatch branch is a
        // `#if DEBUG print` — silent in release). That is precisely the build where a user has
        // megabytes of now-unusable vectors on disk, so bailing out on `fetcher == nil` would show
        // them no row and no Remove button in the one state where removal is the whole point.
        guard let store = semanticShardStore else { return .unavailable }

        let usage = await store.diskUsage()
        let refusals = await store.recordedRefusals

        // The denominator survives a missing fetcher: `bundledExpectations()` is a static read of
        // a bundled resource, not actor state, so the published totals are available either way.
        let published: (volumes: Int, bytes: Int)
        let failures: [String: SemanticShardFetcher.FetchError]
        if let fetcher = semanticShardFetcher {
            published = await fetcher.publishedTotals
            failures = await fetcher.recordedFailures
        } else {
            let expectations = SemanticShardFetcher.bundledExpectations() ?? [:]
            published = (expectations.count, expectations.values.reduce(0) { $0 + $1.bytes })
            failures = [:]
        }

        return SemanticStorageReport(
            volumesOnDisk: usage.volumes,
            bytesOnDisk: usage.bytes,
            volumesPublished: published.volumes,
            bytesPublished: published.bytes,
            failures: failures.mapValues { SemanticStorageReport.describe($0) },
            // `compactMapValues`: two refusal cases are ORDINARY STATES, not faults — `noArtifact`
            // means nothing was ever fetched, and `documentNotVectorised` is about one document
            // rather than this volume's storage. `describe` returns nil for both, and listing them
            // would fill a problems list with the normal condition of an un-fetched library.
            refusals: refusals.compactMapValues { SemanticStorageReport.describe($0) })
    }

    /// Clears remembered shard-fetch failures so the next attempt can retry.
    ///
    /// The fetcher deliberately remembers a failure for the session so the lazy path does not retry
    /// on every query; that is right for a query and wrong for a person who has just reconnected
    /// and pressed the button. This is the button's half.
    func retrySemanticShardFetches() async {
        await semanticShardFetcher?.clearFailures()
    }

    /// Fetches a volume's semantic shard if it is missing, on a detached background task.
    ///
    /// Called from two places, and the split is deliberate. A volume's own download hook fetches
    /// eagerly, because **~294 KB** beside a ~6 MB volume is invisible and it makes the volume
    /// semantic-ready exactly when it becomes search-ready. Everything already on disk is fetched
    /// **lazily**, when a semantic surface first wants that volume — so an existing library does not
    /// silently pull **~162 MB** at launch to enable a feature the user has not opened yet.
    ///
    /// Both figures were HALF the truth until 2026-09-10 (they read 148 KB and 82 MB, from the
    /// 256-dim pack; the shipped width has been 512 since #933). Measured from
    /// `semantic-shards-manifest.json`: 553 shards, 162,354,028 bytes, mean 294 KB, largest 988 KB.
    /// They are quoted here because they ARE the argument for the split — at the real numbers the
    /// eager half is still invisible and the lazy half matters twice as much as this comment
    /// claimed.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// Why a shard fetch is being started — which decides whether the off switch applies.
    ///
    /// Stated at every call site rather than defaulted, so a future one cannot inherit the wrong
    /// answer silently.
    enum SemanticShardFetchReason {
        /// A volume finished downloading and its shard is riding along. **Honours the switch** —
        /// these are the bytes #926 is about: 553 requests fired by a corpus download for an axis
        /// the reader may never open. (It said "off by default" until 2026-09-10; the default is
        /// now 0.5, which makes the ride-along MORE likely to be read, not less — the switch is
        /// about the reader's bandwidth, not about the axis's odds.)
        case volumeDownloaded
        /// A semantic surface is being used right now and wants this shard. **Ignores the switch.**
        ///
        /// **This case NO LONGER ignores the switch, and the sentence it used to carry was wrong.**
        ///
        /// The original exemption was argued from consent: `.semanticSimilarity` had `defaultWeight`
        /// 0 and `skipsGenerationAtZeroWeight`, so reaching here required the reader to have
        /// deliberately raised an experimental axis off zero — a finer and later act of consent than
        /// the toggle, which a coarse earlier setting should not overrule. Raising the default to
        /// 0.5 (2026-09-10, D-D) removed that: for a reader who never touched the sliders there is
        /// no later act of consent at all.
        ///
        /// It was kept for one day on a replacement argument — that the lazy path costs "~294 KB
        /// against the ~6 MB already spent, one volume at a time" — **and that argument was false.**
        /// `SemanticSimilarityGenerator` collects `missingVolumes` across the WHOLE rerank pool and
        /// then loops, so one Related-panel open queues a shard for every candidate volume whose
        /// shard is absent, in one burst. Measured over 60 anchors against the shipped 20 MB block:
        /// the top-800 candidates span a **median of 104 distinct volumes, mean 107, max 227**, so a
        /// full library is **~31 MB per panel open** and up to ~67 MB — on the one path the reader's
        /// own "Download With Volumes" switch did not reach.
        ///
        /// So the switch now governs both reasons. **The cost of that is real and is the case the
        /// exemption originally existed to prevent**: a reader who turns automatic downloads off and
        /// then raises the semantic axis gets an axis that scores nothing, because the generator
        /// needs the anchor's shard to build its query vector at all. The remedy is not silent —
        /// Settings' semantic storage section counts the missing shards, names this switch as the
        /// cause while it is off, and offers **Download Missing Vectors**, which deliberately
        /// ignores the switch because pressing a button is the consent it withholds.
        ///
        /// The enum case is kept rather than collapsed into one reason: the two paths still mean
        /// different things, the call sites still state which they are, and a future policy that
        /// separates them again should not have to reintroduce the distinction.
        case readerAskedForSemantics
    }

    /// Whether an automatic shard fetch starts, given why it was asked for and the reader's switch.
    ///
    /// Extracted for the reason `RelatedDocumentsEngine.runsGenerator` and
    /// `SemanticProjectReach.runsScan` were: a policy a reader's bandwidth depends on should be
    /// driven by a test, not asserted by a grep over an inline condition. **Both reasons are
    /// governed since 2026-09-10** — the argument, and the measurement that ended the exemption, are
    /// on ``SemanticShardFetchReason/readerAskedForSemantics``.
    ///
    /// The `reason` parameter is deliberately still here although the rule no longer branches on it.
    /// It is what makes a future policy that separates the two paths again a change to THIS
    /// function, with these tests in front of it, rather than a re-litigation at the call site.
    ///
    /// - Parameters:
    ///   - reason: Why the shard was asked for.
    ///   - automaticDownloads: The reader's `Download With Volumes` setting.
    /// - Returns: `true` when the fetch should start.
    nonisolated static func startsAutomaticShardFetch(
        reason: SemanticShardFetchReason, automaticDownloads: Bool
    ) -> Bool {
        _ = reason
        return automaticDownloads
    }

    /// Asks for a volume's match file on behalf of a search by meaning, and answers whether a
    /// download is under way for it (#1527).
    ///
    /// A search's caption says match files are downloading only for the volumes this answers
    /// `true` for, so the answer reads every gate the fetch meets, not only the two a reader can
    /// see in Settings:
    /// - no fetcher: the stack booted without a shard manifest of the same generation
    ///   (`FRUSExplorerApp` leaves ``semanticShardFetcher`` `nil`), so nothing can be fetched;
    /// - no published file for the volume;
    /// - a fetch for it that already failed this session, which the fetcher refuses to retry until
    ///   its failures are cleared (Try Failed Downloads Again, or either Download button);
    /// - offline, or Download With Volumes off — ``fetchSemanticShardIfNeeded(for:reason:)``'s own
    ///   gates, read last and on the main actor in the same call that starts the fetch, so a
    ///   `true` never answers for a state that changed while the fetcher was being asked.
    ///
    /// `true` means a fetch started now, or one started earlier is still running (the fetcher
    /// de-duplicates, so asking again costs nothing). The searcher asks afresh on every search
    /// rather than once per launch, because the answer changes: the reader turns the switch on,
    /// the device reconnects, a fetch fails.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// - Returns: Whether a download of the volume's match file is under way.
    func requestSemanticShardForSearch(_ volumeID: String) async -> Bool {
        guard let fetcher = semanticShardFetcher else { return false }
        guard await fetcher.hasShard(for: volumeID),
              await fetcher.failure(for: volumeID) == nil else { return false }
        return fetchSemanticShardIfNeeded(for: volumeID, reason: .readerAskedForSemantics)
    }

    /// Starts a background fetch of a volume's shard when the gates below allow it — the doc
    /// comment above ``SemanticShardFetchReason`` argues where it is called from and why.
    ///
    /// - Parameters:
    ///   - volumeID: Manifest `volumeId`.
    ///   - reason: Why the shard is wanted; it is stated at every call site.
    /// - Returns: Whether the fetch task was started. The task can still find the shard already on
    ///   disk, or a fetch of it already running, and then does nothing.
    @discardableResult
    func fetchSemanticShardIfNeeded(for volumeID: String,
                                    reason: SemanticShardFetchReason) -> Bool {
        guard let store = semanticShardStore, let fetcher = semanticShardFetcher else { return false }
        // **`isOnline` and nothing else — no cellular check, by owner decision D-E (2026-09-10).**
        // Stated here because the absence reads as an oversight beside `DownloadManager`, which
        // does consult a cellular preference, and because two sessions have now raised it. With the
        // axis on by default one Related-panel open can queue a median of 104 shards (~31 MB,
        // measured over 60 anchors on the shipped block), so the question was real; the answer is
        // that the reader already has two controls that stop it — the switch below, which governs
        // this path since #1265, and the axis's own weight. That covers a search by meaning too,
        // which queues its top candidates' volumes whether or not the reader downloaded them.
        guard isOnline else { return false }
        // **The off switch (#926)**, read the way `DownloadManager` reads its cellular twin —
        // straight from `UserDefaults` with the default spelled here, so no view owns it and a
        // device that has never seen the toggle behaves as it always did.
        //
        // **It applies to BOTH reasons since 2026-09-10**, where it governed the ride-along alone.
        // The reason it once governed less than its label is recorded on `readerAskedForSemantics`,
        // along with the measurement that retired it: that path does not ask for one volume, it asks
        // for every candidate volume in the rerank pool whose shard is absent — a median of 104 and
        // up to 227 for a full library, ~31 MB in a burst — so leaving it exempt meant a reader who
        // switched automatic downloads OFF got 31 MB per Related-panel open. A switch that governs
        // less than its label is a defect; one that governs more than the reader expects is worse.
        guard Self.startsAutomaticShardFetch(
            reason: reason, automaticDownloads: Self.automaticSemanticShardDownloads) else { return false }
        Task.detached(priority: .utility) {
            guard await store.shard(for: volumeID) == nil else { return }
            guard await fetcher.hasShard(for: volumeID) else { return }
            do {
                try await fetcher.fetchShard(for: volumeID, into: store)
            } catch {
                #if DEBUG
                print("[AppState] semantic shard fetch failed for \(volumeID): \(error)")
                #endif
            }
        }
        return true
    }

    // MARK: - Semantic Query-Encoder Model (V-5 s2)

    /// The store holding the optional 310 MB query-encoder model, once the bundled index has
    /// loaded — the pin it verifies against is the artifact's `modelFileSHA256`, so it cannot
    /// exist before `BundledSemanticVectors.prepare()` succeeds. `nil` means the semantic stack
    /// did not boot, never that the model is absent (the store answers that itself).
    var semanticModelStore: SemanticModelStore?

    /// Fetches the model file from the app-owned release. `nil` under the same conditions as
    /// ``semanticModelStore``.
    var semanticModelFetcher: SemanticModelFetcher?

    /// Progress of the model download, or `nil` when none is running.
    ///
    /// **Bytes, not a count** — the opposite of ``semanticShardDownload``, for the reason the
    /// fetcher's header gives: one 310 MB file is exactly the size class where a silent transfer
    /// reads as a hang, and a download delegate makes the bytes observable.
    var semanticModelDownload: SemanticModelDownloadProgress?

    /// The typed-query semantic searcher (V-5 s3). `nil` under the same conditions as
    /// ``semanticModelStore`` — it needs the bundled index, both stores, and the pin. Its
    /// existence does not imply the model is downloaded; `search` throws `.modelNotDownloaded`
    /// and the fallback surface offers the download.
    var semanticQuerySearcher: SemanticQuerySearcher?

    /// A model download in flight.
    struct SemanticModelDownloadProgress: Equatable, Sendable {
        /// Bytes received so far.
        var bytesReceived: Int64
        /// Bytes the server said to expect (`SemanticModelStore.publishedBytes` until it answers).
        var bytesExpected: Int64

        /// Fraction done, for a determinate progress view.
        var fraction: Double {
            bytesExpected > 0 ? Double(bytesReceived) / Double(bytesExpected) : 0
        }
    }

    /// What the storage screen shows about the encoder model — assembled here for the same
    /// twin-hubs reason as ``semanticStorageReport()``.
    struct SemanticModelStatus: Equatable, Sendable {
        /// Whether the semantic stack booted at all; when false the screen says unavailable,
        /// never "not downloaded".
        var isAvailable: Bool
        /// The verified model file's location, or `nil` when no verified copy is on disk.
        ///
        /// **Carried here rather than fetched by the view, and that is the point.** The settings
        /// row that shows the path used to call `SemanticModelStore.verifiedModelURL()` straight
        /// from its body — an actor-isolated call from a synchronous MainActor context, which is a
        /// strict-concurrency warning, and two filesystem stats on every body evaluation. This
        /// status is already built from an `await` against that same actor, so the URL rides along
        /// with the rest of the state for free.
        var verifiedURL: URL?

        /// Whether a verified copy is on disk.
        ///
        /// Computed, never stored: it and `verifiedURL` are the same fact, and two stored fields
        /// filled from two separate reads of the same disk can disagree — the row saying "present"
        /// while the path row shows nothing, or the reverse.
        var isPresent: Bool { verifiedURL != nil }
        /// Bytes the stored file occupies (0 when absent).
        var bytesOnDisk: Int
        /// The last fetch failure, described for the screen; `nil` when none is remembered.
        var failure: String?

        /// The stack-not-booted state.
        static let unavailable = SemanticModelStatus(
            isAvailable: false, verifiedURL: nil, bytesOnDisk: 0, failure: nil)
    }

    /// Reads the model's current state for the storage screen.
    func semanticModelStatus() async -> SemanticModelStatus {
        guard let store = semanticModelStore else { return .unavailable }
        let failure: SemanticModelError? = if let fetcher = semanticModelFetcher {
            await fetcher.lastFailure
        } else {
            nil
        }
        return SemanticModelStatus(
            isAvailable: true,
            // `verifiedModelURL()` rather than `isModelPresent()`: the latter is defined as
            // `verifiedModelURL() != nil`, so asking for the URL is the same hop and the presence
            // flag falls out of it. One read of the disk, one answer.
            verifiedURL: await store.verifiedModelURL(),
            bytesOnDisk: await store.bytesOnDisk(),
            failure: failure.map { Self.describeModelError($0) })
    }

    /// Downloads the encoder model, driving ``semanticModelDownload`` as bytes arrive.
    ///
    /// The button that calls it states the size and where the model runs; since B4 there is no
    /// consent sheet, the Gemma Terms' flow-down having retired with EmbeddingGemma 300m. This
    /// method owns only the transfer and the progress mirror. Failures are remembered by the fetcher and reach the screen through
    /// ``semanticModelStatus()`` — not thrown past the button that started them.
    func downloadSemanticModel() async {
        // Adoption happens inside the fetcher, against the store it was built with — only the
        // fetcher is needed here, and it exists only when the store does.
        guard let fetcher = semanticModelFetcher else { return }
        guard semanticModelDownload == nil else { return }
        await fetcher.clearFailure()
        semanticModelDownload = SemanticModelDownloadProgress(
            bytesReceived: 0, bytesExpected: Int64(SemanticModelStore.publishedBytes))
        do {
            try await fetcher.fetchModel { [weak self] received, expected in
                Task { @MainActor in
                    guard let self, self.semanticModelDownload != nil else { return }
                    self.semanticModelDownload = SemanticModelDownloadProgress(
                        bytesReceived: received,
                        bytesExpected: expected > 0
                            ? expected : Int64(SemanticModelStore.publishedBytes))
                }
            }
        } catch {
            #if DEBUG
            print("[AppState] semantic model fetch failed: \(error)")
            #endif
        }
        semanticModelDownload = nil
    }

    /// Cancels a running model download.
    func cancelSemanticModelDownload() async {
        await semanticModelFetcher?.cancel()
    }

    /// Removes the stored model file.
    func removeSemanticModel() async {
        await semanticModelStore?.removeModel()
    }

    /// One place the model-fetch failure vocabulary lives, so both hubs say the same thing.
    static func describeModelError(_ error: SemanticModelError) -> String {
        switch error {
        case .wrongLength(let expected, let found):
            String(format: String(
                localized: "settings.model.error.length %lld %lld",
                defaultValue: "The download was incomplete (%lld of %lld bytes). Try again."),
                Int64(found), Int64(expected))
        case .wrongDigest:
            String(localized: "settings.model.error.digest",
                   defaultValue: "The downloaded file failed verification and was discarded.")
        case .httpStatus(let status):
            String(format: String(
                localized: "settings.model.error.http %lld",
                defaultValue: "The server refused the download (HTTP %lld)."),
                Int64(status))
        case .transport:
            String(localized: "settings.model.error.transport",
                   defaultValue: "The download could not be completed. Check the connection and try again.")
        }
    }

    // MARK: - Download Queue

    /// Volume IDs currently queued for download (active + pending).
    ///
    /// Updated by `DownloadManager` via its `onStateChanged` callback. Views observe
    /// this to show download indicators without calling into the actor directly.
    ///
    /// An indexing queue in flight counts each volume listed here among its own (#1757): a
    /// subseries is still being queued when its first volume begins indexing, and every volume
    /// queued after that is part of the wait the banner reports.
    var downloadQueue: [String] = [] {
        didSet { countInIndexingBatch(downloadQueue) }
    }

    // MARK: - Person Rollup Signal

    /// Bumped whenever the materialised person rollup has been **rebuilt** — by a correction
    /// (merge / separate / undo), by a corpus change (volumes added or removed), or by the launch
    /// consolidation after a `currentPersonRollupVersion` bump. Any surface holding a rollup id or
    /// showing rollup-derived rows refreshes reactively via `.onChange` — the live-signal pattern
    /// this codebase prefers over navigation- or scene-phase-triggered reloads (Session 4 / #243).
    /// The value itself is meaningless; only changes matter.
    ///
    /// Renamed from `personRollupGeneration` in #747. The old name described one of its three
    /// triggers, and the narrow reading was load-bearing: corrections were the only path that
    /// raised it, so every other rebuild renumbered `rollup_id` under live search chips and open
    /// analytics selections with nothing to tell them. It is now raised inside
    /// ``PersonRollupRefresh``, where the rebuild actually happens, rather than by hand at call
    /// sites that could forget.
    var personRollupGeneration: Int = 0

    // MARK: - Tag Stores

    /// Resolves volume-level tag slugs and provides volume-by-tag queries.
    ///
    /// Loaded synchronously at init from `volume-tag-taxonomy.json`, plus the manifest
    /// entries ``manifestStore`` has already decoded — see `init()`. Assigned there rather
    /// than here because the order of the two matters.
    let volumeLevelTagStore: VolumeLevelTagStore

    /// Loads and merges the volume manifest. Loaded from bundle at init; live data fetched at boot.
    ///
    /// Constructed **first** among the stores, because it owns the one decode of
    /// `manifest.json` that the rest share.
    var manifestStore: ManifestStore

    /// Holds the bundled `source-provenance-index.json` aggregate (Series Analytics
    /// SA-3a), the offline data source for the "Archival Sourcing Over Time"
    /// dashboard (SA-3b). Decoded from the bundle at init; `nil` if unavailable.
    let sourceProvenanceStore: SourceProvenanceStore = SourceProvenanceStore()

    /// Holds the bundled `administration-profiles-index.json` aggregate (Series
    /// Analytics SA-2a), the offline data source for the "Administration Profiles"
    /// dashboard (SA-2b). Decoded from the bundle at init; `nil` if unavailable.
    let administrationProfilesStore: AdministrationProfilesStore = AdministrationProfilesStore()

    /// Shared in-memory LRU cache of parsed document ASTs. Warmed by
    /// `DocumentViewModel.load` parse windows so adjacent-document page-turns and
    /// re-opens skip the XML parse entirely. Cleared per-volume on deletion and
    /// globally on iOS memory warnings.
    let documentASTCache = DocumentASTCache()

    // MARK: - Search Infrastructure

    /// The shared indexing pipeline. Created at boot by `FRUSExplorerApp` alongside
    /// `DownloadManager`; `nil` if the database could not be opened.
    var indexingPipeline: IndexingPipeline?

    /// The shared search service. Created at boot alongside `indexingPipeline`;
    /// `nil` if the FTS5 database could not be opened.
    var searchService: SearchService?

    /// The shared corpus analytics service. Created at boot alongside `searchService`;
    /// `nil` if the FTS5 database could not be opened.
    var analyticsService: CorpusAnalyticsService?

    /// The shared word-frequency service backing word clouds. Created at boot
    /// alongside `searchService`; `nil` if the FTS5 database could not be opened.
    var wordFrequencyService: WordFrequencyService?

    /// Coordinates optional cross-device settings sync. Created at boot with the
    /// main model context; `nil` until then. Holds no UI state itself — it mirrors
    /// `UserDefaults` to/from a CloudKit-synced record when the device opts in.
    var settingsSync: SettingsSyncCoordinator?

    // MARK: - Research Logging Preference

    /// The `UserDefaults` key behind Settings ▸ Research ▸ Research Sessions ▸
    /// "Log Research Sessions".
    ///
    /// **Do not change this string.** It is user-data-bearing and mirrored into CloudKit
    /// through `SyncedPreferences.researchLoggingEnabled`, so renaming it would silently
    /// reset every existing user's choice and desynchronise their devices.
    nonisolated static let researchLoggingPreferenceKey = "researchSessionLoggingEnabled"

    /// Whether the app may record what the user reads and searches for, read from an
    /// explicit `UserDefaults` store.
    ///
    /// This is the **single** reader of ``researchLoggingPreferenceKey``. Every writer of the
    /// research trail routes through it — `DocumentViewModel.recordReadingHistory(projectId:in:
    /// defaults:)`, `MacSearchViewModel.recordSearchHistory(projectId:in:defaults:)` and its iOS
    /// counterpart `SearchViewModel.recordSearchHistory(projectId:in:defaults:)`, and since Wave
    /// R-2a `ExportHistoryRecorder.record(…)` — so the switch cannot govern one recorder and miss
    /// another, which is exactly what it did before Wave R-1: the gate lived inline in the
    /// now-retired `logEvent` and the two history stores had no gate at all. Wave R-4's iOS search
    /// writer was gated from its first commit for the same reason: an ungated one would have
    /// started collecting search text on a platform that was not.
    ///
    /// `ResearchTrailMigration` deliberately did **not** consult it: moving records the user
    /// already had was not collection, and skipping the move when the switch was off would have
    /// destroyed them instead of preserving them. (That pass was itself retired in R-2b, #981.)
    ///
    /// An **absent** value means **on**. Both the app gate and
    /// `SettingsSyncCoordinator`'s pull rely on that convention; a well-meaning change to
    /// default-off would silently disable recording for every existing user.
    ///
    /// - Parameter store: The defaults store to consult. Production callers use
    ///   `.standard`; the store is a parameter so `SettingsSyncCoordinator` can pass the
    ///   store it was handed, and so tests can drive the gate without mutating global state.
    /// - Returns: `true` when the app may record research activity.
    nonisolated static func isResearchLoggingEnabled(in store: UserDefaults) -> Bool {
        (store.object(forKey: researchLoggingPreferenceKey) as? Bool) ?? true
    }

    /// Whether the app may record what the user reads and searches for, per
    /// `UserDefaults.standard`. Convenience over ``isResearchLoggingEnabled(in:)``.
    nonisolated static var isResearchLoggingEnabled: Bool {
        isResearchLoggingEnabled(in: .standard)
    }

    // MARK: - Research Session Logging (retired, Wave R-2a)
    //
    // `logEvent(_:defaults:)`, `loggingContext`, the in-memory `currentResearchSession` and
    // `sessionExpiryInterval` all lived here. Nothing writes a `ResearchSession` or a
    // `SessionEvent` any more:
    //
    //   • document opens were already recorded as `ReadingHistoryEntry` from the same two views;
    //   • searches are recorded as `SearchHistoryEntry` on both platforms since Wave R-4;
    //   • exports are `ExportHistoryEntry` (contract D1);
    //   • note saves are dropped — `ResearchNote` timestamps itself (contract D2).
    //
    // Sessions are now derived from those tables' timestamps by `ResearchTrailSessions`, whose
    // `idleInterval` is the 30 minutes this constant used to hold. `ResearchTrailMigration` moved
    // what was worth keeping out of the legacy tables and was itself retired in R-2b (PR #981).

    /// The shared cross-reference store. Created at boot alongside `indexingPipeline`;
    /// `nil` if the database could not be opened.
    var crossReferenceStore: CrossReferenceStore?

    /// The shared person mention store. Created at boot alongside `crossReferenceStore`;
    /// `nil` if the database could not be opened.
    var personMentionStore: PersonMentionStore?

    /// The shared printed-page lookup store (page_ranges table). Created at boot;
    /// used by document views to resolve printed-page cross-references
    /// (`#pg_313`) to the document that begins on the page (Session 162, #1503). `nil` if the
    /// database could not be opened.
    var pageRangeStore: PageRangeStore?

    /// Bumped each time `refreshReadOnlyStores` reopens the read-only stores after an index
    /// rebuild. Dashboards that read those stores (`CrossReferenceAnalyticsView`,
    /// `PersonAnalyticsView`) observe this and reload, so a view already on screen when a reindex
    /// finishes refreshes instead of showing the empty results a stale connection returns (#275).
    var readOnlyStoresGeneration: Int = 0

    /// The one-time boot of the search infrastructure, held so scenes that appear together await
    /// the same work rather than each starting their own.
    ///
    /// Any scene may be the first on screen — a restored Search window boots the app just as the
    /// main window does — so the boot cannot belong to one of them.
    var searchInfrastructureBoot: Task<Void, Never>?

    /// The `frus.db` URL, set at boot alongside the read-only stores. Retained so any in-session
    /// index rebuild (Settings "Reindex All" / "Rebuild Index", boot reindex) can reopen the stores
    /// against it via `refreshReadOnlyStores()` (#275).
    var databaseURL: URL?

    /// The downloaded-volumes directory, set at boot. Retained so `refreshReadOnlyStores()` can
    /// hand it to the citation engine it rebuilds, which reads it at each lookup (#1522), and so
    /// `refreshAfterCorpusChange(context:)` can reconcile side-loaded volumes into the catalogue
    /// (`ManifestStore.refreshLocalEntries(volumesDirectory:)`, #777).
    var volumesDirectory: URL?

    /// The app's SwiftData container, retained so main-actor work `AppState` itself initiates — the
    /// post-indexing corpus refresh — can reach `PersonClusterOverride` without a view's
    /// `@Environment(\.modelContext)` (R-1d).
    ///
    /// Not a `@Model` and not a stored property on one, so `frusModelTypes` is unchanged and no
    /// CloudKit deploy is implied.
    var modelContainer: ModelContainer?

    /// Reopens the read-only SQLite stores (`crossReferenceStore`, `personMentionStore`,
    /// `pageRangeStore`) and the `citationMatchingEngine` that captures one, against the settled
    /// database after an index rebuild. Call this whenever the index tables are rebuilt in-session —
    /// the boot reindex branches AND the Settings "Reindex All" / "Rebuild Index" actions.
    ///
    /// Each store is created once at boot and holds a single long-lived read-only connection opened
    /// *before* any reindex runs. A rebuild's per-volume delete+reinsert and repeated WAL
    /// checkpoints can leave those connections returning empty results for the rest of the session —
    /// so cross-reference / person analytics show "No Data" until the app is relaunched, even though
    /// the index is fully intact (#275). Recreating the stores yields fresh connections against the
    /// settled database; the old connections close in their `deinit`. Bumping
    /// `readOnlyStoresGeneration` lets dashboards on screen reload. `searchService` /
    /// `indexingPipeline` read through the pipeline's own writer connection, which sees the
    /// rebuild's writes directly, so they are intentionally left untouched.
    ///
    /// No-op if `databaseURL` has not been set yet (index infrastructure never came up).
    /// `refreshReadOnlyStores()` **plus** the person-rollup drift check — the call every action
    /// that adds, removes or re-indexes volumes should make (#747 / audit M-14).
    ///
    /// Reopening the read-only connections only refreshes *connections*. It does not recompute the
    /// materialised `person_rollup` tables, which are derived data: `removeVolume` deletes the
    /// `persons` and `person_mentions` rows but leaves the rollup standing, so the People browser
    /// kept listing people whose only mentions were in a removed volume — with their old counts —
    /// and newly indexed volumes' people stayed invisible, in both cases until the next launch.
    ///
    /// The drift check is cheap when nothing moved, so this is the safe default even for actions
    /// that merely VACUUM. When it *does* rebuild, the connections are reopened a second time (the
    /// rebuild replaced every row underneath them) and `personRollupGeneration` is published so
    /// open filter chips and dashboards can re-resolve the ids they are holding.
    ///
    /// - Parameter context: the main-actor context holding `PersonClusterOverride`. Required for
    ///   correctness, not convenience — see `PersonRollupRefresh.afterCorpusChange`. **Non-optional
    ///   since R-1d**: a `nil` here snapshotted no overrides and stamped the empty-set fingerprint,
    ///   rebuilding a rollup that ignored the reader's merges. The type now refuses it, which is
    ///   stronger than a guard because a future caller cannot write the bug at all.
    func refreshAfterCorpusChange(context: ModelContext) {
        refreshReadOnlyStores()
        // #777: a side-loaded volume is a corpus change the catalogue cannot see. Reconciling here
        // means the volume is browsable the moment its import finishes.
        reconcileSideloadedVolumes()
        guard let indexingPipeline else { return }
        Task { @MainActor in
            if await PersonRollupRefresh.afterCorpusChange(context: context,
                                                           pipeline: indexingPipeline,
                                                           appState: self) {
                refreshReadOnlyStores()
            }
        }
    }

    /// Reads the side-loaded volumes' sidecars into the catalogue, minting one for any volume that
    /// has none (`ManifestStore.refreshLocalEntries(volumesDirectory:)`, #777).
    ///
    /// Two callers, and the second is the one that was missing: ``refreshAfterCorpusChange(context:)``,
    /// so a volume is browsable the moment its import finishes, and boot, right after the volumes
    /// directory is known. Before boot called it, a relaunch with no indexing batch listed every
    /// side-loaded volume by its raw id — in Volumes & Storage, in Browse, everywhere
    /// `entry(forVolumeId:)` is read — until a hub action or the end of an indexing batch reached
    /// this, while two doc comments said boot already did. The steady-state cost is one directory
    /// listing and a read of each side-loaded volume's sidecar; a header is parsed only for a
    /// volume side-loaded before #777 shipped, once.
    ///
    /// No-op until boot has set ``volumesDirectory``.
    func reconcileSideloadedVolumes() {
        guard let volumesDirectory else { return }
        manifestStore.refreshLocalEntries(volumesDirectory: volumesDirectory)
    }

    func refreshReadOnlyStores() {
        guard let databaseURL else { return }
        crossReferenceStore = try? CrossReferenceStore(databaseURL: databaseURL)
        personMentionStore = try? PersonMentionStore(databaseURL: databaseURL)
        let freshPageRangeStore = try? PageRangeStore(databaseURL: databaseURL)
        pageRangeStore = freshPageRangeStore
        // The citation engine captures the page-range store by value, so recreating the store on
        // `AppState` alone would leave the engine holding the stale connection; rebuild it too.
        // It reads the volumes directory at each lookup rather than a list taken here (#1522).
        if let searchService, let volumesDirectory {
            citationMatchingEngine = CitationMatchingEngine(
                manifestStore: manifestStore,
                searchService: searchService,
                pageRangeStore: freshPageRangeStore,
                volumesDirectory: volumesDirectory
            )
        }
        readOnlyStoresGeneration &+= 1
        #if DEBUG
        print("[AppState] Reopened read-only stores after reindex (generation=\(readOnlyStoresGeneration)).")
        #endif
    }

    /// Directory containing the SQLite index databases (frus.db). Set at boot;
    /// used by the Volumes & Storage hub to report index disk usage.
    var indexDirectory: URL?

    /// Set by "Find all mentions", Corpus Analytics, indexing banners, … to open Search pre-filled.
    /// Scene-addressed (#338 step 5): the iOS `SearchView` / macOS `SearchSheet` consume it through
    /// ``consumeHandoff(_:for:)`` so the query runs in the producing window (paired with `openTab`),
    /// fixing the BUG-6 nondeterministic winner + the tab/query decoupling.
    var pendingSearch: Handoff<SearchParameters>? = nil

    /// A request to show Search Tips, from the Find menu on either platform (#1299).
    ///
    /// A `Handoff` rather than a counter, on both platforms and for two reasons. On iPad every window has its own
    /// `SearchView`, so a counter every one of them observed would open the sheet in all of them; a hand-off clears as
    /// it is consumed, so one window acts. On the Mac the request usually opens the Search window as well, and a
    /// counter bumped before that window exists is never seen by the `.onChange` of the view it creates — the reason
    /// `pendingSearch` is also read in a first-load `.task`. The payload carries nothing; the request is the message.
    /// Set through ``openSearchTips(from:)``.
    var pendingSearchTips: Handoff<Bool>? = nil

    /// Cross-view handoff from Search to Corpus Analytics (and vice versa).
    ///
    /// Set by `SearchView` when the result count hits `SearchViewModel
    /// .searchHardLimit` and the user chooses to "Visualize in Corpus Analytics" —
    /// seeding the chart with the submitted keywords (and active date filter, if
    /// any) so they can see the distribution over time and pick a narrower range.
    /// `BrowserView` (iOS sheet) and `AnalyticsView` (macOS `frus.analytics` window) observe this via
    /// `.onChange` + drain and consume it through ``consumeHandoff(_:for:)`` — scene-addressed (#338
    /// step 3) so on iPad multi-window only the producing window's Browse tab presents the chart.
    var pendingAnalytics: Handoff<AnalyticsParameters>? = nil

    /// Cross-view handoff into the corpus Chronology browser.
    ///
    /// Set when another surface wants to open Chronology pre-seeded with a date range
    /// (e.g. a future "browse this range chronologically" affordance from Search or
    /// Corpus Analytics). `BrowserView` (iOS sheet) and `ChronologyView` (macOS `frus.chronology`
    /// window) observe this via `.onChange` + drain and consume it through ``consumeHandoff(_:for:)``
    /// — scene-addressed (#338 step 3) so on iPad multi-window only the producing window presents it.
    var pendingChronology: Handoff<ChronologyParameters>? = nil

    /// Cross-view handoff into the Word Cloud analytics view.
    ///
    /// Set by any surface (document toolbar, volume/subseries browser, collection,
    /// user tag, saved search) that wants to open a word cloud for a given scope.
    /// `MainTabView` (iOS sheet) and the macOS `frus.wordcloud` window observe this
    /// via `.onChange`, present the cloud, and clear it — mirroring the
    /// `pendingSearch` / `pendingAnalytics` pattern.
    var pendingWordCloud: Handoff<WordCloudScope>? = nil

    /// Cross-view hand-off into Archival Analytics with a volume scope already applied (#833).
    ///
    /// Set by any surface that can name a volume set a researcher is thinking in — a subject on
    /// a volume's Subjects page, a detected-topic chip, a search result set. The Collections mode
    /// is scoped to it on arrival, which is what turns "the archival profile of the volumes about
    /// X" from a thing the reader must assemble by hand into one tap.
    ///
    /// The same `Handoff` shape as `pendingWordCloud` and for the same reason: it has to work
    /// where the destination is a **window** (macOS) as readily as where it is a sheet or a tab,
    /// and the target scene is what makes a hand-off land in the window the reader was in.
    var pendingArchivalScope: Handoff<ArchivalScopeRequest>? = nil

    /// A pending Subject Explorer open, addressed to the scene that should present it (#1023).
    ///
    /// Same `Handoff` shape and for the same reason as `pendingArchivalScope`: the destination is a
    /// **window** on macOS and a pushed level on iOS, and the target scene is what makes the
    /// hand-off land where the reader actually was.
    var pendingSubjectExplorer: Handoff<SubjectExplorerRequest>? = nil

    /// One-shot hand-off for a continued semantic map (UI review F-28) — the scope and lens a
    /// Handoff activity arrived with.
    ///
    /// The same `Handoff` shape as `pendingArchivalScope`, for the same reason: the destination is
    /// a **window** on macOS and a sheet on iOS, and the target scene is what makes it land where
    /// the reader is.
    var pendingSemanticMap: Handoff<SemanticMapRequest>? = nil

    /// One-shot hand-off for the second-project nudge (#377 Phase 5): the id of a project the
    /// researcher just created that brought their project count to ≥ 2. Set by
    /// `ProjectEditorView.saveProject`; the nudge host (iOS `MainTabView` / macOS Settings) presents
    /// a one-time "open Project Home?" prompt for it and clears it. Transient (never persisted) —
    /// the *once-only* gate is the `@AppStorage("frus.hasShownSecondProjectNudge")` flag at the host.
    // F-20 (iPad review): a Handoff, not a bare UUID — the bare signal was addressed app-wide,
    // so an iPad Stage-Manager setup showed the alert in EVERY open window. The target routes it
    // to the window the project was created in; `.anyWindow` serves the macOS Settings host,
    // which mounts one modifier and has no scene id to match.
    var pendingSecondProjectNudge: Handoff<UUID>? = nil

    /// Cross-window hand-off into the Collections manager: the id of a collection
    /// another surface wants selected there.
    ///
    /// Set by `FRUSExplorerApp.importOpenedCollection` (macOS) immediately before
    /// `openWindow(id: "frus.collections")` when a `.fruscollection` file is opened
    /// from Finder / Files / AirDrop, so the freshly surfaced Collections window
    /// lands on the imported collection instead of appearing unchanged.
    /// `MacCollectionManagerView` consumes it (`.task` for a window created by the
    /// hand-off, `.onChange` for one already open) and clears it — mirroring the
    /// `pendingSearch` / `pendingAnalytics` pattern.
    var pendingCollectionSelection: UUID? = nil

    #if os(macOS)
    /// Cross-window hand-off into the Archives Visits window: the id of a plan another surface wants
    /// shown there (#1462).
    ///
    /// Set by ``openArchiveVisitWindow(on:using:)`` — Project Home's Plan a Visit and Review Changes'
    /// Open the plan — immediately before the window is brought forward, because the window's
    /// selection is its own state. `MacArchiveVisitManagerView` takes it on appear, when it changes,
    /// and when its plan list changes, and clears it once the plan is shown
    /// (``ArchiveVisitWindowHandoff/take(request:selection:planIds:)``). Both entry points used to
    /// present the editor in a sheet instead, which the Mac drew as a strip holding only Done.
    var pendingArchiveVisitSelection: UUID? = nil
    #endif

    #if os(iOS)
    /// The iOS twin of ``pendingCollectionSelection``, addressed to a scene (#752 / M-25).
    ///
    /// A separate slot rather than a scene on the existing one, because the existing one is
    /// macOS's: there a singleton Collections window consumes it and there is no scene to address.
    /// On iOS every open window's `CollectionListView` drains the untargeted slot, so the imported
    /// collection could surface in a different window from the one the tab switch went to — the
    /// two halves of the same continuation, split.
    var pendingCollectionSelectionScene: Handoff<UUID>? = nil
    #endif

    /// Bumped when the user asks to **type a new query** — ⌥⌘F (Find ▸ Search…) or the main
    /// window's titlebar Search button (#749 / audit L-35).
    ///
    /// The macOS Search window is a singleton, so re-summoning it runs no code inside it and
    /// re-fronting never resets first responder: keystrokes went to whatever control was last
    /// focused — the results list, a filter — so typing a query moved the result selection instead.
    /// `MacSearchWindowView` observes this and puts focus back in the query field.
    ///
    /// Deliberately NOT bumped by the parameter hand-offs (Corpus Analytics → Search, a saved
    /// search, a facet drill-in). Those windows arrive pre-filled and the user's next action is
    /// reading results, not typing; stealing focus there would be its own bug. This is the same
    /// refocus-on-reinvoke shape as `DocumentFindBar`'s `focusToken`.
    var searchQueryFocusToken = 0

    /// Whether the FRUS Research Guide's indexing sheet has been on screen in this app session
    /// (#757 / audit L-46, #1757).
    ///
    /// Lives here because `AppState` **is** the session — created once per launch, outliving every
    /// view recreation. The flag was `@AppStorage`, which made the designed once-per-session
    /// introduction a once-per-**install** one: a researcher who indexed a batch months ago never
    /// saw it again on their next tranche, because nothing ever reset the key.
    ///
    /// Set when the sheet appears (`indexingGuideDidAppear()`), not when it is asked for: until
    /// #1757 the queue banner set it as it asked, so a request that showed nothing still spent the
    /// session's one introduction.
    var hasShownIndexingEducationThisSession = false

    /// The window that has asked to open the FRUS Research Guide for this session's first queue of
    /// two or more volumes, until the Guide is on screen (#1757).
    ///
    /// Every main window's tab shell sees the queue at once, so without a claim two iPad windows
    /// would each open a Guide. The flag above was that claim until #1757, set as the first banner
    /// asked; a claim can be let go (`releaseIndexingGuideClaim(for:)`), so a request that never
    /// reached the screen leaves the next queue free to ask.
    @ObservationIgnored
    private(set) var indexingGuideRequester: SceneID?

    /// Whether the window `scene` may open the FRUS Research Guide for the queue now in flight, and
    /// if so, claims the request for it (#1757).
    ///
    /// Yes when a queue of two or more volumes is in flight (`indexingQueuePosition`), the Guide has
    /// not been on screen this session, the keyboard is down (the banner yields to it, #1070, and
    /// the Guide waits with it rather than take the screen from a reader typing), and no other
    /// window holds the request. The tab shell asks 0.6 s after the queue's banner first shows.
    func claimIndexingGuide(for scene: SceneID, keyboardIsVisible: Bool) -> Bool {
        guard indexingQueuePosition != nil, !hasShownIndexingEducationThisSession,
              !keyboardIsVisible, indexingGuideRequester == nil || indexingGuideRequester == scene
        else { return false }
        indexingGuideRequester = scene
        return true
    }

    /// The FRUS Research Guide's indexing sheet is on screen: the session's introduction is spent
    /// (#1757). Called from the sheet's own `onAppear`, whichever way it was opened.
    func indexingGuideDidAppear() {
        hasShownIndexingEducationThisSession = true
        indexingGuideRequester = nil
    }

    /// Lets go of the window `scene`'s claim on the FRUS Research Guide, when its queue has ended
    /// with the Guide never on screen or its window has closed (#1757).
    ///
    /// - Returns: Whether `scene` held the claim. The window then withdraws its request, so a sheet
    ///   still waiting behind another screen does not open over a queue that has ended.
    @discardableResult
    func releaseIndexingGuideClaim(for scene: SceneID) -> Bool {
        guard indexingGuideRequester == scene else { return false }
        indexingGuideRequester = nil
        return true
    }

    /// Whether the async boot has finished wiring the index stack (#753).
    ///
    /// `downloadManager` is assigned **last** in `bootDownloadManager`, after the store open, the
    /// pipeline, and the cleanup/migration passes — so its presence is the app's most conservative
    /// "everything downstream exists now" signal. Surfaces use it to tell *not yet* apart from
    /// *nothing here*, which they previously could not: `hasDownloadedVolumes(in: nil)` returns
    /// `false`, making a booting app look like an empty library.
    ///
    /// Deliberately not a separate flag someone has to remember to set. It is derived, so it cannot
    /// drift out of step with the thing it describes.
    var isBootComplete: Bool { downloadManager != nil }

    /// Cross-platform hand-off channel for opening a document from any tool surface. On **iOS**
    /// `BrowserView` observes it and appends to the Browse tab's path. On **macOS** every
    /// producer now routes directly through `openDocument(_:from:mintWindow:)` (provenance
    /// PR 2), so the only remaining macOS writer is `unregisterHost`'s demotion of an
    /// in-flight `routedBrowse` whose target closed with no surviving host — the hosts'
    /// observers + `onAppear` drains (`routeLegacyPendingBrowse`) stay as its delivery
    /// mechanism, re-resolving the value when the next host mounts.
    ///
    /// **That "every producer" claim was false for two releases and is load-bearing, so treat it as
    /// an invariant to be checked, not prose.** `ProjectHomeView` wrote this channel on macOS until
    /// #748: only its `openTab` call was `#if os(iOS)`-guarded, so the `openBrowseDocument` beside
    /// it ran on both platforms. With Project Home open and the main window closed there were no
    /// hosts to observe the write, so a click did nothing — and then fired as a surprise navigation
    /// whenever the user next opened a window. `WindowRoutingTests` now asserts the invariant
    /// against the source of every macOS-compiled producer, because a doc comment cannot.
    ///
    /// Scene-addressed (#338 step 4): iOS producers target the producing window's `\.sceneID` (only
    /// that window's `BrowserView` consumes), so a document hand-off no longer fans out across iPad
    /// windows; the macOS demotion targets `.macLegacyBrowse`, which `routeLegacyPendingBrowse` drains.
    var pendingBrowseDocument: Handoff<DocumentBrowserEntry>? = nil

    // MARK: Window routing — provenance model (macOS; Planning/Completed/Window-Routing-Provenance.md)

    /// The live document hosts, each with a monotonic "last became key" stamp. Registration and
    /// liveness — not focus sampling — decide where a provenance-routed open lands; the stamp is
    /// ADVISORY, consulted only by the fallback chain (originless opens, dead provenance), where
    /// staleness degrades gracefully instead of corrupting every route. Hosts register on appear,
    /// bump their stamp on `.key`, and unregister on `NSWindow.willClose` (+ `onDisappear` as
    /// belt-and-braces).
    var liveDocumentHosts: [DocumentHostID: UInt64] = [:]

    /// Live iPad scene identities — the `\.sceneID` of every open main window (`MainTabView`), which
    /// registers on appear and removes on disappear. The iPad analogue of `liveDocumentHosts`: it lets
    /// an auxiliary window (Archival Neighbors / Related Documents) resolve its "originating window"
    /// target to a still-open window, falling back to `.anyWindow` when that window has closed or the
    /// aux window was restored into a new session (#338 aux-window origin).
    ///
    /// **Not what closing an aux window reads (#1368).** Which window a Done brings forward is
    /// resolved against `UIApplication.openSessions` through ``mainWindowSessions``, because this set
    /// loses a window at `onDisappear`, which is not the same event as its session ending.
    var liveSceneIDs: Set<SceneID> = []

    #if os(iOS)
    /// Every main window's UIKit session, by raw scene token — registered by `MainTabView` beside its
    /// ``liveSceneIDs`` entry, and never removed (#1368). ``AuxWindowDestination`` says why a stale
    /// entry is harmless. `@ObservationIgnored`: no view renders from it; it is read at a tap.
    @ObservationIgnored
    var mainWindowSessions: [String: RegisteredMainWindow] = [:]

    /// The last ``RegisteredMainWindow/sequence`` handed out, so the newest registration is known.
    @ObservationIgnored
    var mainWindowSessionSequence = 0

    /// Every iOS aux window's UIKit session, by the token ``AuxWindowOriginModifier`` mints for it —
    /// registered from the modifier, never removed, and read only for a PLAIN close (#1368 review
    /// round 1). An aux window opened from another aux window — Source Explorer from the standalone
    /// document window's rail, say — goes back to that window when its Done is tapped, and the only
    /// way to ask iPadOS for it is its session. Kept apart from ``mainWindowSessions`` because the
    /// rule's fallback may choose any MAIN window and must never choose one of these: a hand-off
    /// delivered to an aux window would land nowhere.
    @ObservationIgnored
    var auxWindowSessions: [String: String] = [:]
    #endif

    /// The raw `\.sceneID` of the window currently launching a value-based auxiliary window (Archival
    /// Neighbors / Related Documents). Set by the launcher immediately before `openWindow(value:)` and
    /// drained by the aux window's `.onAppear` into its own state, so the aux window knows which main
    /// window opened it. Transient (never persisted) — a restored aux window reads nil and falls back
    /// to `.anyWindow`. #338 aux-window origin.
    ///
    /// ## The slot can be left populated, and that is harmless (#752 / L-48)
    /// `openWindow(value:)` against a value matching an already-open window **refocuses** it rather
    /// than minting a root, so nothing captures the slot and it stays set. The audit filed that as a
    /// defect on the theory that a later aux window would inherit a stale origin. It cannot:
    /// ``openAuxWindow(_:from:using:)`` is the only writer (through ``recordAuxWindowLaunch(from:)``,
    /// which writes ``pendingAuxWindowLauncherRaw`` in the same call), it writes **unconditionally
    /// immediately before every open**, and it is how iOS mints the twelve aux scenes that drain it —
    /// six through `.auxWindowOrigin` and, since #1368, the six analytics windows through
    /// `.auxWindowCloseOnly`, which record their launcher only so that their Done can bring it
    /// forward. Every open through
    /// it therefore overwrites the slot with its own launcher before the new root reads it — a parked
    /// value can only ever be re-read by the window that parked it. And a value that outlives its
    /// window degrades through ``resolveOriginScene(_:)`` to `.anyWindow`, which is a live window
    /// rather than nowhere.
    ///
    /// **One iOS opener goes round it** (checked for #1368, where this paragraph used to call
    /// ``openAuxWindow(_:from:using:)`` the only one): `DocumentView`'s Open in New Window command
    /// calls `openWindow(value:)` directly, so the document window it mints drains whatever the slot
    /// holds rather than its own launcher. That is normally nothing, and at worst a parked launcher —
    /// another main window, still a live destination. That window has no Done of its own, but what
    /// it drains is not inert: it becomes the `\.sceneID` its rail's windows are opened from, and so
    /// their ROUTING origin. It does not decide where THEIR Done goes — since #1368's review round
    /// they go back to the document window itself, through ``pendingAuxWindowLauncherRaw`` — except
    /// as the fallback once the document window has closed, where a parked main window is still a
    /// live destination.
    ///
    /// What *is* true, and is #338-accepted rather than a bug: an aux window refocused from a
    /// **different** main window keeps the origin it captured first, so an action inside it routes to
    /// the window that originally opened it. See ``AuxWindowOriginModifier``.
    var pendingAuxWindowOriginRaw: String? = nil

    /// The window the reader was STANDING IN when it launched the aux window being opened — drained
    /// beside ``pendingAuxWindowOriginRaw`` and written with it by ``recordAuxWindowLaunch(from:)``
    /// (#1368 review round 1).
    ///
    /// The two differ only when the launcher is itself an aux window. The standalone document
    /// window republishes its own launcher's scene as its `\.sceneID`, so a rail tool opened there
    /// was recorded as opened from that MAIN window; its Done then brought the main window forward
    /// and left the reader's document window behind it — or, with the main window gone, asked
    /// iPadOS for a brand-new one beside the document window that was still open. This slot holds
    /// the aux window's own token instead (``SceneID/borrowingWindow``), and the closing window
    /// goes back there while it is open. Routing still follows ``pendingAuxWindowOriginRaw``.
    var pendingAuxWindowLauncherRaw: String? = nil

    /// The continuation (Handoff / Spotlight / opened `.fruscollection`) a window has already
    /// claimed, so a second window cannot act on the same one (#752 / M-25).
    ///
    /// ## Why a claim exists at all
    /// UIKit delivers a user activity or a URL to **one** `UIScene`, and SwiftUI's
    /// `.onContinueUserActivity` / `.onOpenURL` bridge that per scene — so on the expected
    /// behaviour exactly one window's handler runs and this guard never fires. It is here because
    /// that expectation is **not verified on a device**, and the cost of being wrong is
    /// asymmetric: with the continuation now addressed to the receiving window's own scene, a
    /// fan-out would open the document in *every* window instead of one. The claim makes the
    /// change safe under both readings — one window acts either way.
    ///
    /// Keyed by content, not by object identity, so it also covers `.onOpenURL`, whose payload is
    /// a value type.
    private var claimedContinuationKey: String?

    /// Claims a continuation for the calling window, or refuses if another already has it.
    ///
    /// The claim is released on the next main-actor turn: co-delivered handlers all run in the
    /// turn the OS delivers them, while a user's second tap on the same Spotlight result is a
    /// later turn and must work.
    ///
    /// - Returns: `true` when the caller may act on the continuation.
    func claimContinuation(_ key: String) -> Bool {
        guard claimedContinuationKey != key else { return false }
        claimedContinuationKey = key
        Task { @MainActor [weak self] in self?.releaseContinuationClaim(key) }
        return true
    }

    /// Releases a claim if it is still the current one. Called on the turn after ``claimContinuation(_:)``;
    /// exposed so tests can drive the two halves without racing a `Task`.
    func releaseContinuationClaim(_ key: String) {
        if claimedContinuationKey == key { claimedContinuationKey = nil }
    }

    /// Monotonic counter behind the advisory stamps (deterministic, unlike wall-clock ties).
    private var hostStampCounter: UInt64 = 0

    /// Which document host each tool surface currently belongs to — its (transitive) provenance,
    /// bound by every explicit tool launch. Singletons re-bind last-spawner-wins; value-keyed
    /// tools bind per-instance. Session-scoped, never persisted (owner decision D4).
    var toolProvenance: [ToolWindowID: DocumentHostID] = [:]

    /// A tool-window document selection routed to its provenance host (macOS). The matching host
    /// consumes it via `.onChange` (appends to its navigation path, fronts itself) and clears it.
    var routedBrowse: RoutedBrowse? = nil

    /// Registers a document host as live (called from the host root's `onAppear`).
    func registerHost(_ host: DocumentHostID) {
        hostStampCounter += 1
        liveDocumentHosts[host] = hostStampCounter
        #if DEBUG
        print("[AppState] registerHost \(host) (live: \(liveDocumentHosts.count))")
        #endif
    }

    /// Bumps a host's advisory recency stamp (called when the host window becomes key).
    /// Registers the host as a side effect if a missed `onAppear` left it unknown.
    func hostBecameKey(_ host: DocumentHostID) {
        hostStampCounter += 1
        liveDocumentHosts[host] = hostStampCounter
    }

    /// Removes a closed host from the registry. Its tool bindings are left in place — they fail
    /// the liveness check in `provenance(of:)` and resolve through the fallback chain (D3). An
    /// in-flight `routedBrowse` addressed to the closing host is re-resolved (FM-F's consumption
    /// gap): re-targeted at the fallback host, or — when no host survives — demoted back to
    /// `pendingBrowseDocument`, which the next host to mount drains on appear.
    func unregisterHost(_ host: DocumentHostID) {
        liveDocumentHosts.removeValue(forKey: host)
        #if DEBUG
        print("[AppState] unregisterHost \(host) (live: \(liveDocumentHosts.count))")
        #endif
        if let inFlight = routedBrowse, inFlight.host == host {
            if let survivor = fallbackHost() {
                routedBrowse = RoutedBrowse(host: survivor, entry: inFlight.entry)
            } else {
                routedBrowse = nil
                pendingBrowseDocument = Handoff(target: .macLegacyBrowse, payload: inFlight.entry)
            }
        }
    }

    /// Binds a tool surface to the document host it was launched from — every explicit launch
    /// re-binds (last-spawner-wins). Pass the launcher's own provenance for tool→tool spawns
    /// (transitivity). A `nil` host — an originless launch (Settings/Collections word cloud), or a
    /// transitive spawn whose parent is itself unbound — **CLEARS** the binding, so the tool
    /// resolves through the D3 recency fallback rather than a stale-but-live prior host. (Leaving a
    /// stale binding was the FM-A resurfacing PR-2 review caught: a buried origin A kept stealing
    /// opens from the recency host.) Bare scene keyboard shortcuts run no code, so they never reach
    /// this and correctly leave the existing binding for `provenance(of:)`'s liveness check to age.
    func bindTool(_ tool: ToolWindowID, to host: DocumentHostID?) {
        toolProvenance[tool] = host   // nil removes the key
    }

    /// A tool's provenance host, or `nil` when unbound or the bound host has closed
    /// (delivery-time liveness — a stale binding can never strand a click).
    func provenance(of tool: ToolWindowID) -> DocumentHostID? {
        guard let host = toolProvenance[tool], liveDocumentHosts[host] != nil else { return nil }
        return host
    }

    /// The D3 fallback: the most-recently-key live host, else `nil` (caller mints a standalone
    /// window — a document open must never silently do nothing).
    func fallbackHost() -> DocumentHostID? {
        liveDocumentHosts.max(by: { $0.value < $1.value })?.key
    }

    /// Opens a document in its provenance host (macOS). Tool sources resolve through their
    /// binding, liveness-checked, then the fallback chain; `.global` sources go straight to the
    /// fallback. When no live host exists at all, `mintWindow` runs (callers pass
    /// `openWindow(value: DocumentWindowID(...))`) so the open lands in a fresh standalone window.
    func openDocument(_ entry: DocumentBrowserEntry,
                      from source: DocumentOpenSource,
                      mintWindow: (DocumentBrowserEntry) -> Void) {
        let target: DocumentHostID?
        switch source {
        case .tool(let tool): target = provenance(of: tool) ?? fallbackHost()
        case .global:         target = fallbackHost()
        }
        if let target {
            routedBrowse = RoutedBrowse(host: target, entry: entry)
        } else {
            mintWindow(entry)
        }
    }

    /// Convenience for view-side producers: same resolution as `openDocument(_:from:mintWindow:)`,
    /// with the mint tail wired to the caller's `@Environment(\.openWindow)` — a minted window
    /// carries the entry's FULL display payload (the widened `DocumentWindowID`), so it renders
    /// the same chrome as a routed open.
    func openDocument(_ entry: DocumentBrowserEntry,
                      from source: DocumentOpenSource,
                      using openWindow: OpenWindowAction) {
        openDocument(entry, from: source) { orphan in
            openWindow(value: DocumentWindowID(entry: orphan))
        }
    }

    /// Translates a legacy `pendingBrowseDocument` write (origin-less producer not yet migrated to
    /// `openDocument(_:from:mintWindow:)`) through the fallback chain. Called by EVERY macOS
    /// document host from its `pendingBrowseDocument` observer — the clear-first step makes it
    /// exactly-once no matter how many hosts are open, and having every host run it means the
    /// translation survives even when any particular window is closed. No-op when nothing pending.
    func routeLegacyPendingBrowse(mintWindow: (DocumentBrowserEntry) -> Void) {
        guard let entry = consumeHandoff(\.pendingBrowseDocument, for: .macLegacyBrowse) else { return }
        openDocument(entry, from: .global, mintWindow: mintWindow)
    }

    /// Cross-view hand-off for opening a **volume** in the browser (the volume-grain
    /// sibling of `pendingBrowseDocument`), set by the Cross-Volume Provenance rows
    /// (UI audit gap 12 — they used to be dead ends).
    ///
    /// Set immediately before `openWindow(id: "frus.corpusBrowser")` on macOS —
    /// `CorpusBrowserWindowView` consumes it (`.task` for a freshly created window,
    /// `.onChange` for one already open), selects the volume's subseries, pushes the
    /// volume onto its detail path, and clears it. On iOS `BrowserView` consumes it
    /// via `.onChange` and appends the volume to the Browse tab's path — mirroring
    /// the `pendingBrowseDocument` pattern.
    ///
    /// Scene-addressed (#338 step 4): iOS producers target the producing window's `\.sceneID`; macOS
    /// producers target `.macCorpusBrowser` (the singleton corpus-browser window).
    var pendingBrowseVolume: Handoff<String>? = nil

    /// The page a link was to when it opened its volume's page in Browse because the volume is not on
    /// the device and the bundled page map does not list that page (#1766, `PageLink.volume`).
    ///
    /// Every ``openBrowseVolume(_:from:)`` clears it, and a reader sets it just after its own call,
    /// so only a page link's hand-off carries a page. The volume's page in Browse — `VolumeView` on
    /// iPhone and iPad, the Corpus Browser's volume page on the Mac — names the page in its
    /// not-downloaded state while this names its volume, and clears it when it goes away, so a later
    /// visit to the volume by another way names no page.
    var followedPageLink: FollowedPageLink? = nil

    /// The document currently targeted by the Cross-Reference Graph window.
    ///
    /// Set by the Research rail's Graph tile (`ResearchRailView.openGraph`) immediately before
    /// `openWindow(id: "frus.crossReferenceGraph")` (the titlebar Graph button retired in C2a).
    /// `CrossReferenceGraphWindowView` observes this property to load the correct ego graph. On
    /// macOS the "View Document" button in the graph info panel sets `pendingBrowseDocument`
    /// (routed to the active document window) rather than navigating inline.
    var currentGraphEntry: DocumentBrowserEntry? = nil

    /// Cross-window hand-off into the Cross-Reference Graph window's **volume
    /// connections** mode (UI audit B6): the id of the volume whose corpus-wide
    /// connection graph should be shown.
    ///
    /// `currentGraphEntry` is document-scoped (targeted ego-graph mode); this is its
    /// volume-grain sibling. Set by the Corpus Browser's per-volume graph buttons
    /// immediately before `openWindow(id: "frus.crossReferenceGraph")`.
    /// `CrossReferenceGraphWindowView` consumes it (`.task` for a freshly created
    /// window, `.onChange` for one already open), clears `currentGraphEntry`, jumps
    /// its picker straight to the volume-connections stage, and clears this —
    /// mirroring the `pendingSearch` / `pendingNARALookup` pattern. macOS-only in
    /// practice; iOS shows `VolumeConnectionGraphView` inline in the Browse tab.
    var pendingVolumeGraph: String? = nil

    /// The raw source note of the document currently targeted by the Source Explorer window.
    ///
    /// Set by `MainWindowView` immediately before `openWindow(id: "frus.sourceExplorer")`
    /// is called. `SourceExplorerWindowView` passes this to `MacSourceExplorerView`.
    var currentSourceNote: String? = nil
    /// Year of the FRUS document whose source note is currently displayed in Source Explorer.
    /// Used to route decimal-file citations to the correct NARA period finding-aid page.
    var currentSourceNoteYear: Int? = nil
    /// Document context for the Source Explorer window, used to classify pre-1906 documents
    /// (which carry no source note) into their diplomatic-series rolls. Set alongside
    /// `currentSourceNote` at every open-site; read by the window scenes.
    var currentSourceNoteHeader: String? = nil
    var currentSourceNoteDateline: String? = nil
    var currentSourceNoteVolumeId: String? = nil
    var currentSourceNoteDocumentId: String? = nil

    /// Bumped to a fresh `UUID` by a **deliberate** Source Explorer note open (`openSources`) so the
    /// Source Explorer window snapshots the `currentSourceNote*` sextet into local `@State` at that
    /// moment and thereafter ignores background mutations (#369 BUG-8). Without this focus signal the
    /// window binds the globals *live*, so a *second* document window's `loadDocument()` — which
    /// rewrites the same globals — would flicker the open explorer to a different document's note
    /// (or "No Document Selected"). Mirrors how `pendingNARALookup` is consumed once into local
    /// state rather than read live.
    var sourceNoteFocusID: UUID? = nil

    /// Cross-window hand-off into the Source Explorer window's **NARA Lookup** mode
    /// (UI audit B3): the selected document text a caller wants pre-filled as the
    /// catalog query.
    ///
    /// The **sole** producer is `MacDocumentView.lookUpSelectionInNARA` (the floating
    /// selection bar's "Look Up in NARA" action), which sets this immediately before
    /// `openWindow(id: "frus.sourceExplorer")`. `SourceExplorerWindowView` consumes it
    /// (`.task` for a freshly created window, `.onChange(of: pendingNARALookup)` for one
    /// already open), switches to the NARA Lookup segment with a fresh view identity so
    /// the query field shows the new text, and clears it — mirroring the `pendingSearch` /
    /// `pendingCollectionSelection` pattern. macOS-only in practice; iOS presents
    /// `NARACatalogLookupView` as a local sheet.
    ///
    /// #363: this producer deliberately does NOT also bump `sourceNoteFocusID` — keeping
    /// the NARA and note-focus signals disjoint is what makes the Source Explorer segment
    /// switch deterministic (a shared signal previously raced the note handler back to the
    /// Source Note segment).
    var pendingNARALookup: NARALookupRequest? = nil

    /// `SettingsPane` rawValue to auto-select when the macOS Settings window opens (or is already
    /// open). Set by the Research ▸ Switch Project ▸ "Manage Projects…" command immediately BEFORE
    /// `openSettings()`, then consumed and cleared by `FRUSSettingsView`. Stored as a raw `String`
    /// (not the macOS-only `SettingsPane` type) so `AppState` stays platform-agnostic, mirroring
    /// `pendingVolumeGraph` / `pendingNARALookup`. macOS-only in practice. (#377 Phase 5)
    var pendingSettingsPaneRaw: String? = nil

    // (#363) The research-note composer is now a value-based `WindowGroup(for: NoteComposerRequest.self)`
    // opened via `openWindow(value:)`, so the old `pendingNoteComposer` hand-off field was removed.

    /// `EducationPage.id` to open the Research Guide to directly, or `nil` to
    /// open at the first page.
    ///
    /// Set by contextual entry points (e.g. an info button in the Source
    /// Explorer or document footnote view) immediately before presenting the
    /// guide — `openWindow(value: ResearchGuideWindowID())` on macOS, or presenting
    /// `ResearchGuideView` as a sheet on iOS — so the guide opens pre-scrolled to the
    /// topic the user asked about. `ResearchGuideView` reads and clears it.
    var researchGuideInitialPageId: String? = nil

    /// Incremented each time the full-text index is completely cleared (app reset).
    ///
    /// Observed by `MacSearchWindowView` to discard cached result sets that were
    /// fetched before the reset. Without this, the search window — a persistent
    /// `Window` scene — continues displaying stale rows even though the FTS5 table
    /// is empty, because its `searchTrigger` never changes and no re-query fires.
    var indexGeneration: Int = 0

    // `showCitationLookup` removed in 4.3 — Citation Lookup is a Window scene on
    // macOS (`frus.citationLookup`, UI audit B4) and a local-state sheet on iOS
    // (`SearchView`), so no cross-view flag remains.
    //
    // `showResearchGuide` removed for the same reason (#752 / L-43). It was a Bool on this
    // app-wide object driving a `.sheet(isPresented:)` in `SettingsView`, so on an iPad with
    // several windows open every window's Settings tab was bound to the one flag and all of them
    // would present the guide at once. The audit prescribed converting it to a scene-addressed
    // hand-off; that is the wrong shape. Producer and consumer are **one view tree in one
    // window** — `AboutView` is a `NavigationLink` destination of the very `SettingsView` that
    // presented the sheet — so it never needed to cross a window boundary at all. The flag is now
    // `@State` on `AboutView`, which is scene-local by construction and cannot fan out.

    /// The most recent per-document indexing progress update, or `nil` when no
    /// indexing is in progress.
    ///
    /// Populated by `connectIndexingProgress(pipeline:)` which subscribes to
    /// `IndexingPipeline.progressStream`. Views observe this to render live
    /// indexing indicators (iOS: inline capsule in VolumeRowLabel; macOS: StatusBarView).
    /// It is the one source of indexing progress outside this type: Browse's Index Now and the Mac's
    /// Corpus Browser read it, never the stream, which has one reader.
    ///
    /// Version history:
    ///   1.0 — Session 51: initial implementation (iOS only)
    ///   1.1 — New UI scaffolding: promoted to cross-platform for macOS StatusBarView
    ///   1.2 — 2026-10-20: Browse's Index Now reads it (`BrowserViewModel.updateIndexingProgress(from:)`)
    ///          in place of a second reader of the stream
    var currentIndexingProgress: IndexingProgressUpdate? = nil

    /// The most recent volume metadata snapshot discovered during the parse phase of indexing.
    ///
    /// Populated by `connectIndexingProgress(pipeline:)` which subscribes to
    /// `IndexingPipeline.metadataStream`. Cleared to `nil` when the next indexing
    /// operation begins (i.e. when `currentIndexingProgress` is first set for a new volume).
    /// Views use this to enrich live progress displays with person counts, date coverage,
    /// and cross-reference totals as soon as the XML parse completes.
    ///
    /// Version history:
    ///   1.0 — Session 113: initial implementation
    var lastDiscoveredMetadata: VolumeMetadataDiscovered? = nil

    /// The metadata of the most recently completed indexing pass.
    ///
    /// Set to `lastDiscoveredMetadata` when the pipeline emits `.complete` for a volume.
    /// Cleared to `nil` by `IndexingSummaryCard.onDismiss` (after the 6-second auto-dismiss
    /// or when the user taps an action). Views observe this to render the post-index
    /// summary card.
    ///
    /// Version history:
    ///   1.0 — Session 114: initial implementation
    var completedIndexingMetadata: VolumeMetadataDiscovered? = nil

    /// Volume IDs whose indexing pass started but did not complete before the app was killed.
    ///
    /// Seeded at boot by reading `IndexingStateTracker.interruptedVolumeIds()`.
    /// Cleared per-volume as `connectIndexingProgress` observes `.complete` events.
    /// Views observe this to render amber "needs attention" indicators on affected rows.
    ///
    /// Version history:
    ///   1.0 — Session 115: initial implementation
    var interruptedVolumeIds: Set<String> = []

    /// Cached set of volume IDs that are present in the FTS5 search index.
    ///
    /// Seeded at boot via `seedIndexedVolumeIds(pipeline:)` which runs a single
    /// `SELECT DISTINCT volume_id FROM document_cache` query. Updated incrementally
    /// in `connectIndexingProgress` when a volume's `.complete` event fires, and re-read after
    /// every whole-index pass (`indexAllVolumes(with:)`, #1526), which reports no volume as it
    /// finishes it. Write it through `markVolumeIndexed(_:)`, `markVolumeUnindexed(_:)` and
    /// `clearIndexedVolumeIds()`, so a change made while a re-read is in flight survives it.
    ///
    /// Replaces per-call `IndexingPipeline.isVolumeIndexed()` lookups from view bodies
    /// (which previously fired SQLite queries on every SwiftUI render pass — up to 10×/s
    /// during indexing — saturating the main thread and making the education sheet laggy).
    var indexedVolumeIds: Set<String> = []

    /// What Volumes & Storage last measured and the volume removals in progress (#1356).
    ///
    /// Held here rather than by the hub, because a hub does not outlive the reader leaving it: the
    /// iOS hub is a navigation destination and the Mac hub one arm of the Settings pane switch, so
    /// Back and in again builds a new one. A removal keeps running after its hub is gone, and its
    /// mark and its re-measure have to reach the hub the reader comes back to. See
    /// `DownloadedVolumesListModel`.
    let downloadedVolumes = DownloadedVolumesListModel()

    /// Keeping Current's list: what the last check found changed upstream, and where each listed
    /// volume's update stands (#1660). Held here for the reason `downloadedVolumes` is: an update
    /// keeps running after the hub that started it is gone. See `KeepingCurrentModel`.
    let keepingCurrent = KeepingCurrentModel()

    // MARK: - Live Activity (iOS only)

    #if os(iOS)
    /// What this process asks of ActivityKit, and what it hears back: the system's activities
    /// (`SystemLiveActivityHost`), or a stand-in a unit test sets (#1695). See
    /// `LiveActivityHosting`. `@ObservationIgnored`, like the seven below: no view renders from it.
    @ObservationIgnored
    var liveActivityHost: any LiveActivityHosting = SystemLiveActivityHost()

    /// The id of the activity this process holds for each kind of job; none while that kind is
    /// idle.
    ///
    /// The indexing one follows a whole queue (#1695, plan of record decision 63): asked for, or
    /// taken over, at the queue's first update, updated for each volume in turn, and ended with
    /// the queue (`endIndexingBatch()`). The summarization one follows a run, through
    /// `syncSummarizationLiveActivity()`. The system starts one only while the app is in the
    /// foreground; once started, it takes updates in the background too, so a queue or a run that
    /// goes on there keeps it.
    @ObservationIgnored
    private var heldLiveActivityIDs: [LiveActivityJobKind: String] = [:]

    /// The ids of the activities this process requested or took over, those it has since ended
    /// included (#1642). An activity whose id is not here was left by an earlier process.
    @ObservationIgnored
    private var drivenLiveActivityIDs: Set<String> = []

    /// The ids of the activities this process has asked the system to end: its own as each queue
    /// or run ends, and the leftovers it sweeps (#1642). The end is not instant, and until it
    /// lands the system still lists the activity as live: a run that starts in that moment must
    /// not take over one that is about to go (#1695).
    @ObservationIgnored
    private var endedLiveActivityIDs: Set<String> = []

    /// Whether this process may ask the system for an activity: not again in a background run
    /// once the system has refused one in it (#1695). See `LiveActivityLifecycle.RequestGate`.
    @ObservationIgnored
    private var liveActivityRequests = LiveActivityLifecycle.RequestGate()

    /// The state last sent to each activity this process holds, for the keep-alive to send again.
    /// Written at every progress update, up to ten times a second.
    @ObservationIgnored
    private var lastLiveActivityStates: [LiveActivityJobKind: IndexingActivityAttributes.ContentState] = [:]

    /// The keep-alive: it sends each held activity its last state again, with a new stale date,
    /// for as long as this process holds one. See `keepLiveActivitiesFresh()`.
    @ObservationIgnored
    private var liveActivityKeepAlive: Task<Void, Never>?

    /// How many of this launch's own index passes have been started and have not finished: the
    /// whole-library pass, the rebuild from the cache, and the pass over volumes left unindexed.
    /// See `launchIndexPassWillBegin()`.
    @ObservationIgnored
    private var launchIndexPassesInFlight = 0
    #endif

    // MARK: - Queue tracking (Session 116)

    /// The indexing queue currently in flight, if any.
    ///
    /// **Queue-grained, deliberately.** The per-volume signal
    /// (``currentIndexingProgress``) goes `nil` between volumes, so a banner keyed on it
    /// flashed in and out once per volume — the user sees a strobe rather than a state.
    /// What a researcher actually needs to know is *when everything they downloaded is
    /// ready*, which is a property of the queue, not of whichever volume happens to be
    /// parsing. This value is created when indexing starts and survives until the backlog
    /// is empty.
    var indexingBatch: IndexingBatch?

    /// Volumes whose download has landed and whose pass has not yet finished (#1757).
    ///
    /// The queue counts them from here because neither of its other lists holds them for certain.
    /// Such a volume has left the download queue, and the backlog leaves out every volume with
    /// rows in the index, which a pass under way has begun to write and a re-download or an update
    /// keeps from before. Four transfers run at once by default, so several volumes can land and
    /// leave the download queue before the first progress update opens a queue: measured on an
    /// iPhone 17 simulator, six volumes of a 27-volume download were indexing before the first
    /// finished. A volume leaves this set when its pass ends, and the set empties with the queue.
    @ObservationIgnored
    private var landedVolumeIdsAwaitingIndex: Set<String> = []

    /// Counts each of `volumeIds` among the queue's volumes, when a queue is in flight (#1757),
    /// and shows a new total on the queue's Live Activity at once.
    private func countInIndexingBatch(_ volumeIds: some Sequence<String>) {
        guard var batch = indexingBatch else { return }
        guard batch.count(volumeIds) else { return }
        indexingBatch = batch
        #if os(iOS)
        refreshIndexingLiveActivityQueue()
        #endif
    }

    /// A download has ended (#1757). One that landed is counted among the queue's volumes until
    /// its pass finishes, since `onVolumeDownloaded` indexes every download that lands; one
    /// cancelled or failed for good leaves the queue, so the banner's total does not wait for a
    /// volume that will never come. `DownloadManager`'s `onTransferFinished` calls this, once for
    /// each transfer.
    func indexingQueueTransferDidFinish(_ volumeId: String, outcome: DownloadTransferOutcome) {
        switch outcome {
        case .succeeded:
            landedVolumeIdsAwaitingIndex.insert(volumeId)
            countInIndexingBatch([volumeId])
        case .cancelled, .failed:
            guard var batch = indexingBatch else { return }
            guard batch.uncount(volumeId) else { return }
            indexingBatch = batch
            #if os(iOS)
            refreshIndexingLiveActivityQueue()
            #endif
        }
    }

    /// Bumped after any review write to `document_revisions` or to a highlight's
    /// `renderingVersion` (R-5 P3), so the three P2 readers — the document twins' `revision`,
    /// `ResearchView`'s unreviewed set, the storage hubs' section — reload without a re-index.
    /// A counter rather than a payload: every reader re-reads the whole set anyway.
    var revisionReviewToken: Int = 0

    /// A Summarize Again that failed after its sheet was dismissed, for the document twins to show.
    ///
    /// The review sheet's Summarize Again spawns a task that outlives the sheet, and the sheet is
    /// freely dismissible while it runs — `SummarizationService`'s own doc records a document at
    /// 131 chunks and "many minutes". Success already survives that, because the sheet signals it
    /// by bumping `revisionReviewToken` on this object; failure was written into the sheet's own
    /// `@State` and reached nobody. This is the other half of that asymmetry, and it mirrors the
    /// shipped precedent: `DocumentView.regenerate` stores its error on the view model precisely
    /// because "this task outlives a dismissed rail sheet by design".
    ///
    /// Carries the document it belongs to, so a failure cannot surface on a document the reader
    /// navigated to afterwards. Cleared by whichever twin shows it.
    var summarizeAgainFailure: SummarizeAgainFailure?

    /// A failed Summarize Again, addressed to one document.
    ///
    /// A struct rather than a tuple because the twins watch it with `onChange`, which needs
    /// `Equatable`; and it carries `id` so that the SAME error twice in a row is still two
    /// events — without it the second failure of a repeated attempt would not fire the handler.
    struct SummarizeAgainFailure: Equatable {
        /// The volume of the document the failed run belonged to.
        let volumeId: String
        /// The document the failed run belonged to.
        let documentId: String
        /// What to show the reader.
        let message: String
        /// Makes two identical failures distinct events.
        let id = UUID()
    }

    /// Volumes made searchable by the queue that just finished, when it held more than
    /// one — the summary card's queue-grain line. `nil` for a single-volume queue, whose
    /// per-volume card already says everything true about it.
    var completedIndexingBatchVolumeCount: Int?

    /// Ends a queue that has stopped making progress.
    ///
    /// The backlog is the queue's authority for when it is finished, and a volume that
    /// cannot be indexed — a truncated download, a parse failure — stays in that backlog
    /// forever. Without a watchdog the banner would be pinned to the screen for the rest
    /// of the session, telling the user their library is still being prepared while
    /// nothing at all is running.
    private var indexingBatchWatchdog: Task<Void, Never>?

    /// Rolling mean throughput across completed volumes in the current batch (docs/s).
    ///
    /// Updated on each `.complete` event. Used by `IndexingQueueBannerView` to estimate
    /// ETA for remaining queued volumes.
    var indexingQueueAverageDocsPerSecond: Double = 0

    /// Rolling mean document count across completed volumes in the current batch.
    ///
    /// Falls back to 600 (approximate corpus mean) until at least one volume completes.
    var indexingQueueAverageDocumentCount: Int = 600

    /// The current volume's position within a multi-volume queue.
    ///
    /// Returns `nil` for a single-volume queue and when nothing is queued. `current` is
    /// 1-based. Drives `IndexingQueueBannerView`.
    ///
    /// Reads the queue, not the volume: it stays non-nil through the gaps between
    /// volumes, which is what stops the banner strobing once per volume.
    ///
    /// Version history:
    ///   1.0 — Session 116: initial implementation
    ///   2.0 — queue-grained: derived from ``indexingBatch`` rather than from
    ///         `currentIndexingProgress` plus two loose counters
    var indexingQueuePosition: (current: Int, total: Int)? {
        guard let batch = indexingBatch, batch.total >= 2 else { return nil }
        return (current: min(batch.completed + 1, batch.total), total: batch.total)
    }

    /// Re-reads the real backlog and either counts what it holds or ends the queue.
    ///
    /// The download queue only describes a queue whose downloads are still in flight. When the
    /// downloads finished first — a subseries on a fast connection — there is nothing left in it
    /// while dozens of volumes wait on disk, which is what hid the queue banner (#541).
    /// `unindexedDownloadedVolumeIds()` is the authoritative answer for those, and is what the
    /// background indexing pass already uses to decide its own work. Each volume it lists is
    /// counted once, as every other list the queue reads is (`IndexingBatch.count(_:)`, #1757).
    ///
    /// - Parameter mayEnd: `true` after a volume completes, when an empty backlog means
    ///   the whole queue is done. `false` at queue start, where an empty result could only
    ///   be a race with the volume that is indexing right now.
    ///
    /// Runs off the main actor (`IndexingPipeline` is an actor) and only ever raises the
    /// total, so a slow query cannot retract a count the banner is already showing.
    /// A total it raises reaches the queue's Live Activity at once
    /// (`refreshIndexingLiveActivityQueue()`): with no next volume under way, nothing else would
    /// carry it there.
    private func syncIndexingBatchWithBacklog(mayEnd: Bool) {
        guard let pipeline = indexingPipeline else {
            // Nothing can answer "is there more?", so ending on the volume that just
            // finished beats leaving a banner up with nothing driving it.
            if mayEnd { endIndexingBatch() }
            return
        }
        Task { @MainActor [weak self] in
            let found = try? await pipeline.unindexedDownloadedVolumeIds()
            guard let self, let batch = self.indexingBatch else { return }
            guard let found else {
                // A transient failure: the next volume asks again. With no next volume, nothing
                // else would end the queue, and since #1695 its Live Activity ends with it, so the
                // stall timeout does once the queue has been quiet that long.
                if mayEnd {
                    self.armIndexingBatchWatchdog(generation: batch.generation,
                                                  seconds: Self.indexingBatchStallTimeout)
                }
                return
            }
            // A volume whose pass failed in this queue stays unindexed, and nothing here will
            // index it: waiting for it would hold the queue until the stall timeout (#1695).
            let backlog = found.filter { !batch.failedVolumeIds.contains($0) }
            if mayEnd, backlog.isEmpty {
                // Deliberately does NOT end here.
                //
                // `unindexedDownloadedVolumeIds()` subtracts every volume that has rows in
                // `document_cache` — and a volume that is halfway through storing already
                // has rows. When downloads drive indexing (`onVolumeDownloaded` spawns an
                // unstructured Task per completed download, uncapped) several volumes are
                // storing at once, so this query can come back empty while real work is
                // still in flight. Ending the queue on that reading tore the banner and its
                // cloud down and rebuilt them once per volume — which is what the owner saw
                // as the frame probe resetting on every volume, since a rebuilt backdrop
                // gets fresh @State.
                //
                // So an empty backlog only *starts a countdown*. Any progress at all bumps
                // the generation and makes it inert, which is the property this needs: the
                // question "is anything still happening?" is answered by watching, not by
                // asking a table that cannot distinguish started from finished.
                self.armIndexingBatchWatchdog(generation: batch.generation,
                                              seconds: Self.indexingBatchSettleSeconds)
            } else {
                // Counted, never replaced: the backlog shrinks as volumes are indexed, and the
                // cloud's scope must describe the queue the user started, not what is left of it.
                // A volume the queue has already met — still listed as downloading when its file
                // landed, or the one indexing now — is not counted again (#1757). The backlog is
                // sorted, so volumes met here join in a stable order.
                self.countInIndexingBatch(backlog)
                if mayEnd {
                    self.armIndexingBatchWatchdog(generation: batch.generation,
                                                  seconds: Self.indexingBatchStallTimeout)
                }
            }
        }
    }

    /// Tears the queue down, ends its Live Activity, and hands the summary card its queue-grain
    /// count.
    private func endIndexingBatch() {
        indexingBatchWatchdog?.cancel()
        indexingBatchWatchdog = nil
        // A volume still listed here never reported its pass: nothing will, in this queue (#1757).
        landedVolumeIdsAwaitingIndex.removeAll()
        #if os(iOS)
        // The one activity the queue had ends with it (#1695, plan of record decision 63).
        endIndexingLiveActivity()
        #endif
        guard let batch = indexingBatch else { return }
        completedIndexingBatchVolumeCount = batch.completed > 1 ? batch.completed : nil
        indexingBatch = nil
        corpusSettled()
    }

    /// The one place an indexing-driven corpus change reaches ``refreshAfterCorpusChange(context:)``
    /// (R-1d).
    ///
    /// ## Why here, and not at the download
    /// `refreshAfterCorpusChange` had 16 call sites and **all of them were in the two storage hubs**.
    /// No download path called it, so a downloaded or corrected volume's people stayed invisible and
    /// its read-only stores stale until the next launch. There is no per-call-site fix worth having:
    /// many `enqueueDownload` calls across the app produce a download, and `enqueueDownload` merely
    /// *enqueues* — a refresh beside one runs before the transfer, let alone before the re-index, and
    /// would be a call that looks right and does nothing.
    ///
    /// Every completion reaches this teardown instead, which runs only once the watchdog has seen the
    /// batch generation unchanged with no indexing in flight.
    ///
    /// ## Why batched rather than per volume
    /// `refreshAfterCorpusChange` reopens three SQLite connections, rebuilds the citation engine,
    /// rescans the volumes directory and runs the person-rollup drift check — which on a drifted
    /// corpus is a full re-cluster of the `persons` table. A per-volume call would run that once per
    /// volume during a corpus download. Every bulk path in the hubs already calls it once after its
    /// loop; this is the same convention, applied to the path that had none.
    private func corpusSettled() {
        guard let container = modelContainer else {
            // Never the full refresh without a context. `PersonRollupRefresh.afterCorpusChange`
            // would snapshot NO overrides and stamp the empty-set fingerprint, rebuilding a rollup
            // that ignores the reader's merges until something passes a real context. The override
            // ROWS survive either way — only the materialised rollup goes wrong — but a stale rollup
            // is the smaller wrong answer than a confidently wrong one.
            refreshReadOnlyStores()
            return
        }
        refreshAfterCorpusChange(context: container.mainContext)
    }

    /// Arms the stall timeout described on ``indexingBatchWatchdog``.
    ///
    /// Keyed on the queue's generation, so any real progress in the interim — including
    /// the `.optimizing` stage, which is reported like any other — makes the pending
    /// timeout inert without needing to cancel it.
    ///
    /// Called with ``indexingBatchSettleSeconds`` when the backlog says the queue is done
    /// and with ``indexingBatchStallTimeout`` when it says work remains; the difference is
    /// only how much quiet is required before believing it.
    ///
    /// **A pending download is not a stall.** Indexing routinely catches up with a slow
    /// connection and then sits idle waiting for the next file to land, which on cellular
    /// can be minutes. Tearing the queue down there would re-create the strobe at a slower
    /// cadence, and would be wrong on the merits: the user's volumes are not ready yet.
    /// So while `downloadQueue` is non-empty the watchdog re-arms instead of firing.
    private func armIndexingBatchWatchdog(generation: Int, seconds: Double) {
        indexingBatchWatchdog?.cancel()
        indexingBatchWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, let batch = self.indexingBatch else { return }
            guard batch.generation == generation, self.currentIndexingProgress == nil else { return }
            guard self.downloadQueue.isEmpty else {
                self.armIndexingBatchWatchdog(generation: generation, seconds: seconds)
                return
            }
            self.endIndexingBatch()
        }
    }

    /// Seconds of quiet required after an empty backlog before the queue is called done.
    ///
    /// Short, because by this point the evidence already points at "finished" — this only
    /// has to outlast the window in which a concurrently-storing volume looks indexed to
    /// `unindexedDownloadedVolumeIds()` but has not yet emitted its next progress update.
    static var indexingBatchSettleSeconds: Double = 2

    /// Seconds with nothing reported at all — no progress, no new volume — before a queue
    /// is presumed finished and torn down.
    ///
    /// The backlog is the queue's primary end condition; this is the backstop for a volume
    /// that can never be indexed and so never leaves it, and for a manual reindex of one
    /// volume while other unindexed volumes happen to sit on disk. Long enough that the
    /// ordinary gap between two volumes — an FTS5 write, sometimes an `optimize()` — can
    /// never trip it, short enough that a finished queue does not linger.
    ///
    /// `var` so `IndexingBatchLifecycleTests` can shorten it; main-actor-isolated, like
    /// everything else on `AppState`, so there is nothing to race.
    static var indexingBatchStallTimeout: Double = 15

    /// Volume titles for the volumes currently waiting in the download queue, in order.
    ///
    /// Resolved from `manifestStore`; falls back to `volumeId` when the manifest has no entry.
    /// Used by `MainTabView` and `SupportingViews`' indexing banner. (Was documented as
    /// `IndexingQueueBannerView`, which no longer references it — corrected 2026-08-15.)
    ///
    /// Version history:
    ///   1.0 — Session 116: initial implementation
    var indexingQueueVolumeTitles: [String] {
        downloadQueue.map { manifestStore.entry(forVolumeId: $0)?.title ?? $0 }
    }

    /// Populates `indexedVolumeIds` from the database in a background task.
    ///
    /// Runs a single `SELECT DISTINCT volume_id FROM document_cache` query so subsequent
    /// per-volume checks use an O(1) Set lookup instead of per-call SQLite queries from
    /// the SwiftUI render loop. Boot calls this once, after the pipeline is created; a whole-index
    /// pass re-reads through ``reseedIndexedVolumeIds(pipeline:)`` instead, which it awaits.
    func seedIndexedVolumeIds(pipeline: IndexingPipeline) {
        Task { await reseedIndexedVolumeIds(pipeline: pipeline) }
    }

    // MARK: - The indexed-volume set across whole-index passes (#1526)

    /// One change made to ``indexedVolumeIds`` while a re-read of the index was in flight.
    ///
    /// Version history:
    ///   1.0 — #1526: initial implementation
    private enum IndexedVolumeEdit {
        /// A volume finished indexing.
        case indexed(String)
        /// A volume's index rows were deleted.
        case unindexed(String)
        /// The whole index was wiped.
        case cleared
    }

    /// The edits made since the oldest re-read in flight began. Emptied when the last one lands.
    private var indexedVolumeEdits: [IndexedVolumeEdit] = []
    /// How many re-reads of the index are in flight.
    private var indexedVolumeReadsInFlight = 0

    /// Runs a whole-index pass, then re-reads which volumes the index holds (#1526).
    ///
    /// `indexAllVolumes()` reports no volume as it finishes it — only one `.complete` with an EMPTY
    /// volume id at the very end — so the per-volume inserts in ``connectIndexingProgress(pipeline:)``
    /// never see the volumes it indexed. Settings ▸ Rebuild Index empties the set first, so until a
    /// relaunch every reader of the set (Add Documents, working corpora, the Browse-tab badge, the
    /// Mac Search window's saved-search run records) saw nothing indexed. This is the only call
    /// site of `indexAllVolumes()` in the app. `IndexedVolumeSetTests` fails on a bare call anywhere
    /// else — but it does not scan this file or `IndexingPipeline.swift`, so a second call in
    /// either is the reviewer's to catch; and its write scan finds only writes spelled
    /// `appState.indexedVolumeIds`, so one inside this file, or through another name, is not seen.
    ///
    /// Errors are swallowed as every caller did before: a pass that fails part-way has still
    /// indexed what it indexed, and the re-read says which.
    func indexAllVolumes(with pipeline: IndexingPipeline) async {
        try? await pipeline.indexAllVolumes()
        await reseedIndexedVolumeIds(pipeline: pipeline)
    }

    /// Settings ▸ Rebuild Index: wipes the search index, rebuilds it from every downloaded volume,
    /// and re-reads which volumes it now holds. Both hubs call this.
    ///
    /// - Returns: `false` when the wipe failed. Nothing is re-indexed then, because re-indexing on
    ///   top of a partially deleted index is worse than stopping.
    func rebuildSearchIndex(pipeline: IndexingPipeline) async -> Bool {
        do {
            try await pipeline.removeAllVolumesFromIndex()
        } catch {
            return false
        }
        clearIndexedVolumeIds()
        await indexAllVolumes(with: pipeline)
        return true
    }

    /// Re-reads ``indexedVolumeIds`` from the index and waits for it to land.
    func reseedIndexedVolumeIds(pipeline: IndexingPipeline) async {
        await reseedIndexedVolumeIds(reading: { try? pipeline.allIndexedVolumeIds() })
    }

    /// Replaces ``indexedVolumeIds`` with what `read` finds, keeping every change made while it
    /// read.
    ///
    /// The read runs off the main actor, and a volume can finish indexing — or be removed — while
    /// it does. Assigning its answer as it stands would drop that change: a volume indexed during
    /// the read would read *not indexed* until a relaunch, which is #1526's defect again in a
    /// narrower window. So every change made through ``markVolumeIndexed(_:)``,
    /// ``markVolumeUnindexed(_:)`` or ``clearIndexedVolumeIds()`` while a read is in flight is
    /// journalled, and replayed over the read's answer.
    ///
    /// - Parameter read: Returns the ids the index holds, or `nil` when it could not be read, in
    ///   which case the set is left as it is. An empty id is never stored.
    func reseedIndexedVolumeIds(reading read: @escaping @Sendable () async -> Set<String>?) async {
        let firstEdit = indexedVolumeEdits.count
        indexedVolumeReadsInFlight += 1
        defer {
            indexedVolumeReadsInFlight -= 1
            if indexedVolumeReadsInFlight == 0 { indexedVolumeEdits.removeAll() }
        }
        let found = await Task.detached(priority: .utility) { await read() }.value
        guard var ids = found else { return }
        for edit in indexedVolumeEdits[firstEdit...] {
            switch edit {
            case .indexed(let volumeId): ids.insert(volumeId)
            case .unindexed(let volumeId): ids.remove(volumeId)
            case .cleared: ids.removeAll()
            }
        }
        ids.remove("")
        indexedVolumeIds = ids
        #if os(iOS)
        refreshUnindexedVolumeCount()
        #endif
    }

    /// Records that `volumeId` finished indexing. An empty id — the end-of-pass signal of a
    /// whole-index pass, which names no volume — is ignored.
    func markVolumeIndexed(_ volumeId: String) {
        guard !volumeId.isEmpty else { return }
        indexedVolumeIds.insert(volumeId)
        if indexedVolumeReadsInFlight > 0 { indexedVolumeEdits.append(.indexed(volumeId)) }
    }

    /// Records that `volumeId`'s index rows were deleted.
    func markVolumeUnindexed(_ volumeId: String) {
        indexedVolumeIds.remove(volumeId)
        if indexedVolumeReadsInFlight > 0 { indexedVolumeEdits.append(.unindexed(volumeId)) }
    }

    /// Records that the whole index was wiped.
    func clearIndexedVolumeIds() {
        indexedVolumeIds = []
        if indexedVolumeReadsInFlight > 0 { indexedVolumeEdits.append(.cleared) }
    }

    /// Subscribes to `pipeline.progressStream` and `pipeline.metadataStream`, forwarding
    /// updates onto the main actor as `currentIndexingProgress`, `lastDiscoveredMetadata`,
    /// and `completedIndexingMetadata`.
    ///
    /// **The app's one reader of both streams: call it once for a pipeline.** An `AsyncStream` hands
    /// each element to ONE of the readers waiting on it, so a second reader takes updates this loop
    /// never sees, and cancelling a reader while it waits ends the stream for every reader. A second
    /// call here would be such a reader, since nothing stops the first loop. Until 2026-10-20 this
    /// comment called the method safe to call again, and Browse's Index Now read `progressStream` in
    /// a task it cancelled: that cut this loop off for the rest of the launch. Anything else that
    /// shows indexing progress reads `currentIndexingProgress`, as the Mac's Corpus Browser and,
    /// since then, Index Now do; `IndexNowProgressReaderTests` fails on a second reader in the app.
    func connectIndexingProgress(pipeline: IndexingPipeline) {
        Task { @MainActor [weak self] in
            // Clock-based throttle: forward at most ~10 UI updates per second.
            // Stage transitions (.optimizing) and new-volume transitions always pass through
            // immediately so the UI never shows stale volume context.
            var lastForwardedAt = Date.distantPast
            for await update in pipeline.progressStream {
                guard let self else { return }
                if update.stage == .complete {
                    self.completedIndexingMetadata = self.lastDiscoveredMetadata
                    self.currentIndexingProgress = nil
                    self.interruptedVolumeIds.remove(update.volumeId)
                    // A whole-index pass ends with a `.complete` naming no volume; that is not an
                    // id to store (#1526). Its volumes reach the set through the re-read the pass
                    // runs after it (`indexAllVolumes(with:)`).
                    self.markVolumeIndexed(update.volumeId)
                    #if os(iOS)
                    // The Browse-tab badge counts downloaded-but-unindexed volumes, and one
                    // just left that set.
                    self.refreshUnindexedVolumeCount()
                    #endif
                    // The citation engine is not told: it reads the volumes directory and
                    // the index at each lookup, so the "download this volume, then resolve
                    // again" loop CitationLookupView and Add Documents advertise needs no
                    // notice (#1522; a notice sent here, and only here, left a download
                    // waiting for its pass offered for download).
                    self.landedVolumeIdsAwaitingIndex.remove(update.volumeId)
                    if var batch = self.indexingBatch {
                        batch.completed += 1
                        batch.completedVolumeIds.insert(update.volumeId)
                        batch.total = max(batch.total, batch.completed)
                        batch.generation += 1
                        self.indexingBatch = batch
                    }
                    let completedInBatch = Double(max(1, self.indexingBatch?.completed ?? 1))
                    // Update rolling throughput average (Welford online mean).
                    if update.docsPerSecond > 0 {
                        self.indexingQueueAverageDocsPerSecond +=
                            (update.docsPerSecond - self.indexingQueueAverageDocsPerSecond) / completedInBatch
                    }
                    // Update rolling document-count average.
                    if let meta = self.completedIndexingMetadata, meta.totalDocuments > 0 {
                        self.indexingQueueAverageDocumentCount = Int(
                            Double(self.indexingQueueAverageDocumentCount) +
                            (Double(meta.totalDocuments) - Double(self.indexingQueueAverageDocumentCount)) / completedInBatch
                        )
                    }
                    // Is the whole queue done, or is there more on disk waiting? Only the
                    // backlog knows, and only it may end the queue.
                    self.syncIndexingBatchWithBacklog(mayEnd: true)
                    // The index content just changed. Flush the word-cloud service's
                    // in-memory result cache — unlike its disk cache, the in-memory
                    // key carries no index fingerprint, so without this an empty
                    // result computed before the volume was indexed (e.g. opening a
                    // downloaded-but-unindexed volume's cloud) would keep serving
                    // "No Terms" for the rest of the session.
                    if let wordFrequencyService = self.wordFrequencyService {
                        Task { await wordFrequencyService.invalidateCache() }
                    }
                    // The index content just changed. Flush Corpus Analytics'
                    // in-memory result caches — their keys are bare query terms
                    // with no index fingerprint, so a count computed before this
                    // volume was indexed would keep serving stale (or empty)
                    // charts for the rest of the session.
                    if let analyticsService = self.analyticsService {
                        Task { await analyticsService.invalidateCache() }
                    }
                    #if os(iOS)
                    // Not ended here: one activity follows the whole queue (#1695, plan of record
                    // decision 63), and the queue's end ends it (`endIndexingBatch()`). Until the
                    // next volume's first update it shows this one finished.
                    self.syncIndexingLiveActivity(update: update)
                    // Nothing is queued here any more. The background word-cloud precompute this
                    // site fed was removed: it ran NLTagger over the corpus at 97% CPU until iOS
                    // terminated the app, and an entry it managed to write was invalidated by the
                    // next volume indexed — which is to say, by the very event this call sits in.
                    #endif
                } else if update.stage == .failed {
                    // A pass that threw (#1695). No `.complete` follows it, and only a `.complete`
                    // cleared the progress the banner and the Live Activity show, which the
                    // queue's watchdog waits for: both went on showing the volume as under way for
                    // as long as the app ran. The volume is still unindexed and in the backlog,
                    // where nothing in this queue will index it, so the queue leaves it out of what
                    // it waits for, goes on to the next volume if there is one, and ends if not.
                    self.currentIndexingProgress = nil
                    self.landedVolumeIdsAwaitingIndex.remove(update.volumeId)
                    if var batch = self.indexingBatch {
                        batch.failedVolumeIds.insert(update.volumeId)
                        batch.generation += 1
                        self.indexingBatch = batch
                    }
                    self.syncIndexingBatchWithBacklog(mayEnd: true)
                } else {
                    let isNewVolume = self.currentIndexingProgress?.volumeId != update.volumeId
                    let isStageTransition = update.stage == .optimizing
                    let elapsed = Date().timeIntervalSince(lastForwardedAt)
                    guard isNewVolume || isStageTransition || elapsed >= 0.1 else { continue }
                    lastForwardedAt = Date()
                    if isNewVolume {
                        self.lastDiscoveredMetadata = nil
                    }
                    if var batch = self.indexingBatch {
                        // A queue already in flight simply advances. There is no
                        // idle-gap heuristic any more: #541 fixed one wrong reading of
                        // "is this a new batch?" (`downloadQueue.isEmpty`, which is true
                        // at every transition once downloads outpace indexing) and a
                        // 30-second timer was only ever a second guess at the same
                        // question. The queue's own presence is the answer.
                        batch.latest = update
                        batch.generation += 1
                        // A volume indexed again is no longer one this queue gave up on.
                        batch.failedVolumeIds.remove(update.volumeId)
                        self.indexingBatch = batch
                    } else {
                        // A new queue, counting what is queued to download, what has landed
                        // and waits for its pass, and the volume that opened it, each once
                        // (#1757): until then this was the download queue's length plus one,
                        // which counted the opening volume twice while it was still listed
                        // there. The backlog query below counts what waits on disk.
                        var batch = IndexingBatch(total: 0, completed: 0, latest: update, volumeIds: [])
                        batch.count(self.downloadQueue + self.landedVolumeIdsAwaitingIndex.sorted()
                                    + [update.volumeId])
                        self.indexingBatch = batch
                        self.completedIndexingBatchVolumeCount = nil
                        self.indexingQueueAverageDocsPerSecond = 0
                        self.indexingQueueAverageDocumentCount = 600
                        self.syncIndexingBatchWithBacklog(mayEnd: false)
                    }
                    self.currentIndexingProgress = update
                    #if os(iOS)
                    self.syncIndexingLiveActivity(update: update)
                    #endif
                }
            }
        }
        Task { @MainActor [weak self] in
            for await meta in pipeline.metadataStream {
                guard let self else { return }
                self.lastDiscoveredMetadata = meta
            }
        }
    }

    // MARK: - Live Activity management (iOS only)

    #if os(iOS)
    /// Shows `update` on the indexing queue's Live Activity, starting the activity at the queue's
    /// first update.
    ///
    /// **One activity follows the whole queue** (#1695, plan of record decision 63). It is asked
    /// for at the queue's first update, updated for each volume in turn, shown each volume finished
    /// as its `.complete` arrives, and ended with the queue (`endIndexingBatch()`), so a queue that
    /// goes on in the background keeps it. Until #1695 it was ended as each volume finished, and a
    /// volume that started within the three seconds that activity lingered took the ended one over
    /// and showed nothing: measured on 2026-10-12 (iPhone 17 simulator, iOS 27.0), of three
    /// volumes in one launch pass the first and third had an activity and the second none.
    ///
    /// `heldLiveActivityIDs` is in memory only, so after a relaunch this process holds nothing
    /// while an activity may still be on the Lock Screen. With none held it takes over a live one
    /// of its kind before asking for one (`LiveActivityLifecycle.activityToTakeOver(_:among:ended:)`):
    /// that is how a pass a launch resumes keeps the activity the last process left (#1642). An
    /// activity no pass takes over is ended by `endLeftoverLiveActivities()`.
    ///
    /// Every update carries a stale date (`LiveActivityLifecycle.staleDate(after:)`), and the
    /// keep-alive sends the last one again while this process holds the activity, so the date
    /// passes only when the app has stopped running.
    ///
    /// Checks `SettingsKeys.liveActivityEnabled` (default on, Session 154) before
    /// requesting or updating an activity; when the user has turned the preference
    /// off, any already-running activity is ended instead.
    private func syncIndexingLiveActivity(update: IndexingProgressUpdate) {
        guard liveActivityHost.mayShow else { return }
        let liveActivityEnabled = (UserDefaults.standard.object(forKey: SettingsKeys.liveActivityEnabled) as? Bool) ?? true
        guard liveActivityEnabled else {
            endIndexingLiveActivity()
            return
        }
        let finished = update.stage == .complete
        // The `.complete` of a whole-library pass names no volume: there is nothing new to show,
        // and the queue's end follows within seconds.
        if finished && update.volumeId.isEmpty { return }
        lastIndexingLiveActivityUpdate = update
        // A finished volume is shown on the activity the queue holds, and starts none: a queue
        // that holds none by then is one whose request the system refused.
        showLiveActivity(indexingLiveActivityState(for: update), startingOne: !finished)
    }

    /// What the indexing queue's Live Activity shows for `update`, with the queue's count as it
    /// stands now.
    private func indexingLiveActivityState(for update: IndexingProgressUpdate) -> IndexingActivityAttributes.ContentState {
        // A finished volume counts among the queue's volumes done; one under way is the next.
        let queue = update.stage == .complete
            ? indexingBatch.flatMap { $0.total >= 2 ? (current: $0.completed, total: $0.total) : nil }
            : indexingQueuePosition
        return LiveActivityLifecycle.indexingState(
            for: update,
            catalogueTitle: manifestStore.entry(forVolumeId: update.volumeId)?.title,
            queue: queue
        )
    }

    /// The update the indexing queue's Live Activity last showed, kept so that a new count can be
    /// shown on it again (`refreshIndexingLiveActivityQueue()`, #1757). Cleared with the activity.
    @ObservationIgnored
    private var lastIndexingLiveActivityUpdate: IndexingProgressUpdate?

    /// Shows the queue's count on its Live Activity again, after the count changed with no progress
    /// update to carry it (#1757): a download queued, landed, cancelled or failed while the queue
    /// waits between two volumes, or the backlog read after a volume finished.
    ///
    /// Until then the activity took a new count only with the next volume's first update, and a
    /// queue waiting on a slow download sends none for minutes, so the banner and the activity
    /// could name different totals. It sends only to an activity the queue holds, and starts none.
    private func refreshIndexingLiveActivityQueue() {
        guard heldLiveActivityIDs[.indexing] != nil, let update = lastIndexingLiveActivityUpdate else { return }
        showLiveActivity(indexingLiveActivityState(for: update), startingOne: false)
    }

    /// Ends the indexing queue's Live Activity, which lingers `LiveActivityLifecycle.lingerAfterEnd`
    /// seconds so the queue's last state is seen before it goes.
    private func endIndexingLiveActivity() {
        lastIndexingLiveActivityUpdate = nil
        endLiveActivity(.indexing)
    }

    /// Sends `state` to the activity this process holds for its kind. With none held, and where
    /// `startingOne`, it takes over a live one of that kind or asks the system for one.
    ///
    /// A request the system refuses in a background run is not made again in that run
    /// (`LiveActivityLifecycle.RequestGate`, #1695): the system starts no activity for an app in
    /// the background, and this was asked again at every progress update, up to ten times a second.
    private func showLiveActivity(_ state: IndexingActivityAttributes.ContentState, startingOne: Bool = true) {
        let kind = state.resolvedKind
        if let held = heldLiveActivityIDs[kind] {
            sendLiveActivityState(state, to: held)
            return
        }
        guard startingOne else { return }
        if let existing = LiveActivityLifecycle.activityToTakeOver(
            kind, among: liveActivityHost.listedActivities(), ended: endedLiveActivityIDs) {
            heldLiveActivityIDs[kind] = existing
            drivenLiveActivityIDs.insert(existing)
            sendLiveActivityState(state, to: existing)
            return
        }
        guard liveActivityRequests.mayRequest(inForeground: liveActivityHost.isInForeground) else { return }
        guard let requested = liveActivityHost.request(showing: state) else {
            liveActivityRequests.noteRefusal(inForeground: liveActivityHost.isInForeground)
            return
        }
        heldLiveActivityIDs[kind] = requested
        drivenLiveActivityIDs.insert(requested)
        lastLiveActivityStates[kind] = state
        keepLiveActivitiesFresh()
    }

    /// The reader's **Show Indexing Live Activity** switch has changed (#1695). Off ends every
    /// activity this process holds at once, where it had waited for the next progress update: one
    /// activity follows a whole queue, and a queue waiting between two volumes for a download may
    /// send none for minutes. On starts nothing; the next update asks for one. Settings calls this.
    func liveActivitySwitchDidChange(isOn: Bool) {
        guard !isOn else { return }
        endLiveActivity(.indexing)
        endLiveActivity(.summarizing)
    }

    /// Ends the activity this process holds for `kind`, if it holds one. It lingers
    /// `LiveActivityLifecycle.lingerAfterEnd` seconds, so the finished state is seen first.
    private func endLiveActivity(_ kind: LiveActivityJobKind) {
        guard let id = heldLiveActivityIDs.removeValue(forKey: kind) else { return }
        lastLiveActivityStates[kind] = nil
        endedLiveActivityIDs.insert(id)
        liveActivityHost.end(id, dismissal: .afterLinger)
    }

    // MARK: - The keep-alive (#1642)

    /// Sends `state` to the activity `id`, and keeps it for the keep-alive to send again.
    private func sendLiveActivityState(_ state: IndexingActivityAttributes.ContentState, to id: String) {
        lastLiveActivityStates[state.resolvedKind] = state
        keepLiveActivitiesFresh()
        liveActivityHost.update(id, to: state)
    }

    /// Starts the keep-alive, if it is not running.
    ///
    /// A run reports when it has something to report, and some of its phases report nothing for
    /// a long time: the merge that ends a whole-library pass runs 30 to 60 seconds without a
    /// word on a full corpus, a summarization run says nothing while it lists a large scope's
    /// documents, and a queue waits between two volumes for a download to land. A stale date
    /// counted from the run's last report would pass in such a phase with the app at work, and
    /// the Lock Screen would say the work had stopped. So while this process holds an activity it
    /// sends the last state again every `LiveActivityLifecycle.keepAliveEvery` seconds, each time
    /// with a new stale date. The date then passes only when the app has stopped running:
    /// suspended in the background, or gone.
    ///
    /// Measured on an iPhone 17 simulator (iOS 27.0) on 2026-10-12, with a whole-library pass of
    /// 75 volumes made to report once and then nothing. Without this loop the system marked its
    /// activity stale 120 seconds in, while the pass was still indexing. With it the same pass
    /// ran 3 minutes 51 seconds and was never marked: the loop sent seven times, 30 seconds
    /// apart, and each send moved the system's mark to 120 seconds after it.
    ///
    /// The loop ends by itself at the first turn that finds no activity held, and the next
    /// update starts it again.
    ///
    /// It cannot tell a run that died from one that is quiet unless the run says so. A volume whose
    /// pass throws does, since #1695 (`IndexingStage.failed`): its queue goes on to the next volume
    /// or ends, and until one of those happens the activity keeps the failed volume's last state.
    private func keepLiveActivitiesFresh() {
        guard liveActivityKeepAlive == nil else { return }
        liveActivityKeepAlive = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(LiveActivityLifecycle.keepAliveEvery))
                guard let self, !Task.isCancelled else { return }
                guard self.resendHeldLiveActivityStates() else {
                    self.liveActivityKeepAlive = nil
                    return
                }
            }
        }
    }

    /// Sends each activity this process holds its last state again, with a new stale date.
    ///
    /// - Returns: Whether this process holds an activity at all.
    private func resendHeldLiveActivityStates() -> Bool {
        for (kind, id) in heldLiveActivityIDs {
            guard let state = lastLiveActivityStates[kind] else { continue }
            liveActivityHost.update(id, to: state)
        }
        return !heldLiveActivityIDs.isEmpty
    }

    // MARK: - Leftover Live Activities (#1642)

    /// What this process is doing with Live Activities, as `LiveActivityLifecycle.isLeftover`
    /// reads it: which activities are its own, which kinds have a run that can still take one
    /// over, and whether it may show one at all.
    var liveActivityDriver: LiveActivityLifecycle.Driver {
        var running: Set<LiveActivityJobKind> = []
        if launchIndexPassesInFlight > 0 { running.insert(.indexing) }
        if backgroundSummarizationProgress.state.isRunning { running.insert(.summarizing) }
        let switchedOn = (UserDefaults.standard.object(forKey: SettingsKeys.liveActivityEnabled) as? Bool) ?? true
        return LiveActivityLifecycle.Driver(
            driven: drivenLiveActivityIDs,
            running: running,
            // The host's answer first, as in the two sync functions: in a test's process it asks
            // the system nothing (`LiveActivityPolicy`).
            mayShow: liveActivityHost.mayShow && switchedOn
        )
    }

    /// Records that this launch has decided to run an index pass of its own, before the pass
    /// starts: the whole-library pass, the rebuild from the cache, or the pass over volumes left
    /// unindexed. Until `launchIndexPassDidEnd()` answers it, a live indexing activity left by an
    /// earlier process is not ended, because the pass takes it over at its first progress update.
    func launchIndexPassWillBegin() {
        launchIndexPassesInFlight += 1
    }

    /// Records that one of this launch's index passes has finished, and ends what it left: an
    /// activity it never took over, because it reported nothing or was not allowed to show one.
    func launchIndexPassDidEnd() {
        launchIndexPassesInFlight = max(0, launchIndexPassesInFlight - 1)
        endLeftoverLiveActivities()
    }

    /// Ends every Live Activity of the app's that nothing in this process is driving (#1642).
    ///
    /// An activity is held in memory by the process that started it, so when the app is killed
    /// while it indexes or summarizes, nothing ends the activity and the Lock Screen goes on
    /// showing the progress as it stood. This is called at launch, once the launch has decided
    /// which index passes it will run, and again as each of those passes finishes;
    /// `LiveActivityLifecycle.isLeftover(_:driver:)` is the rule. It runs in every process, a
    /// test's and a background launch included: it starts nothing and can only remove.
    ///
    /// A leftover is dismissed at once and not after the three seconds a finished run's activity
    /// lingers. A dismissal that comes due after the app has gone makes the system open the app
    /// again in the background (`LiveActivityPolicy`); one made now cannot. Ending an activity
    /// the system already lists as ended dismisses it too: measured on 2026-10-12, one with 71
    /// seconds of its dismissal still to run was removed by the launch's sweep.
    func endLeftoverLiveActivities() {
        let driver = liveActivityDriver
        for listed in liveActivityHost.listedActivities()
        where LiveActivityLifecycle.isLeftover(listed, driver: driver) {
            endedLiveActivityIDs.insert(listed.id)
            liveActivityHost.end(listed.id, dismissal: .immediately)
        }
    }

    // MARK: - Summarization Live Activity

    /// Re-arming observer that mirrors `backgroundSummarizationProgress.state` onto a
    /// Live Activity. Call once at boot; it re-subscribes after every change.
    func startObservingSummarizationProgress() {
        withObservationTracking {
            _ = backgroundSummarizationProgress.state
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.syncSummarizationLiveActivity()
                self.startObservingSummarizationProgress()
            }
        }
    }

    /// Starts, updates or ends the summarization Live Activity from the current progress state.
    /// Mirrors `syncIndexingLiveActivity(update:)`, for the on-device summarizer, and ends with
    /// the run.
    ///
    /// The state says whether the run goes on by itself in the background
    /// (`BackgroundSummarizationRequestStore.hasPending`, decision 64), which is what the activity
    /// says once the app is suspended. So Settings calls this too when Continue in the background
    /// changes: a run whose saved request was cleared must not go on saying it will continue.
    func syncSummarizationLiveActivity() {
        guard liveActivityHost.mayShow else { return }
        let liveActivityEnabled = (UserDefaults.standard.object(forKey: SettingsKeys.liveActivityEnabled) as? Bool) ?? true

        switch backgroundSummarizationProgress.state {
        case let .running(tally, _, _):
            guard liveActivityEnabled else { endLiveActivity(.summarizing); return }
            showLiveActivity(LiveActivityLifecycle.summarizationState(
                tally: tally,
                continuesInBackground: BackgroundSummarizationRequestStore.hasPending
            ))
        case .completed, .cancelled, .failed, .idle:
            endLiveActivity(.summarizing)
        }
    }
    #endif

    #if os(iOS)
    /// A one-shot request to bring a tab forward, set by cross-view hand-offs (#316).
    ///
    /// The cross-view hand-offs (search-from-person, Spotlight, open-with, the analytics sheets Browse
    /// presents, …) write `pendingTab = .browse/.search/…` alongside their `pendingX` content field.
    /// A document opened inside a tab no longer uses this channel: it reads in that tab (2026-09-11). Each `MainTabView` consumes it into its own per-scene `@SceneStorage`
    /// selection and clears it, exactly like the other `pendingX` hand-offs.
    ///
    /// This is deliberately a **consume-once optional**, not a persistent "current tab": the tab
    /// selection lives per-window in `@SceneStorage` (so multiple iPad windows don't mirror each
    /// other), and a user tab tap never touches this channel — so a tap in one window cannot
    /// propagate to another. `nil` means no pending request. `MainTabView` also drains a
    /// non-`nil` value on appear, so a request delivered during a cold launch (open-with,
    /// Spotlight) before any `onChange` observer exists is not dropped.
    var pendingTab: Handoff<AppTab>? = nil

    /// Adopts and clears the consume-once tab hand-off (#316): returns the pending tab (the
    /// caller selects it) and nils the channel in the same step, so exactly one consumer ever
    /// adopts a given request — a second window (or the post-clear `onChange` re-fire) gets
    /// `nil` and keeps its own selection. Factored out of `MainTabView`'s `onChange`/`onAppear`
    /// drains so the adopt-then-clear contract is directly unit-testable.
    func consumePendingTab(for sceneID: SceneID) -> AppTab? {
        consumeHandoff(\.pendingTab, for: sceneID, orAnyWindow: true)
    }

    /// The persisted last-selected tab (or `.browse`), used to seed a fresh window's per-scene
    /// selection (#316). `MainTabView` writes it via ``persistTabSeed(_:)`` whenever its
    /// selection changes, so a brand-new window opens where the user last was.
    static var seedActiveTab: AppTab {
        guard let raw = UserDefaults.standard.string(forKey: Keys.activeTab),
              let tab = AppTab(rawValue: raw) else { return .browse }
        return tab
    }

    /// Persists the current tab as the fresh-window seed (#316). Writing `UserDefaults` directly
    /// (rather than a shared `@Observable` property) is what keeps a user tab tap in one window
    /// from being observed — and mirrored — by another.
    static func persistTabSeed(_ tab: AppTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: Keys.activeTab)
        #if DEBUG
        print("[FRUSExplorer] Tab seed: \(tab.rawValue)")
        #endif
    }

    /// The timestamp of the most recent visit to the Activity tab.
    ///
    /// Persisted via `UserDefaults` so the badge count ("notes since last visit")
    /// survives app relaunch. Retained for a potential future Research-tab badge; the
    /// Activity tab it was stamped for was replaced by Research in Session 130, so nothing
    /// currently writes it. Defaults to `.distantPast` so all existing notes appear as new
    /// on first launch.
    ///
    /// Version history:
    ///   1.0 — Session 45: initial implementation
    var lastActivityTabVisit: Date = {
        UserDefaults.standard.object(forKey: Keys.lastActivityTabVisit) as? Date ?? .distantPast
    }() {
        didSet {
            UserDefaults.standard.set(lastActivityTabVisit, forKey: Keys.lastActivityTabVisit)
            #if DEBUG
            print("[FRUSExplorer] lastActivityTabVisit updated to \(lastActivityTabVisit)")
            #endif
        }
    }

    /// Count of volumes that are downloaded but not yet present in the search index.
    ///
    /// Used to drive the Settings tab badge, prompting the user to run Reindex.
    /// Returns 0 before `downloadManager` is available (i.e. during boot).
    ///
    /// Stored, not computed — recomputed off the main thread when its inputs change.
    ///
    /// It used to be a computed property, and `MainTabView` reads it in a `.badge(…)` on
    /// every one of its five tabs. `isVolumeDownloaded` is a `FileManager.fileExists`, so
    /// each read was ~552 `stat(2)` syscalls on the main thread — against the very
    /// directory the downloader is writing into — repeated five times per body evaluation,
    /// at roughly ten body evaluations a second during an indexing run. The 1.1 doc comment
    /// claimed this kept "the render loop free of I/O", which was true of the SQLite query
    /// it replaced and never true of the `stat`s that took its place. Reading a stale count
    /// for a fraction of a second is not a defect; blocking the render loop on the
    /// filesystem is.
    ///
    /// Version history:
    ///   1.0 — Session 45: initial implementation
    ///   1.1 — Session 131: switched to `indexedVolumeIds` cache; no SQLite in render loop
    ///   2.0 — stored and refreshed off-main; the render loop now does no I/O for real
    private(set) var unindexedVolumeCount: Int = 0

    /// Recomputes ``unindexedVolumeCount`` on a background task.
    ///
    /// Idempotent and cheap to over-call: worst case it does the same filesystem sweep
    /// twice and writes the same number.
    func refreshUnindexedVolumeCount() {
        guard let dm = downloadManager else { return }
        let entries = (manifestStore.diffResult?.known ?? manifestStore.bundledEntries)
            .map(\.volumeId)
        let indexed = indexedVolumeIds
        Task.detached(priority: .utility) { [weak self] in
            let count = entries.filter { dm.isVolumeDownloaded($0) && !indexed.contains($0) }.count
            await MainActor.run { [weak self] in self?.unindexedVolumeCount = count }
        }
    }
    #endif

    /// The shared citation matching engine. Created at boot once a database URL is available.
    /// `nil` until boot completes or if the database could not be opened.
    var citationMatchingEngine: CitationMatchingEngine?

    /// The shared summarization service. Created at boot with the SwiftData container;
    /// always non-nil after boot. `AppleIntelligenceProvider.isAvailable` controls
    /// whether summarization features are presented in the UI.
    var summarizationService: SummarizationService?

    /// The background summarization service. Created at boot alongside `summarizationService`.
    var backgroundSummarizationService: BackgroundSummarizationService?

    /// Observable progress model for the background summarization service.
    /// Views observe this to display progress without calling into the actor.
    let backgroundSummarizationProgress: BackgroundSummarizationProgress = BackgroundSummarizationProgress()

    // MARK: - Network Monitor (private)

    /// Monitors network path changes and updates `isOnline`.
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "frus.networkMonitor", qos: .utility)

    // MARK: - Initialization

    init() {
        // O-0-2 — `manifest.json` is decoded ONCE, here, and shared.
        //
        // These two stores used to be default-valued stored properties, each calling a
        // parameterless init that reached into the bundle for `manifest.json`
        // independently: 763 KB decoded twice on the synchronous path before the first
        // frame. Building them in order and passing the entries across removes the second
        // decode (~8 ms) and, more importantly, means the tag index and the manifest can
        // never derive from two different reads of the file.
        //
        // The order is load-bearing: `manifestStore` owns the decode, so it must exist
        // first. Keep any future store that needs the manifest below these two, and give
        // it the entries rather than a third decode.
        let manifestStore = ManifestStore()
        self.manifestStore = manifestStore
        self.volumeLevelTagStore = VolumeLevelTagStore(
            bundledManifestEntries: manifestStore.bundledEntries
        )

        if let raw = UserDefaults.standard.string(forKey: Keys.activeProjectId),
           let uuid = UUID(uuidString: raw) {
            activeProjectId = uuid
        }

        startNetworkMonitor()

        #if DEBUG
        print("[FRUSExplorer] AppState initialised. activeProjectId=\(activeProjectId?.uuidString ?? "nil")")
        #endif
    }

    // MARK: - Private

    /// Starts the NWPathMonitor and keeps `isOnline` in sync with the network path.
    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOnline = self.isOnline
                self.isOnline = online
                #if DEBUG
                if wasOnline != online {
                    print("[FRUSExplorer] Network status changed: \(online ? "online" : "offline")")
                }
                #endif
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    private enum Keys {
        static let activeProjectId = "activeProjectId"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasFinishedOnboardingWithoutVolumes = "frus.onboarding.finishedWithoutVolumes"
        static let activeTab = "frus.activeTab"
        static let lastActivityTabVisit = "frus.lastActivityTabVisit"
        static let filterDownloadedOnly = "frus.filterDownloadedOnly"
        static let browseScopeFilterId = "frus.browseScopeFilterId"
    }
}

// MARK: - Cross-scene Handoff primitive (#338)

/// Identity of a UI scene (window) that a ``Handoff`` can be addressed to.
///
/// On iPad each ``MainTabView`` instance mints one (`@SceneStorage("frus.sceneID")`) and publishes it
/// through `\.sceneID`, so a cross-scene hand-off is delivered to exactly the scene it originated in
/// rather than fanning out to every open window (#338). Platform-neutral and `Sendable` so a single
/// ``Handoff`` type serves every field.
///
/// macOS document-open routing keeps its own, already-correct `DocumentHostID` / `RoutedBrowse`
/// provenance (its tool targets are singleton windows that can't fan out) and does not go through
/// `SceneID`.
///
/// ## Borrowed identities (#1351)
/// An iPad auxiliary window has no tab shell of its own, so ``AuxWindowOriginModifier`` publishes the
/// *launching* window's identity for producers that present into that window (the word cloud, the
/// analytics sheets). A view there can therefore name a real, live scene while standing in a
/// different window — and a hand-off that also switches a TAB then changes a window the reader is
/// not looking at, because a hand-off does not bring its window forward. (Since #1368 one thing
/// does: CLOSING an aux window, through ``AuxWindowCloseAction``. A door that leaves its window open
/// fronts nothing.) ``isBorrowed`` is how such a view can tell. It rides on the value itself rather
/// than on an environment key of its own, so every one of the app's explicit `\.sceneID`
/// re-injections into sheets carries it for free.
///
/// **Equality and hashing read `raw` alone, deliberately.** A borrowed identity must still address
/// the launcher: `Handoff.target == sceneID` is how the launcher consumes what it is sent, and
/// `liveSceneIDs` membership is how an origin is judged alive. Only ``isBorrowed`` itself, read
/// directly, tells the two apart.
///
/// ## The window it is borrowed BY (#1368 review round 1)
/// A borrowed identity also carries ``borrowingWindow``, the token of the aux window standing here,
/// for the same reason ``isBorrowed`` rides on the value: every re-injection carries it. It is what
/// an aux window opened from HERE records as the window to go back to on Done — without it, a rail
/// tool opened in the standalone document window recorded the MAIN window the document window had
/// borrowed from, and its Done fronted that. Excluded from `==` and hashing like ``isBorrowed``.
struct SceneID: Hashable, Sendable {
    /// Opaque per-scene token — a `UUID` string on iPad.
    let raw: String
    /// True when this identity was republished by an auxiliary window on behalf of the window that
    /// launched it (see "Borrowed identities" above). Excluded from `==` and `hash(into:)`.
    let isBorrowed: Bool
    /// The token of the auxiliary window that republished this identity, when it said — see "The
    /// window it is borrowed BY" above. `nil` for an identity a main window publishes as its own.
    /// Excluded from `==` and `hash(into:)`.
    let borrowingWindow: String?
    /// Wraps a raw per-scene token.
    init(_ raw: String) {
        self.raw = raw
        self.isBorrowed = false
        self.borrowingWindow = nil
    }

    private init(raw: String, isBorrowed: Bool, borrowingWindow: String?) {
        self.raw = raw
        self.isBorrowed = isBorrowed
        self.borrowingWindow = borrowingWindow
    }

    /// The same identity, marked as republished by an auxiliary window — the one whose token is
    /// `window`, when the caller knows it. Still `==` to `self`.
    func borrowed(by window: String? = nil) -> SceneID {
        SceneID(raw: raw, isBorrowed: true, borrowingWindow: window)
    }

    /// Compares by token only — see "Borrowed identities" for why ``isBorrowed`` is excluded.
    static func == (lhs: SceneID, rhs: SceneID) -> Bool { lhs.raw == rhs.raw }

    /// Hashes the token only, matching `==`.
    func hash(into hasher: inout Hasher) { hasher.combine(raw) }

    /// Fixed identity of the macOS singleton **word-cloud** window (`frus.wordcloud`, #338 step 2).
    /// macOS word-cloud hand-offs address this; iPad producers address their own minted per-scene id.
    static let macWordCloud = SceneID("frus.wordcloud")

    /// Fixed identity of the macOS singleton **Archival Analytics** window
    /// (`frus.archivalAnalytics`, #833) — where scoped topic and search hand-offs land.
    static let macArchivalAnalytics = SceneID("frus.archivalAnalytics")

    /// Fixed identity of the macOS singleton **Subjects** window (`frus.subjects`, #1023).
    static let macSubjects = SceneID("frus.subjects")

    /// Fixed identity of the macOS singleton **Corpus Analytics** window (`frus.analytics`, #338 step 3).
    static let macAnalytics = SceneID("frus.analytics")

    /// Fixed identity of the macOS singleton **Chronology** window (`frus.chronology`, #338 step 3).
    static let macChronology = SceneID("frus.chronology")

    /// Fixed identity of the macOS singleton **Corpus Browser** window (`frus.corpusBrowser`, #338
    /// step 4) — the volume hand-off target on macOS.
    static let macCorpusBrowser = SceneID("frus.corpusBrowser")

    /// Target for a macOS **legacy document-browse** hand-off (#338 step 4). macOS document opens
    /// route through the provenance model (`routedBrowse`); the only writer of `pendingBrowseDocument`
    /// on macOS is `unregisterHost`'s demotion of an orphaned in-flight open, drained by every host
    /// via `routeLegacyPendingBrowse`. This fixed target preserves that clear-first, exactly-once bridge.
    static let macLegacyBrowse = SceneID("frus.legacyBrowse")

    /// Wildcard target for a **scene-less** iPad open (#338 step 4) — a document reached from a deep
    /// link / Spotlight / Handoff continuation (no spawning window by definition) or from an auxiliary
    /// Stage-Manager window that publishes no `\.sceneID`. It is **first-wins, not a broadcast**: the
    /// first live `BrowserView` to observe it consumes-and-clears it, so the open lands in exactly ONE
    /// window (never fans out, never black-holes — c.f. the deliberately-absent broadcast target).
    static let anyWindow = SceneID("frus.anyWindow")

    /// Fixed identity of the macOS singleton **Search** window (`frus.search`, #338 step 5). macOS
    /// search hand-offs address this; iPad producers address their own scene.
    static let macSearch = SceneID("frus.search")

    /// The macOS Semantic Analytics window (UI review F-28), so a continued map lands in it.
    static let macSemanticAnalytics = SceneID("frus.semanticAnalytics")
}

/// A volume set to open Archival Analytics on, with the words to describe it (#833).
///
/// The label is carried rather than re-derived because only the sender knows what the set *means*
/// — "Vietnam War", "Search: dien bien phu", "the 1969–1976 subseries" — and the receiving chart
/// has to say it. A scope with no name would show narrowed figures over an unexplained population.
/// `Codable & Hashable` since CW-9c, so the same value can key the iOS `archivalAnalyticsScene`
/// window. Both fields are `[String]` and `String`, so both conformances are synthesised — and the
/// init already sorts `volumeIds`, which is what makes two requests for the same set compare
/// equal and therefore focus one window rather than opening a second identical chart.
struct ArchivalScopeRequest: Equatable, Sendable, Codable, Hashable {
    /// The volumes to scope to. Empty is treated as no scope by the receiver rather than as an
    /// empty chart, because a topic that matches nothing is a fact about the topic, not a filter.
    let volumeIds: [String]
    /// What to call this set on the chip, in the denominator sentence, and in the export.
    let label: String

    /// Creates a request, sorting the ids so the same set always compares equal.
    init(volumeIds: some Sequence<String>, label: String) {
        self.volumeIds = volumeIds.sorted()
        self.label = label
    }

    /// Opens the surface with no scope at all — the whole series, as the menu button has always
    /// done. It goes through the hand-off rather than round a side door so that iOS has exactly
    /// one presenter of this surface (#833).
    static let unscoped = ArchivalScopeRequest(volumeIds: [], label: "")
}

/// What a Subject Explorer was opened *at* (#1023).
///
/// ## Why a sum type and not `(ref, name)`
/// The three doors carry three different amounts of knowledge, and flattening them would make one
/// of them lie.
///
/// - The **Browse** row knows nothing — it wants the index from the top.
/// - The **results facet** knows a `(category, subcategory)` BUCKET, and cannot know a subject:
///   the facet aggregates `document_subjects`, which stores the bucket a document's subjects fold
///   to and never the subjects themselves. With a flat `(ref, name)` payload this door would have
///   to invent a ref it does not possess — most plausibly the bucket's first subject — which is a
///   fabricated claim about what the reader tapped, on a surface whose whole job is to say what a
///   number means. The bucket hand-off is also *lossless*: both subject tables are written from one
///   closure, and a document's buckets are literally `bucketByVocabIndex[subject]` for its own
///   subjects, so "documents in bucket B" is exactly "documents carrying any subject in B".
/// - The **subject pivot sheet** knows a single subject, ref and name both.
///
/// `Codable` because it rides a macOS window's restoration payload, `Hashable` because the window
/// group is keyed on it.
enum SubjectExplorerRequest: Equatable, Sendable, Codable, Hashable {

    /// The whole index, no selection — the Browse-tab door, and the honest arrival state when a
    /// more specific payload could not be resolved.
    case all

    /// A `(category, subcategory)` bucket, by its durable `SubjectBucketVocabulary` key — the
    /// results-facet door. Lands on the group, never on a subject inside it.
    case group(categoryKey: String)

    /// One subject, carrying both halves of the durable key: the ref is exact, and the name
    /// resolves it after a re-mint (see `SearchParameters.subjectRef`).
    case subject(ref: String, name: String)
}

/// A cross-scene hand-off carrying a `payload` addressed to a target ``SceneID``.
///
/// Replaces the process-global single-slot `pendingX` pattern, whose consumers were per-scene
/// observers on shared `AppState` — so on iPad multi-window a single hand-off was observed (and
/// applied) by *every* open window (#338 fan-out / nondeterministic winner). Carrying the target
/// scene lets only the addressed scene apply it, via ``AppState/consumeHandoff(_:for:)``: an iPad
/// ``MainTabView`` addresses its minted per-scene id; a macOS singleton tool window a fixed
/// ``SceneID`` of its own.
///
/// There is intentionally **no** "every window" broadcast target: it would need its own all-consume,
/// non-clearing consumer, so a reserved-but-unconsumable case would silently black-hole a hand-off
/// (#338 review). Reintroduce a target enum, with that consumer, if a broadcast use ever appears.
struct Handoff<Payload: Equatable & Sendable>: Equatable, Sendable, Identifiable {
    /// Stable identity, for dedupe, the consume-once re-read guard, and `.sheet(item:)`.
    let id: UUID
    /// The scene that should receive this hand-off.
    var target: SceneID
    /// The delivered value.
    var payload: Payload

    /// Creates a hand-off addressed to `target` carrying `payload`. `id` defaults to a fresh `UUID`.
    init(target: SceneID, payload: Payload, id: UUID = UUID()) {
        self.id = id
        self.target = target
        self.payload = payload
    }
}

extension AppState {
    /// Returns the payload of the hand-off at `keyPath` **iff** it is addressed to `sceneID`,
    /// clearing the slot as it does so (consume-once). A scene that is not the target gets `nil` and
    /// therefore never applies the hand-off — the fix for the #338 fan-out. Main-actor via `AppState`.
    func consumeHandoff<P>(_ keyPath: ReferenceWritableKeyPath<AppState, Handoff<P>?>,
                           for sceneID: SceneID) -> P? {
        guard let handoff = self[keyPath: keyPath],
              handoff.target == sceneID else { return nil }
        self[keyPath: keyPath] = nil
        return handoff.payload
    }

    /// As ``consumeHandoff(_:for:)``, but also accepts a hand-off addressed to the wildcard
    /// ``SceneID/anyWindow`` when `orAnyWindow` is true (#338 step 4). A scene-less open (deep link,
    /// Spotlight, an aux window) targets `.anyWindow`; because this still clears on consume, the first
    /// live scene to observe it wins and the open lands in exactly one window — never a fan-out.
    func consumeHandoff<P>(_ keyPath: ReferenceWritableKeyPath<AppState, Handoff<P>?>,
                           for sceneID: SceneID, orAnyWindow: Bool) -> P? {
        guard let handoff = self[keyPath: keyPath],
              handoff.target == sceneID || (orAnyWindow && handoff.target == .anyWindow) else { return nil }
        self[keyPath: keyPath] = nil
        return handoff.payload
    }

    /// Registers a main window's scene identity as live (called by `MainTabView.onAppear`). #338.
    func registerScene(_ id: SceneID) { liveSceneIDs.insert(id) }

    /// Removes a main window's scene identity (called by `MainTabView.onDisappear`). #338.
    func unregisterScene(_ id: SceneID) { liveSceneIDs.remove(id) }

    /// Resolves an aux window's stored origin (`rawSceneID`) to a delivery target: the originating
    /// window if it is still open, else the `.anyWindow` first-wins wildcard — so a document opened
    /// from an aux window lands in the launching window when it survives, and in *some* live window
    /// (never nowhere) when it doesn't (the launcher closed, or a restored aux window whose launcher
    /// is gone). #338 aux-window origin.
    func resolveOriginScene(_ rawSceneID: String?) -> SceneID {
        guard let rawSceneID else { return .anyWindow }
        let candidate = SceneID(rawSceneID)
        return liveSceneIDs.contains(candidate) ? candidate : .anyWindow
    }

    /// The `\.sceneID` an auxiliary window publishes: ``resolveOriginScene(_:)``, marked
    /// ``SceneID/borrowed(by:)`` so a view inside the window can tell it names another window
    /// (#1351), and carrying `window` — the aux window's own token — so a window opened from inside it
    /// knows which window to go back to (#1368 review round 1). `AuxWindowOriginModifier` publishes
    /// exactly this; it is a function so the mark can be tested.
    func auxWindowSceneID(forOrigin rawSceneID: String?, standingIn window: String? = nil) -> SceneID {
        resolveOriginScene(rawSceneID).borrowed(by: window)
    }

    /// Opens a value-based auxiliary window, recording the launching window's scene as its origin so a
    /// document opened from inside it routes back to that window (#338 aux-window origin). `sceneID` is
    /// the launcher's `@Environment(\.sceneID)` (nil on macOS, where aux windows route via provenance).
    func openAuxWindow<V: Codable & Hashable>(_ value: V, from sceneID: SceneID?,
                                              using openWindow: OpenWindowAction) {
        recordAuxWindowLaunch(from: sceneID)
        openWindow(value: value)
    }

    /// Parks the launch the next aux window drains — the testable half of
    /// ``openAuxWindow(_:from:using:)``, which calls nothing else before `openWindow(value:)`.
    ///
    /// Two facts, because an aux window launcher publishes a BORROWED `\.sceneID`: the scene it names
    /// (``pendingAuxWindowOriginRaw``, where the new window's hand-offs route) and the window the
    /// reader is actually in (``pendingAuxWindowLauncherRaw``, where its Done goes back to). From a
    /// main window they are the same token; from an aux window the second is that window's own
    /// ``SceneID/borrowingWindow`` (#1368 review round 1).
    func recordAuxWindowLaunch(from sceneID: SceneID?) {
        pendingAuxWindowOriginRaw = sceneID?.raw
        pendingAuxWindowLauncherRaw = sceneID?.borrowingWindow ?? sceneID?.raw
    }

    /// Opens a word cloud as a scene-addressed hand-off (#338 step 2, replacing the fan-out-prone
    /// single-slot `pendingWordCloud = scope`). On iPad it addresses the producing window's own
    /// `\.sceneID`, so only that window's sheet presents — no fan-out across open windows; on macOS
    /// the singleton `frus.wordcloud` window. Every producer calls this uniformly; pass the producer
    /// view's `@Environment(\.sceneID)` (nil on macOS, where it's ignored).
    func openWordCloud(_ scope: WordCloudScope, from sceneID: SceneID?) {
        #if os(macOS)
        pendingWordCloud = Handoff(target: .macWordCloud, payload: scope)
        #else
        // `\.sceneID` is published by MainTabView and must reach every producer. A nil means it did
        // not propagate (a sheet/inspector not handed it) — the sheet would then present in no
        // window. Loud in debug; in release it's a localized non-open, caught by the two-window
        // on-device check (#338 review Finding 1). Producers in sheets/inspectors inject `\.sceneID`
        // explicitly at their presentation site rather than trust inheritance.
        // A nil `sceneID` means `\.sceneID` didn't reach this producer — a producer in a scene that
        // doesn't publish one (a standalone document window, #338 step-2 follow-up). Rather than trap
        // (which would crash Debug builds) it falls through to an unmatched target, so the word cloud
        // simply doesn't present from that surface — a graceful no-op logged for diagnosis, not a
        // crash. The main-window and injected sheet/inspector producers always have a real id.
        #if DEBUG
        if sceneID == nil {
            print("[AppState] openWordCloud: \\.sceneID did not reach this producer (#338) — the word "
                + "cloud won't present here until this scene publishes a \\.sceneID + hosts the sheet.")
        }
        #endif
        pendingWordCloud = Handoff(target: sceneID ?? SceneID("frus.sceneID.unreached"), payload: scope)
        #endif
    }

    /// Opens Archival Analytics scoped to a volume set (#833).
    ///
    /// The same scene-addressed shape as `openWordCloud`: on macOS the destination is the
    /// singleton window, and on iOS it is the producing scene, so on iPad the profile opens in
    /// the window the reader was working in rather than fanning out across all of them.
    ///
    /// - Parameters:
    ///   - request: The volume set and the words for it.
    ///   - sceneID: The producing scene, on iOS.
    /// Routes a continued semantic map to the surface that shows it (UI review F-28).
    ///
    /// Written from `openArchivalScope`, which is the established shape for a destination that is
    /// a window on one platform and a sheet on the other.
    ///
    /// - Parameters:
    ///   - request: The scope and lens to restore.
    ///   - sceneID: The producing scene on iOS; ignored on macOS, where the window is the target.
    func openSemanticMap(_ request: SemanticMapRequest, from sceneID: SceneID?) {
        #if os(macOS)
        pendingSemanticMap = Handoff(target: .macSemanticAnalytics, payload: request)
        #else
        // A Handoff continuation has no producing scene — it arrives from another device — so
        // `.anyWindow` is correct here rather than a fallback: the first main window to observe it
        // presents the map, which is what the reader expects when they tap the badge.
        pendingSemanticMap = Handoff(target: sceneID ?? .anyWindow, payload: request)
        #endif
    }

    /// Opens the Subject Explorer at `request`, addressed to the scene the reader was in (#1023).
    ///
    /// Mirrors `openArchivalScope` exactly, including its DEBUG note when `\.sceneID` did not reach
    /// the producer — on iOS an unaddressed hand-off cannot present, and a silent no-op is the
    /// failure #338 exists to make visible.
    func openSubjectExplorer(_ request: SubjectExplorerRequest, from sceneID: SceneID?) {
        #if os(macOS)
        pendingSubjectExplorer = Handoff(target: .macSubjects, payload: request)
        #else
        #if DEBUG
        if sceneID == nil {
            print("[AppState] openSubjectExplorer: \\.sceneID did not reach this producer (#338) — "
                + "the subject index will not present from this surface.")
        }
        #endif
        pendingSubjectExplorer = Handoff(target: sceneID ?? SceneID("frus.sceneID.unreached"),
                                         payload: request)
        #endif
    }

    func openArchivalScope(_ request: ArchivalScopeRequest, from sceneID: SceneID?) {
        #if os(macOS)
        pendingArchivalScope = Handoff(target: .macArchivalAnalytics, payload: request)
        #else
        #if DEBUG
        if sceneID == nil {
            print("[AppState] openArchivalScope: \\.sceneID did not reach this producer (#338) — "
                + "the scoped profile will not present from this surface.")
        }
        #endif
        pendingArchivalScope = Handoff(target: sceneID ?? SceneID("frus.sceneID.unreached"),
                                       payload: request)
        #endif
    }

    /// Opens Corpus Analytics with `params` as a scene-addressed hand-off (#338 step 3, replacing the
    /// fan-out-prone `pendingAnalytics = params`). On iPad it addresses the producing window's own
    /// `\.sceneID`, so only that window's Browse-tab observer presents the chart — no fan-out across
    /// open windows; on macOS the singleton `frus.analytics` window (``SceneID/macAnalytics``).
    /// Producers call this in place of the assignment; the surrounding open-window / tab-switch /
    /// dismiss logic is unchanged. Pass the producer view's `@Environment(\.sceneID)` (nil on macOS,
    /// where it is ignored).
    func openAnalytics(_ params: AnalyticsParameters, from sceneID: SceneID?) {
        #if os(macOS)
        pendingAnalytics = Handoff(target: .macAnalytics, payload: params)
        #else
        #if DEBUG
        if sceneID == nil {
            print("[AppState] openAnalytics: \\.sceneID did not reach this producer (#338 step 3) — "
                + "the chart won't present until this scene publishes a \\.sceneID.")
        }
        #endif
        pendingAnalytics = Handoff(target: sceneID ?? SceneID("frus.sceneID.unreached"), payload: params)
        #endif
    }

    /// Opens the Chronology browser with `params` as a scene-addressed hand-off (#338 step 3),
    /// mirroring ``openAnalytics(_:from:)``: iPad addresses the producing window's `\.sceneID` (only
    /// its Browse-tab observer presents), macOS the singleton `frus.chronology` window
    /// (``SceneID/macChronology``). Pass the producer view's `@Environment(\.sceneID)`.
    func openChronology(_ params: ChronologyParameters, from sceneID: SceneID?) {
        #if os(macOS)
        pendingChronology = Handoff(target: .macChronology, payload: params)
        #else
        #if DEBUG
        if sceneID == nil {
            print("[AppState] openChronology: \\.sceneID did not reach this producer (#338 step 3) — "
                + "Chronology won't present until this scene publishes a \\.sceneID.")
        }
        #endif
        pendingChronology = Handoff(target: sceneID ?? SceneID("frus.sceneID.unreached"), payload: params)
        #endif
    }

    /// Opens a document in the browser as a scene-addressed hand-off (#338 step 4). On iPad it
    /// addresses the producing window's own `\.sceneID`, so only that window's `BrowserView` appends
    /// it — no fan-out across open windows. On macOS it targets `.macLegacyBrowse`, which every
    /// document host drains through `routeLegacyPendingBrowse` (clear-first, exactly-once) into the
    /// provenance router — i.e. the pre-existing legacy bridge, unchanged. Works uniformly whether a
    /// producer is iOS-only or cross-platform; a macOS producer that already routes through
    /// `openDocument(_:from:)` never calls this. Pass the producer view's `@Environment(\.sceneID)`.
    func openBrowseDocument(_ entry: DocumentBrowserEntry, from sceneID: SceneID?) {
        #if os(macOS)
        pendingBrowseDocument = Handoff(target: .macLegacyBrowse, payload: entry)
        #else
        // A nil `sceneID` is EXPECTED, not a bug: the producer is scene-less — an aux Stage-Manager
        // window (Archival Neighbors / Related Documents / the standalone Document window) or a deep
        // link / Spotlight / Handoff continuation — none of which publish `\.sceneID`. Route those to
        // the `.anyWindow` wildcard so the first live `BrowserView` opens the document (one window, no
        // fan-out) rather than stranding it at a dead sentinel (#338 step-4 review Findings 1/2/3/5/6/7).
        #if DEBUG
        if sceneID == nil {
            print("[AppState] openBrowseDocument: scene-less producer — routing to .anyWindow (#338 step 4).")
        }
        #endif
        pendingBrowseDocument = Handoff(target: sceneID ?? .anyWindow, payload: entry)
        #endif
    }

    /// Opens a volume in the browser as a scene-addressed hand-off (#338 step 4), the volume-grain
    /// sibling of ``openBrowseDocument(_:from:)``: iPad addresses the producing window's `\.sceneID`
    /// (only its `BrowserView` appends), macOS the singleton corpus-browser window (`.macCorpusBrowser`).
    /// Pass the producer view's `@Environment(\.sceneID)`. It clears ``followedPageLink``, which a page
    /// link sets again after calling it (#1766).
    func openBrowseVolume(_ volumeId: String, from sceneID: SceneID?) {
        followedPageLink = nil
        #if os(macOS)
        pendingBrowseVolume = Handoff(target: .macCorpusBrowser, payload: volumeId)
        #else
        // A nil `sceneID` routes to the `.anyWindow` wildcard (first-wins) rather than a dead sentinel,
        // matching `openBrowseDocument` — defensive for any scene-less volume producer (#338 step 4).
        #if DEBUG
        if sceneID == nil {
            print("[AppState] openBrowseVolume: scene-less producer — routing to .anyWindow (#338 step 4).")
        }
        #endif
        pendingBrowseVolume = Handoff(target: sceneID ?? .anyWindow, payload: volumeId)
        #endif
    }

    /// Opens Search with `params` as a scene-addressed hand-off (#338 step 5). On iPad it addresses the
    /// producing window's own `\.sceneID` (so the SAME window switches to Search and runs the query — no
    /// more decoupled winners; nil scene-less producers route to `.anyWindow` first-wins). On macOS it
    /// targets the singleton `frus.search` window (`.macSearch`). On iOS, pair with `openTab(.search, from:)`.
    func openSearch(_ params: SearchParameters, from sceneID: SceneID?) {
        #if os(macOS)
        pendingSearch = Handoff(target: .macSearch, payload: params)
        #else
        pendingSearch = Handoff(target: sceneID ?? .anyWindow, payload: params)
        #endif
    }

    /// Asks Search to show its tips (#1299): the Search Tips sheet in the addressed window's Search tab on iPad and
    /// iPhone, the Tips panel in the singleton `frus.search` window on macOS.
    ///
    /// Addressed exactly as ``openSearch(_:from:)`` addresses a query, so a request and a search cannot disagree about
    /// which window they reach. On iOS, pair with `openTab(.search, from:)`; on macOS, front the Search window. A
    /// `.commands` producer has no `\.sceneID` and passes `nil`, which on an iPad with two windows is the first-wins
    /// behaviour `openTab(_:from:)` documents for a nil scene.
    func openSearchTips(from sceneID: SceneID?) {
        #if os(macOS)
        pendingSearchTips = Handoff(target: .macSearch, payload: true)
        #else
        pendingSearchTips = Handoff(target: sceneID ?? .anyWindow, payload: true)
        #endif
    }

    #if os(iOS)
    /// Brings a tab forward as a scene-addressed hand-off (#338 step 5, folding the old shared
    /// `pendingTab`). Addresses the producing window's `\.sceneID` (scene-less producers pass
    /// `.anyWindow`), so the tab switch lands in the SAME window as its content hand-off — the two can
    /// no longer split across windows (BUG-7). macOS has no tabs; it routes to windows instead.
    func openTab(_ tab: AppTab, from sceneID: SceneID?) {
        pendingTab = Handoff(target: sceneID ?? .anyWindow, payload: tab)
    }
    #endif
}

// MARK: - Scene identity environment

private struct SceneIDEnvironmentKey: EnvironmentKey {
    static let defaultValue: SceneID? = nil
}

extension EnvironmentValues {
    /// Identity of the scene (window) the current view renders in, if the host published one (iPad
    /// ``MainTabView``). A hand-off producer reads it to address a ``Handoff`` to its own scene.
    var sceneID: SceneID? {
        get { self[SceneIDEnvironmentKey.self] }
        set { self[SceneIDEnvironmentKey.self] = newValue }
    }
}

// MARK: - Closing an auxiliary window (#1368)

/// What an iOS auxiliary window publishes at its scene root so that closing it brings one of the
/// app's main windows forward instead of leaving the reader on the Home Screen (#1368).
///
/// ## The defect this exists for
/// On iPad the analysis surfaces, Source Explorer, the cross-reference graph and the rail's word
/// cloud open as `WindowGroup` scenes of their own, filling the screen, and the launching window
/// goes to the background. Their Done buttons were written for the sheets they used to be, and
/// `dismiss()` at the root of a window scene closes the scene — so with nothing asking iPadOS to show
/// another of the app's windows, it could show the Home Screen (measured on iOS 27.0 in Windowed
/// Apps mode, a fresh simulator's default: Archival and Semantic Analytics' Done, every run). The app
/// had not quit; tapping its icon brought the main window back as it was.
///
/// ## Why an environment value, and why the scene publishes it
/// A Done cannot tell whether it closes a sheet or a window: `dismiss()` does whichever its container
/// is. The root of an aux window's scene is where "this is a window" is known, so
/// ``AuxWindowOriginModifier`` — the only writer of this value — publishes it there: from the scene
/// declarations in `FRUSExplorerApp` for ten of the twelve aux scenes, and from inside the window
/// view's own file for the other two (`ArchivalNeighborsWindowView`, `RelatedDocumentsWindowView`),
/// which are only ever a `WindowGroup`'s content.
///
/// Where it is ABSENT — every iPhone presentation, every sheet a main window presents, and every
/// macOS window — ``AuxWindowCloseAction`` is the plain `dismiss()` it replaced. A sheet presented
/// INSIDE an aux window is the other case: the value does reach it through the environment, and
/// ``AuxWindowClose`` WITHHOLDS it there (`\.isPresented`), with the same result.
///
/// ## Why closures
/// So the views never touch UIKit, and a test can stand in for the window being closed. The
/// production closures (``AppState/auxWindowClosing(origin:launcher:)``) resolve where to go at the
/// moment of the tap, against the sessions iPadOS reports open then — not when the window opened,
/// because the launcher may have closed since.
struct AuxWindowClosing: Sendable {
    /// The scene a hand-off from this window should be addressed to, given the producer's own
    /// `\.sceneID`: the main window ``front`` will bring forward for it, so the content and the
    /// window the reader lands in are the same one. Always a MAIN window, or `.anyWindow` when a new
    /// one must be requested — never an aux window, which consumes no hand-off.
    let handOffTarget: @MainActor @Sendable (SceneID?) -> SceneID
    /// Asks iPadOS to bring forward the main window a hand-off addressed to the argument lands in —
    /// or, for `nil` (no hand-off), the window that launched this one, which may be an aux window.
    let front: @MainActor @Sendable (SceneID?) -> Void
}

private struct AuxWindowClosingKey: EnvironmentKey {
    static let defaultValue: AuxWindowClosing? = nil
}

extension EnvironmentValues {
    /// The close payload an iOS auxiliary window's scene root publishes (#1368); `nil` everywhere
    /// else. Read it through ``AuxWindowClose``, never directly — the wrapper is what withholds it
    /// from a view the window presents.
    var auxWindowClosing: AuxWindowClosing? {
        get { self[AuxWindowClosingKey.self] }
        set { self[AuxWindowClosingKey.self] = newValue }
    }
}

/// The close a Done performs in a view that may be the root of an iPad auxiliary window (#1368).
///
/// At a window's root it asks iPadOS to bring a main window forward, then dismisses — which there
/// closes the window. Anywhere else it is the view's own `dismiss()`, exactly as before.
///
/// **"Anywhere else" includes a sheet INSIDE an aux window**, which is why the initializer takes
/// `isPresented`. The environment reaches a sheet the window presents — the Research Guide opened
/// from Source Explorer's toolbar can present Archival Analytics — and there `dismiss()` closes the
/// sheet, not the window. Fronting the launcher then would pull the reader out of a window that is
/// staying open, so a presented view never fronts anything.
///
/// **Front first, then dismiss**: dismissing ends this scene. Both are requests iPadOS carries out
/// asynchronously, and whether the Home Screen can show for a frame between them is a question only
/// a device answers (`Planning/DEVELOPMENT-PLAN.md`, 2026-09-24).
@MainActor
struct AuxWindowCloseAction {
    /// The view's own dismissal — at a window's root, closing the window.
    private let dismiss: @MainActor () -> Void
    /// The window payload, or `nil` when the view is presented or nothing published one.
    let window: AuxWindowClosing?

    /// - Parameters:
    ///   - dismiss: The view's `\.dismiss`.
    ///   - isPresented: The view's `\.isPresented`; `true` withholds `window`, see the type's doc.
    ///   - window: The payload the scene root published, if any.
    init(dismiss: @escaping @MainActor () -> Void, isPresented: Bool, window: AuxWindowClosing?) {
        self.dismiss = dismiss
        self.window = isPresented ? nil : window
    }

    /// Closes: at a window's root, brings the window that launched it forward first — a main window,
    /// or the aux window it was opened from (the standalone document window's rail tools) — or,
    /// failing that, another main window; everywhere else, only dismisses.
    func callAsFunction() {
        window?.front(nil)
        dismiss()
    }

    /// The scene a hand-off made just before this closes should be addressed to. At a window's
    /// root, the main window ``callAsFunction(frontingHandOffTo:)`` will bring forward; everywhere
    /// else `sceneID`, unchanged — so a sheet's hand-offs, and the openers' own fallbacks for a nil
    /// scene, are exactly what they were.
    func handOffTarget(from sceneID: SceneID?) -> SceneID? {
        guard let window else { return sceneID }
        return window.handOffTarget(sceneID)
    }

    /// Closes after a hand-off addressed to `target` (from ``handOffTarget(from:)``): at a window's
    /// root, brings that window forward first; everywhere else, only dismisses.
    ///
    /// A `nil` target still names a hand-off, so it is sent as `.anyWindow` rather than as the plain
    /// close `nil` means to ``AuxWindowClosing/front``: content went to a main window, and the
    /// launching aux window a plain close may return to is not where it went.
    func callAsFunction(frontingHandOffTo target: SceneID?) {
        window?.front(target ?? .anyWindow)
        dismiss()
    }
}

/// Reads a view's ``AuxWindowCloseAction`` — its `\.dismiss`, its `\.isPresented` and the scene's
/// `\.auxWindowClosing`, together (#1368).
///
/// A property wrapper rather than three `@Environment` lines per view so that a Done cannot read the
/// payload without the `isPresented` check that keeps it out of sheets. Declare it where the view
/// declared `@Environment(\.dismiss)`: the three are read at the view's own position, which is what
/// decides whether its `dismiss()` closes a window.
@MainActor
@propertyWrapper
struct AuxWindowClose: DynamicProperty {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @Environment(\.auxWindowClosing) private var window

    /// Reads the three environment values at the declaring view's position.
    init() {}

    /// The close action for the declaring view.
    var wrappedValue: AuxWindowCloseAction {
        let dismiss = self.dismiss
        return AuxWindowCloseAction(dismiss: { dismiss() }, isPresented: isPresented, window: window)
    }
}

#if os(iOS)
/// #338 aux-window origin: drains the launching window's scene from the transient `AppState` hand-off
/// once on appear and re-publishes it as this auxiliary window's `\.sceneID` (resolved live, else
/// `.anyWindow`). Applied to an aux `WindowGroup`'s content root, it makes origin flow TRANSITIVELY:
/// a document opened here — or a further aux window launched here — routes back to the originating
/// main window. Captured ONCE: a same-request `openWindow(value:)` refocus keeps the first origin
/// (a live window, no black-hole; #338 review, accepted).
///
/// The consequence of capturing once, stated plainly (#752 / L-48): an aux window **refocused from a
/// different main window** keeps its *first* origin, so a related-document tap inside it routes to
/// the window that originally opened it rather than the one that just refocused it. That is the
/// accepted trade — the alternative, re-capturing on every appear, would let a background window's
/// stale launch overwrite a foreground one's — and since #752/L-40 it is the behaviour
/// `SourceExplorerWindowContent` inherits, so it is worth knowing before reading that code.
///
/// The published identity is marked borrowed (#1351, ``AppState/auxWindowSceneID(forOrigin:standingIn:)``):
/// it still addresses the launcher, and it tells a view here that the launcher is not the window
/// it is standing in.
///
/// ## The close payload, and the windows that publish ONLY that (#1368)
/// Every iOS aux window also publishes ``AuxWindowClosing`` built from the same captured origin, so
/// its Done — and every exit that hands content to a main window and then closes — brings a main
/// window forward instead of leaving the reader on the Home Screen. All twelve aux scenes apply this
/// modifier, so all twelve drain ``AppState/pendingAuxWindowOriginRaw``.
///
/// The six analytics windows apply it with `republishesSceneID: false` (`.auxWindowCloseOnly`): they
/// learn where to go back to without borrowing the launcher's `\.sceneID`. Borrowing it would change
/// what they ROUTE, which is not this modifier's business there. `ArchivalAnalyticsView` claims a
/// scope hand-off addressed to `sceneID ?? .anyWindow`, so with the launcher's identity it would
/// consume requests meant for the launcher — racing `MainTabView.consumePendingArchivalScope` for
/// every scope the reader sends from a main window — and every analytics producer that addresses
/// `nil` today would start addressing the launcher. Those windows' closing exits address the window
/// they front through ``AuxWindowCloseAction/handOffTarget(from:)`` instead, one call at a time.
///
/// ## An aux window is also a LAUNCHER (#1368 review round 1)
/// The standalone document window's rail opens Source Explorer, the graph, the word cloud and the
/// semantic map, and the reader expects Done in any of them to bring back the document window — not
/// the main window it borrowed its identity from. So each window mints a token of its own
/// (`windowToken`), registers its UIKit session under it (``AppState/auxWindowSessions``), and
/// passes it on inside the borrowed `\.sceneID` (``SceneID/borrowingWindow``), which is what
/// ``AppState/recordAuxWindowLaunch(from:)`` parks for the next window as its launcher. It captures
/// that launcher (``AppState/pendingAuxWindowLauncherRaw``) beside its origin, once, the same way.
struct AuxWindowOriginModifier: ViewModifier {
    /// The app state the origin is drained from and resolved against.
    let appState: AppState
    /// Whether this window republishes its launcher's identity as its own `\.sceneID` (#338). True
    /// for the six document-anchored windows, false for the six analytics windows (#1368).
    var republishesSceneID = true
    @State private var originRaw: String? = nil
    /// The window the reader launched this one from — a main window's token, or an aux window's.
    @State private var launcherRaw: String? = nil
    /// This window's own token, under which it registers its session for the windows it launches.
    @State private var windowToken = "frus.auxWindow." + UUID().uuidString
    @State private var didCapture = false
    func body(content: Content) -> some View {
        Group {
            if republishesSceneID {
                content
                    .environment(\.sceneID, appState.auxWindowSceneID(forOrigin: originRaw, standingIn: windowToken))
            } else {
                content
            }
        }
        .environment(\.auxWindowClosing, appState.auxWindowClosing(origin: originRaw, launcher: launcherRaw))
        // The session a window launched from here asks iPadOS for when it closes (round 1).
        .background {
            SceneSessionReader { appState.registerAuxWindowSession($0, for: windowToken) }
        }
        .onAppear {
            guard !didCapture else { return }
            didCapture = true
            originRaw = appState.pendingAuxWindowOriginRaw
            launcherRaw = appState.pendingAuxWindowLauncherRaw
            appState.pendingAuxWindowOriginRaw = nil
            appState.pendingAuxWindowLauncherRaw = nil
        }
    }
}

extension View {
    /// Applies ``AuxWindowOriginModifier`` — see it for the origin-propagation contract.
    func auxWindowOrigin(_ appState: AppState) -> some View { modifier(AuxWindowOriginModifier(appState: appState)) }

    /// Applies ``AuxWindowOriginModifier`` WITHOUT republishing the launcher's `\.sceneID`: the
    /// window records where it was opened from so its Done can go back there, and nothing else
    /// (#1368). For the six analytics windows — see the modifier for why they must not borrow.
    func auxWindowCloseOnly(_ appState: AppState) -> some View {
        modifier(AuxWindowOriginModifier(appState: appState, republishesSceneID: false))
    }
}

// MARK: - Where a closing aux window leaves the reader (#1368)

/// How far a main window's session is from the reader, for choosing one to bring forward (#1368).
/// Ordered: a lower raw value is preferred.
enum AuxWindowSessionState: Int, Sendable {
    /// Its scene is on screen (`foregroundActive` or `foregroundInactive`).
    case foreground = 0
    /// Its scene is connected but not on screen.
    case background = 1
    /// The system keeps the session with no scene connected — still in the app switcher, and
    /// activatable, but slower to bring back and not verified on a device (see `front(_:)`).
    case unattached = 2
}

/// A main window's UIKit session, as its `MainTabView` registered it (#1368).
struct RegisteredMainWindow: Equatable, Sendable {
    /// The session's `persistentIdentifier` — what `UIApplication.openSessions` is searched for.
    let sessionID: String
    /// When it registered, in registration order; the newer of two otherwise equal candidates wins.
    let sequence: Int
}

/// One attempt to bring a window forward (#1368).
enum AuxWindowActivationStep: Equatable, Sendable {
    /// Activate the open session with this `persistentIdentifier`.
    case session(String)
    /// Ask iPadOS for a new main window — the scene the app declares first.
    case newMainWindow
}

/// Where closing an iOS auxiliary window leaves the reader (#1368).
///
/// ## The rule, in order
/// 0. **For a plain close only, the aux window this one was launched from**, when it is still
///    open (#1368 review round 1). The standalone document window's rail tools come back to the
///    document window, not to the main window behind it. A close that follows a hand-off skips
///    this step: the content went to a main window, and an aux window consumes no hand-off.
/// 1. **The hand-off's own target**, when the close follows a hand-off addressed to a main window
///    that is still open — the content went there, so that is where the reader must land.
/// 2. **The launching main window** — the scene the window routes to — when it is still open.
/// 3. **Any open main window**: on screen before off screen before unattached, then the most
///    recently registered, then by token so the choice never depends on dictionary order.
/// 4. **A new main window**, when none is open (closed in Stage Manager, say): iPadOS is asked for
///    one rather than being left to show the Home Screen.
///
/// "Open" means present in `UIApplication.openSessions`, **not** in `AppState.liveSceneIDs`.
/// `MainTabView.onDisappear` removes a window from `liveSceneIDs`, and SwiftUI does not promise
/// that fires only when the session ends; a session that survives it is still a window the reader
/// can be returned to. The registries the rule reads are never pruned for the same reason — a
/// stale entry is harmless because a session that has ended is not in `openSessions`.
indirect enum AuxWindowDestination: Equatable, Sendable {
    /// An open main window: its scene token and its session's `persistentIdentifier`.
    case mainWindow(SceneID, sessionID: String)
    /// The open aux window this one was launched from (step 0), by its session's
    /// `persistentIdentifier` — with `fallback`, where steps 1–4 lead, for when iPadOS refuses it.
    case launchingAuxWindow(sessionID: String, fallback: AuxWindowDestination)
    /// No main window is open, so a new one is requested.
    case newMainWindow

    /// The scene a hand-off should be addressed to so that it lands in this destination. A window
    /// that does not exist yet has no token, so the new-window case addresses `.anyWindow`.
    ///
    /// **`.anyWindow` does not reach every channel.** The new window's `MainTabView` and
    /// `BrowserView` drain it for a tab, a search, a Browse volume or document and a word cloud —
    /// but `BrowserView` consumes the Corpus Analytics and Chronology hand-offs STRICTLY (no
    /// `orAnyWindow:`), so Analyze and View in Chronology from a Word Cloud window with no main
    /// window left open a new window on Browse without the chart. Not a regression (on `v2` the
    /// same `.anyWindow` went nowhere, and the reader was on the Home Screen), and not fixed here.
    ///
    /// An aux window takes no hand-off; the rule never chooses one for a hand-off, and asked
    /// anyway it answers for the main window behind it.
    var handOffTarget: SceneID {
        switch self {
        case .mainWindow(let scene, _): scene
        case .launchingAuxWindow(_, let fallback): fallback.handOffTarget
        case .newMainWindow: .anyWindow
        }
    }

    /// The attempts ``AppState/front(_:)`` makes, in order: the window's own session, then — if
    /// iPadOS refuses it — a new main window, so a failed activation still does not end on the Home
    /// Screen. (It may FLASH there: the aux window has already been dismissed when a failure is
    /// reported. Unmeasured; needs a device.) A launching aux window is tried first, then its
    /// fallback's steps.
    var activationSteps: [AuxWindowActivationStep] {
        switch self {
        case .mainWindow(_, let sessionID): [.session(sessionID), .newMainWindow]
        case .launchingAuxWindow(let sessionID, let fallback): [.session(sessionID)] + fallback.activationSteps
        case .newMainWindow: [.newMainWindow]
        }
    }

    /// Applies the rule above.
    ///
    /// - Parameters:
    ///   - target: The scene a hand-off was addressed to, or `nil` for a plain close. `.anyWindow`
    ///     and the unreachable sentinels name no registered window and fall through — but they are
    ///     still a hand-off, so step 0 is skipped for them too.
    ///   - origin: The raw token of the main window this one routes to, or `nil` (a restored window).
    ///   - registry: Every main window's session, by raw scene token.
    ///   - openSessions: The state of each open session, by `persistentIdentifier`.
    ///   - launcher: The raw token of the window the reader launched this one from — an aux
    ///     window's own token when it was one, else the same as `origin`.
    ///   - auxWindows: Every aux window's session, by its token (``AppState/auxWindowSessions``).
    static func resolve(target: SceneID?, origin: String?,
                        registry: [String: RegisteredMainWindow],
                        openSessions: [String: AuxWindowSessionState],
                        launcher: String? = nil,
                        auxWindows: [String: String] = [:]) -> AuxWindowDestination {
        let main = resolveMainWindow(target: target, origin: origin, registry: registry,
                                     openSessions: openSessions)
        if target == nil, let launcher, let sessionID = auxWindows[launcher],
           openSessions[sessionID] != nil {
            return .launchingAuxWindow(sessionID: sessionID, fallback: main)
        }
        return main
    }

    /// Steps 1–4 of the rule: always a main window, or a new one.
    private static func resolveMainWindow(target: SceneID?, origin: String?,
                                          registry: [String: RegisteredMainWindow],
                                          openSessions: [String: AuxWindowSessionState]) -> AuxWindowDestination {
        for raw in [target?.raw, origin].compactMap({ $0 }) {
            if let entry = registry[raw], openSessions[entry.sessionID] != nil {
                return .mainWindow(SceneID(raw), sessionID: entry.sessionID)
            }
        }
        let open = registry.compactMap { raw, entry -> (raw: String, entry: RegisteredMainWindow,
                                                          state: AuxWindowSessionState)? in
            openSessions[entry.sessionID].map { (raw, entry, $0) }
        }
        let best = open.min { lhs, rhs in
            if lhs.state != rhs.state { return lhs.state.rawValue < rhs.state.rawValue }
            if lhs.entry.sequence != rhs.entry.sequence { return lhs.entry.sequence > rhs.entry.sequence }
            return lhs.raw < rhs.raw
        }
        guard let best else { return .newMainWindow }
        return .mainWindow(SceneID(best.raw), sessionID: best.entry.sessionID)
    }
}

extension AppState {
    /// Records a main window's UIKit session under its scene token (#1368). Called by
    /// `MainTabView` once its window is known.
    ///
    /// Never removed — see ``AuxWindowDestination`` for why a stale entry is harmless and a pruned
    /// one is not. A repeat of the same pairing keeps its place in the order; a token that moved to
    /// a new session is re-registered as the newest.
    func registerSceneSession(_ sessionID: String, for sceneID: SceneID) {
        if mainWindowSessions[sceneID.raw]?.sessionID == sessionID { return }
        mainWindowSessionSequence += 1
        mainWindowSessions[sceneID.raw] = RegisteredMainWindow(sessionID: sessionID,
                                                               sequence: mainWindowSessionSequence)
    }

    /// Records an aux window's UIKit session under the token its ``AuxWindowOriginModifier`` minted
    /// (#1368 review round 1), so a window launched from it can bring it back on Done. Never removed,
    /// for the reason ``mainWindowSessions`` is not.
    func registerAuxWindowSession(_ sessionID: String, for windowToken: String) {
        auxWindowSessions[windowToken] = sessionID
    }

    /// Where a closing aux window leaves the reader, given a snapshot of the open sessions — the
    /// testable half of ``auxWindowClosing(origin:launcher:)``.
    func auxWindowDestination(target: SceneID?, origin: String?, launcher: String? = nil,
                              openSessions: [String: AuxWindowSessionState]) -> AuxWindowDestination {
        AuxWindowDestination.resolve(target: target, origin: origin, registry: mainWindowSessions,
                                     openSessions: openSessions,
                                     launcher: launcher, auxWindows: auxWindowSessions)
    }

    /// The state of every session iPadOS reports open, by `persistentIdentifier`.
    static func openSessionStates() -> [String: AuxWindowSessionState] {
        var states: [String: AuxWindowSessionState] = [:]
        for session in UIApplication.shared.openSessions {
            switch session.scene?.activationState {
            case .foregroundActive?, .foregroundInactive?:
                states[session.persistentIdentifier] = .foreground
            case .background?:
                states[session.persistentIdentifier] = .background
            default:
                states[session.persistentIdentifier] = .unattached
            }
        }
        return states
    }

    /// The close payload an aux window publishes (#1368): `origin` is the main window it routes to,
    /// `launcher` the window the reader opened it from (an aux window's own token when it was one).
    /// Both closures resolve at the moment they are called, against the sessions open then.
    ///
    /// `handOffTarget` never answers with the launching aux window, even for a producer with no
    /// scene: for that destination it answers with the main window behind it
    /// (``AuxWindowDestination/handOffTarget``), because the content has to go to a main window.
    /// `front` treats `nil` as the plain close it is.
    ///
    /// They capture `self` strongly, and that is deliberate: the one `AppState` lives as long as the
    /// app, and nothing it owns holds these closures, so there is no cycle to break — while a weak
    /// capture would add a nil branch no caller can reach and no test could.
    func auxWindowClosing(origin: String?, launcher: String?) -> AuxWindowClosing {
        AuxWindowClosing(
            handOffTarget: { target in
                self.auxWindowDestination(target: target, origin: origin, launcher: launcher,
                                          openSessions: Self.openSessionStates()).handOffTarget
            },
            front: { target in
                self.front(self.auxWindowDestination(target: target, origin: origin, launcher: launcher,
                                                     openSessions: Self.openSessionStates()))
            })
    }

    /// Brings `destination` forward — **the app's one scene-activation call** (#1368;
    /// `WindowTargetingTests.activationExistsAtExactlyOneSite` pins that it stays one).
    ///
    /// A step whose session has gone by the time it runs counts as a failure, so the next step — a
    /// main window after a launching aux window, and a new main window last — is tried instead of
    /// nothing. Two device questions stay open: whether a session iPadOS has disconnected
    /// (`unattached`) can be activated, and whether the Home Screen shows for a frame between this
    /// request and the aux window's dismissal.
    func front(_ destination: AuxWindowDestination) {
        Self.activate(destination.activationSteps) { step, failed in
            let request: UISceneSessionActivationRequest
            switch step {
            case .session(let sessionID):
                guard let session = UIApplication.shared.openSessions
                    .first(where: { $0.persistentIdentifier == sessionID }) else {
                    failed()
                    return
                }
                request = UISceneSessionActivationRequest(session: session)
            case .newMainWindow:
                request = UISceneSessionActivationRequest(role: .windowApplication)
            }
            UIApplication.shared.activateSceneSession(for: request) { @Sendable error in
                // `@Sendable`, so it is not inferred main-actor: UIKit does not promise the queue it
                // reports on. Domain and code only — the telemetry allow-list, never a description.
                let nsError = error as NSError
                Self.windowLog.error("""
                    aux-window close: activation refused (\(nsError.domain, privacy: .public) \
                    \(nsError.code, privacy: .public))
                    """)
                Task { @MainActor in failed() }
            }
        }
    }

    /// Scene-activation failures (#1368), in their own category so a device log can be filtered
    /// to them when the owed device check runs.
    nonisolated private static let windowLog = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "Windows")

    /// Tries `steps` in order, moving to the next only when `attempt` reports that a step failed —
    /// and stopping after the last. Separate from ``front(_:)`` so the fallback can be tested
    /// without asking UIKit for a window.
    static func activate(_ steps: [AuxWindowActivationStep],
                         using attempt: @escaping @MainActor @Sendable (
                            AuxWindowActivationStep, _ failed: @escaping @MainActor @Sendable () -> Void) -> Void) {
        guard let first = steps.first else { return }
        let rest = Array(steps.dropFirst())
        attempt(first) { activate(rest, using: attempt) }
    }
}

extension SceneID {
    /// Whether a hand-off that switches this window's TAB — the Topic index (`openSubjectExplorer` +
    /// `openTab(.browse)`), "Find all mentions" (`openSearch` + `openTab(.search)`) — lands in front
    /// of the reader, on iOS (#1274, #1351).
    ///
    /// It does only in a main window's tab shell. Everywhere else the pair splits, or is delivered to
    /// a window other than the reader's, so the door is withheld — the house answer to a door into a
    /// context that cannot receive it:
    /// - **nil** — the window publishes no scene (the semantic map, Chronology and the analytics
    ///   windows). The request goes to a target no view consumes, or to `.anyWindow`, while `openTab`
    ///   falls back to `.anyWindow` and switches some other window.
    /// - **`.anyWindow`** — the wildcard. A consumer that accepts it is first-observer-wins, so the
    ///   request lands in whichever window looks first; the Topic index's is strict
    ///   (`pendingSubjectExplorer`), so that one lands nowhere.
    /// - **borrowed** — a popped-out document window, and the Related Documents, Archival Neighbors,
    ///   cross-reference graph, Source Explorer and word-cloud windows, republish their LAUNCHER's
    ///   identity while it is open (a borrowed `.anyWindow` once it has closed, or for a restored
    ///   window). The pair is delivered, but to that window: measured on an iPad mini (iOS 26.4), a
    ///   topic tapped in a popped-out document's rail replaced the launcher's Browse history with the
    ///   Topic index while the document window in front showed no change. These doors leave their
    ///   window open, and only a CLOSING aux window brings another forward (#1368 — one activation
    ///   site, which `WindowTargetingTests` pins); #752's rule is that an action in a window happens in
    ///   that window.
    ///
    /// **Gated on it:** the rail's topic chips, the Find all mentions button on a document's person
    /// sheet, and the analytics and series scope bars' Topic-index doors. The other Topic-index doors
    /// (the Search facets panel, the subject pivot sheet, the index's own group doors) are presented
    /// only from a main window's Browse and Search tabs, and would need this gate before being
    /// presented anywhere else.
    ///
    /// **A scene-level test, and it cannot see sheets.** A view in a sheet over a main window carries
    /// that window's own identity and passes. The tab then switches beneath the sheet unless the door
    /// closes it first — the rail does close its own iPhone sheet, but a reader pushed inside another
    /// sheet (the iPhone Related Documents or cross-reference graph sheet, Project Home) still opens
    /// the index beneath that sheet. That predates #1351 and is not addressed by this predicate.
    static func tabHandoffOpensInFront(from sceneID: SceneID?) -> Bool {
        guard let sceneID, sceneID != .anyWindow else { return false }
        return !sceneID.isBorrowed
    }
}
#endif

// MARK: - LiveActivityPolicy

#if os(iOS)
/// Whether this process may show a Live Activity: any process but a test's.
///
/// ## Why a test's process shows none
/// The system opens the app in the background when one of its activities is dismissed and the
/// app is not running, and a test's app is seldom running by then: it is killed when its test
/// ends, often while it indexes. Two ways were measured, on iPhone 17 (iOS 27.0, simulator),
/// 2026-10-11, from the simulator's own log.
///
/// - **An activity nothing ended.** A UI test that taps Index Now passes once the rows are
///   drawn, and a unit run that takes a second ends while the host is still indexing a volume
///   it found at launch. The next `xcodebuild` run installs the app again, the system stops the
///   activity ("Stopping uninstalled activity"), and `liveactivitiesd` asks SpringBoard to open
///   the app.
/// - **An activity the app ended.** Its dismissal comes due three seconds later
///   (`endIndexingLiveActivity`), and the same request follows: twice out of two, 3.013 seconds
///   after the end, the host having exited.
///
/// A launch a test asks for while that background launch is starting is given its process,
/// which has none of the test's launch arguments and none of its environment: the onboarding
/// wizard, over the simulator's real store, with CloudKit set up. In an afternoon of 11
/// installs and 20 launches, three installs stopped an activity left over, and the launch after
/// each was the one that came up in the background (`BG-Active`) and showed onboarding, its
/// request 9 to 23 ms behind `liveactivitiesd`'s; the other 17 came up in front. The third was
/// made on purpose, by running `testIndexingFromTheCompilationFillsItsDocumentList` and then
/// another test in a new run. Each of the three tests failed in 12 to 15 seconds with "Could
/// not reach the 'Browse' tab".
///
/// So a unit test's host (`FigureImageStore.isUnitTestHost(_:)`) and a UI test's app
/// (`FRUS_UI_TEST_MODE`) start none. An activity left by something else — a build older than
/// this rule, or the app killed by hand while it indexed — still does it to the next run's first
/// test, once: `TabBarNavigator` names the cause when it meets the wizard.
///
/// Version history:
///   1.0 — 2026-10-11: initial implementation
enum LiveActivityPolicy {

    /// - Parameter environment: `ProcessInfo.processInfo.environment`.
    /// - Returns: Whether a Live Activity may be requested or updated from this process.
    static func mayShow(in environment: [String: String]) -> Bool {
        !FigureImageStore.isUnitTestHost(environment) && environment["FRUS_UI_TEST_MODE"] != "1"
    }
}
#endif

// MARK: - LiveActivityLifecycle

#if os(iOS)
/// The rules for the app's Live Activities: which of them are leftovers and when an update goes
/// stale (#1642); which one a run takes over, when the app may ask for one, and what one shows
/// (#1695).
///
/// ## What goes wrong without them
/// An activity is held in memory by the process that started it, and ended when its run reports
/// that it finished. When the app is killed while it indexes or summarizes (a force-quit, the
/// system reclaiming a suspended app, a crash) nothing ends the activity. Measured on an iPhone 17
/// simulator (iOS 27.0) on 2026-10-12, on the build before this type: the app was terminated a
/// second and a half into indexing a volume, and 2 minutes 43 seconds later, after a background
/// launch and a foreground one, the Lock Screen still read "Parsing…" under the volume's title.
/// With no stale date the system never marked the frozen activity either.
///
/// ## The two rules, the owner's decision of 2026-10-11
/// - **A leftover is ended at launch.** `isLeftover(_:driver:)` says which activities those are,
///   and `AppState.endLeftoverLiveActivities()` ends them.
/// - **Every update carries a stale date** (`staleDate(after:)`), so the system marks an activity
///   stale when the app stops updating it, and the widget then says that the work has stopped.
///   `AppState` sends the last state again every `keepAliveEvery` seconds while it holds an
///   activity, so the date passes only when the app has stopped running.
///
/// ## #1695's, the owner's decisions 63 and 64 and the plan of record's default for the rest
/// - **A run takes over only a live activity**, and none this process has asked to end
///   (`activityToTakeOver(_:among:ended:)`). With that, and the queue's end ending its activity
///   (`AppState.endIndexingBatch()`), one activity follows a whole indexing queue.
/// - **A request the system refused in a background run is not made again in that run**
///   (`RequestGate`).
/// - **What an activity shows** (`indexingState(for:catalogueTitle:queue:)`,
///   `summarizationState(tally:continuesInBackground:)`): the finishing merge is titled, seconds
///   left are rounded up, and a summarization run says whether it goes on in the background.
///
/// The type reads no system state and imports nothing of ActivityKit's but the state enum it
/// translates, so a unit test drives every rule here with values it makes.
///
/// Version history:
///   1.0 — 2026-10-12 (#1642): initial implementation
///   1.1 — 2026-10-20 (#1695): `activityToTakeOver(_:among:ended:)`, `RequestGate`, `Dismissal`,
///          and the state builders
enum LiveActivityLifecycle {

    // MARK: Stale dates

    /// How long after an update the system marks an activity stale, in seconds: two minutes,
    /// the soonest the system does it.
    ///
    /// Measured on the same simulator and day, from `liveactivitiesd`'s own schedule ("Marking
    /// activities stale"): a stale date 30 or 60 seconds after the update was scheduled at 120
    /// seconds, and one 180 or 600 seconds after was scheduled as asked. Each update moves the
    /// mark. So the app asks for the two minutes it would get anyway, and says two minutes where
    /// it describes this.
    static let staleAfter: TimeInterval = 120

    /// How often `AppState` sends an activity it holds its last state again, in seconds: four
    /// turns to a stale date, so three may be late or lost before a running app's activity reads
    /// as stopped.
    static let keepAliveEvery: TimeInterval = 30

    /// The stale date for an update sent at `now`.
    static func staleDate(after now: Date) -> Date {
        now.addingTimeInterval(staleAfter)
    }

    // MARK: Leftovers

    /// Where the system has an activity, as far as the leftover rule cares.
    enum Phase: Equatable, Sendable {
        /// Shown, and still taking updates. A stale activity is live: an update makes it current
        /// again.
        case live
        /// Ended, and still on the Lock Screen until its dismissal comes due. No update reaches it.
        case ended
        /// Removed from the screen.
        case dismissed
    }

    /// One of the app's activities as the system lists it.
    struct Listed: Equatable, Sendable {
        /// The system's id for the activity.
        let id: String
        /// The kind of job it shows.
        let kind: LiveActivityJobKind
        /// Where the system has it.
        let phase: Phase
    }

    /// What this process is doing with Live Activities.
    struct Driver: Equatable, Sendable {
        /// The ids of the activities this process requested or took over, those it has since ended
        /// included.
        var driven: Set<String> = []
        /// The kinds whose run is under way here, or has been decided on and not yet begun: such a
        /// run takes over a live activity of its kind at its first update.
        var running: Set<LiveActivityJobKind> = []
        /// Whether this process may show an activity at all: `LiveActivityPolicy`, the reader's
        /// own switch, and the system's. A run in a process that may not show one takes none over.
        var mayShow = true
    }

    /// Whether `activity` is a leftover: one the system still shows, which this process neither
    /// started nor took over, and which no run here is about to take over.
    ///
    /// - An activity already dismissed is no leftover. Nothing of it is on the screen.
    /// - An activity this process drove is its own, for as long as it shows. That includes the
    ///   three seconds a finished run's activity lingers, which a sweep must not cut short.
    /// - A live activity of a kind whose run is under way or due here is spared, because that run
    ///   takes it over at its first update: the pass a launch resumes keeps the last process's
    ///   activity and goes on updating it. An ended one is not spared, since no update reaches it,
    ///   and neither is one in a process that may not show an activity, since its run takes none.
    static func isLeftover(_ activity: Listed, driver: Driver) -> Bool {
        guard activity.phase != .dismissed, !driver.driven.contains(activity.id) else { return false }
        let aRunHereTakesItOver = activity.phase == .live
            && driver.mayShow
            && driver.running.contains(activity.kind)
        return !aRunHereTakesItOver
    }

    // MARK: Taking one over (#1695)

    /// The activity a run of `kind` takes over in place of asking for one: the first live
    /// activity of its kind that this process has not asked the system to end.
    ///
    /// - **Live only.** An ended activity takes no update, and the system lists it until its
    ///   dismissal comes due. Before #1695 a run took the first of its kind the system listed, and
    ///   in a queue whose activity was ended as each volume finished, a volume that started within
    ///   the three seconds that activity lingered took it over and showed nothing: measured on
    ///   2026-10-12 (iPhone 17 simulator, iOS 27.0), of three volumes in one launch pass the
    ///   first and third had an activity and the second none.
    /// - **None this process has asked to end**, its own or a leftover (`ended`): the end takes a
    ///   moment to land, and until it does the system still lists the activity as live.
    /// - **A live one an earlier process left is taken**: the pass a launch resumes keeps the
    ///   last process's activity and goes on updating it (#1642).
    static func activityToTakeOver(_ kind: LiveActivityJobKind, among listed: [Listed],
                                   ended: Set<String>) -> String? {
        listed.first { $0.kind == kind && $0.phase == .live && !ended.contains($0.id) }?.id
    }

    // MARK: Asking for one (#1695)

    /// Whether the app may ask the system for an activity: not again in a background run once
    /// the system has refused one in it.
    ///
    /// The system starts no activity for an app in the background. Before #1695 a run there asked
    /// again at every progress update, up to ten times a second, and was refused each time: six
    /// times in the launch #1642's session measured. A background run ends when the app is next
    /// in the foreground, where a request may be made again. A refusal in the foreground closes
    /// nothing.
    struct RequestGate: Equatable, Sendable {
        /// Whether the system has refused a request since the app was last in the foreground.
        private(set) var refusedInBackground = false

        /// Whether a request may be made now. Being in the foreground opens the gate again.
        mutating func mayRequest(inForeground: Bool) -> Bool {
            if inForeground { refusedInBackground = false }
            return !refusedInBackground
        }

        /// Records that the system refused a request.
        mutating func noteRefusal(inForeground: Bool) {
            if !inForeground { refusedInBackground = true }
        }
    }

    // MARK: Ending one

    /// How an ended activity leaves the screen.
    enum Dismissal: Equatable, Sendable {
        /// At once: a leftover's end (#1642). A dismissal that comes due after the app has gone
        /// makes the system open the app again in the background (`LiveActivityPolicy`).
        case immediately
        /// After `lingerAfterEnd` seconds, so that the finished state is seen first: the end of
        /// this process's own queue or run.
        case afterLinger
    }

    /// How long a finished queue's or run's activity stays on the screen after it ends, in
    /// seconds.
    static let lingerAfterEnd: TimeInterval = 3

    // MARK: What an activity shows (#1695)

    /// What an indexing activity shows for `update`.
    ///
    /// - **The title** is the volume's (`catalogueTitle`, or its id when the catalogue has none),
    ///   and *Finalizing index…* for an update that names no volume: the merge that ends a
    ///   whole-library pass, and the rebuild from the cache. Its title had been empty.
    /// - **The seconds left** are rounded up (`secondsLeft(of:)`).
    /// - **A finished volume** (`.complete`) shows its bar full and no seconds left, with the
    ///   queue's count of volumes done in `queue`.
    ///
    /// - Parameter queue: Where the queue stands, or `nil` for a queue of one volume.
    static func indexingState(for update: IndexingProgressUpdate, catalogueTitle: String?,
                              queue: (current: Int, total: Int)?) -> IndexingActivityAttributes.ContentState {
        let title = update.volumeId.isEmpty
            ? String(localized: "liveactivity.optimizing", defaultValue: "Finalizing index…")
            : catalogueTitle ?? update.volumeId
        // A finished volume is full, one with no documents included, which would otherwise read
        // as not yet counted ("Parsing…").
        let fraction: Double? = update.stage == .complete ? 1
            : update.totalDocuments > 0 ? Double(update.completedDocuments) / Double(update.totalDocuments)
            : nil
        return IndexingActivityAttributes.ContentState(
            kind: .indexing,
            volumeTitle: title,
            progressFraction: fraction,
            etaSeconds: secondsLeft(of: update),
            completedDocuments: update.completedDocuments,
            totalDocuments: update.totalDocuments,
            isOptimizing: update.stage == .optimizing,
            queueCurrent: queue?.current,
            queueTotal: queue?.total
        )
    }

    /// The seconds `update`'s volume has left at its rate, rounded up, or `nil` when there is no
    /// rate or nothing left.
    ///
    /// Rounded up, because a volume takes a few seconds: cut down to a whole second, as before
    /// #1695, the count read "~0s" for most of one. The widget prints none under
    /// `IndexingActivityAttributes.ContentState.fewestSecondsShown`.
    static func secondsLeft(of update: IndexingProgressUpdate) -> Int? {
        guard update.docsPerSecond > 0, update.totalDocuments > update.completedDocuments else { return nil }
        let seconds = (Double(update.totalDocuments - update.completedDocuments) / update.docsPerSecond).rounded(.up)
        guard seconds.isFinite, seconds < Double(Int.max) else { return nil }
        return Int(seconds)
    }

    /// What a summarization run's activity shows: its documents done of those it will send to the
    /// model, and whether it goes on by itself in the background (decision 64), which the activity
    /// says once the app has stopped updating it.
    static func summarizationState(tally: BatchRunTally,
                                   continuesInBackground: Bool) -> IndexingActivityAttributes.ContentState {
        let processed = tally.finished
        let total = tally.attemptable
        return IndexingActivityAttributes.ContentState(
            kind: .summarizing,
            volumeTitle: String(localized: "liveactivity.summarizing.title",
                                defaultValue: "Summarizing FRUS documents"),
            progressFraction: total > 0 ? Double(processed) / Double(total) : nil,
            etaSeconds: nil,
            completedDocuments: processed,
            totalDocuments: total,
            isOptimizing: false,
            queueCurrent: nil,
            queueTotal: nil,
            continuesInBackground: continuesInBackground
        )
    }
}

extension LiveActivityLifecycle.Phase {

    /// The phase the system's state for an activity stands for.
    ///
    /// Stale is live, as above. So is pending, an activity scheduled to start, which the app
    /// never makes: one that nothing drives should not be left to start. A state this build does
    /// not know is read the same way, so that an activity in it is ended and not kept.
    init(_ state: ActivityState) {
        switch state {
        case .active, .stale, .pending: self = .live
        case .ended: self = .ended
        case .dismissed: self = .dismissed
        @unknown default: self = .live
        }
    }
}

extension LiveActivityLifecycle.Listed {

    /// `activity` as the leftover rule reads it.
    init(_ activity: Activity<IndexingActivityAttributes>) {
        self.init(id: activity.id,
                  kind: activity.content.state.resolvedKind,
                  phase: LiveActivityLifecycle.Phase(activity.activityState))
    }
}

// MARK: - LiveActivityHosting

/// What `AppState` asks of ActivityKit for its Live Activities (#1695): the system's activities
/// in the app (`SystemLiveActivityHost`), or a stand-in a unit test sets.
///
/// ## Why a seam
/// A test's process may show no activity (`LiveActivityPolicy`), so until #1695 the calls into
/// ActivityKit could be checked only by reading the source. What a queue's activity does across
/// its volumes (one request, an update for each volume, one end with the queue), which activity a
/// run takes over, and how often a refused request is made again were out of a test's reach.
/// Through this a unit test drives `AppState`'s own code with a real pipeline and reads what it
/// asked for. What the system does with those requests no stand-in can vouch for: it was measured
/// on a simulator, and the session entry of 2026-10-20 in `Planning/DEVELOPMENT-PLAN.md` says
/// what was seen.
///
/// It speaks in ids and `LiveActivityLifecycle.Listed`, the rules' own values, so a stand-in
/// needs nothing of ActivityKit's but the content state.
///
/// Version history:
///   1.0 — 2026-10-20 (#1695): initial implementation
@MainActor
protocol LiveActivityHosting: AnyObject {
    /// Whether this process may show an activity at all: `LiveActivityPolicy`, then the system's
    /// switch for the app. The reader's own switch is `AppState`'s to read.
    var mayShow: Bool { get }
    /// Whether the app is in the foreground, the only place the system starts an activity.
    var isInForeground: Bool { get }
    /// The app's activities as the system lists them, ended ones included.
    func listedActivities() -> [LiveActivityLifecycle.Listed]
    /// Asks the system for an activity showing `state`. Returns its id, or `nil` when the system
    /// refuses.
    func request(showing state: IndexingActivityAttributes.ContentState) -> String?
    /// Sends `state` to the activity `id`.
    func update(_ id: String, to state: IndexingActivityAttributes.ContentState)
    /// Ends the activity `id`, which leaves the screen as `dismissal` says.
    func end(_ id: String, dismissal: LiveActivityLifecycle.Dismissal)
}

/// The system's Live Activities, through ActivityKit: what `AppState` uses outside a unit test.
///
/// It asks `LiveActivityPolicy` before it reports that it may show one and again before it makes
/// a request, so a test's process asks the system for nothing, whatever its caller does. Listing
/// and ending ask nothing: the launch's sweep runs in every process and can only remove (#1642).
///
/// Every content it gives an activity carries a stale date two minutes out (`content(_:)`, the one
/// place the app builds one, #1642). Updates and ends go out on tasks of their own, as they did
/// before this type: the app does not wait on ActivityKit.
///
/// Version history:
///   1.0 — 2026-10-20 (#1695): initial implementation, from `AppState`'s own calls
@MainActor
final class SystemLiveActivityHost: LiveActivityHosting {

    /// The activities this host has requested or listed, by id, so that an update reaches one
    /// the system has not listed yet.
    private var known: [String: Activity<IndexingActivityAttributes>] = [:]

    var mayShow: Bool {
        // The policy first: a test's process asks the system nothing.
        LiveActivityPolicy.mayShow(in: ProcessInfo.processInfo.environment)
            && ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isInForeground: Bool {
        UIApplication.shared.applicationState != .background
    }

    func listedActivities() -> [LiveActivityLifecycle.Listed] {
        Activity<IndexingActivityAttributes>.activities.map { activity in
            known[activity.id] = activity
            return LiveActivityLifecycle.Listed(activity)
        }
    }

    func request(showing state: IndexingActivityAttributes.ContentState) -> String? {
        guard LiveActivityPolicy.mayShow(in: ProcessInfo.processInfo.environment) else { return nil }
        guard let activity = try? Activity.request(attributes: IndexingActivityAttributes(),
                                                   content: Self.content(state)) else { return nil }
        known[activity.id] = activity
        return activity.id
    }

    func update(_ id: String, to state: IndexingActivityAttributes.ContentState) {
        guard let activity = activity(id) else { return }
        Task { @MainActor in
            await activity.update(Self.content(state))
        }
    }

    func end(_ id: String, dismissal: LiveActivityLifecycle.Dismissal) {
        guard let activity = activity(id) else { return }
        known[id] = nil
        let policy: ActivityUIDismissalPolicy = switch dismissal {
        case .immediately: .immediate
        case .afterLinger: .after(.now + LiveActivityLifecycle.lingerAfterEnd)
        }
        Task { @MainActor in
            await activity.end(nil, dismissalPolicy: policy)
        }
    }

    /// The activity `id`, from those this host knows or the system's list.
    private func activity(_ id: String) -> Activity<IndexingActivityAttributes>? {
        known[id] ?? Activity<IndexingActivityAttributes>.activities.first { $0.id == id }
    }

    /// `state` as an activity's content, to go stale `LiveActivityLifecycle.staleAfter` seconds
    /// from now unless another update follows. The one place the app builds an activity's content.
    private static func content(
        _ state: IndexingActivityAttributes.ContentState
    ) -> ActivityContent<IndexingActivityAttributes.ContentState> {
        ActivityContent(state: state, staleDate: LiveActivityLifecycle.staleDate(after: Date()))
    }
}
#endif
