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

    /// Real-time CloudKit sync state, updated by observing
    /// `NSPersistentCloudKitContainer.eventChangedNotification`.
    ///
    /// `.unknown` at startup; transitions to `.syncing` when an import or export begins,
    /// `.succeeded` when it completes cleanly, or `.failed` when it errors. A `.failed`
    /// state surfaces the error message in the macOS status bar and iOS Settings so
    /// developers and users can see exactly what is preventing data from syncing.
    var cloudKitSyncState: CloudKitSyncState = .unknown

    /// True once the first CloudKit **import** has finished this launch, so the local `Project`
    /// store is stable. Until then the macOS "Switch Project" menu shows a "Syncing…" placeholder
    /// instead of a list that would churn/reshuffle as records arrive one batch at a time — a native
    /// menu handles live content mutation poorly, which made the menu hard to use during the initial
    /// sync of a fresh launch. Session-only (not persisted): a relaunch re-shows the placeholder only
    /// while its own import runs, and an already-synced launch (no import work) never shows it because
    /// the sync state never reaches `.syncing`. (#377 Phase 5)
    var hasInitialProjectSyncSettled = false

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
    /// `nil` = not yet verified; `true` = zone found and sync should work;
    /// `false` = zone missing — records cannot be uploaded or downloaded until
    /// NSPersistentCloudKitContainer recreates it (typically on next cold launch).
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
    /// `cloudKitAccountStatus`, `cloudKitZoneVerified`, and (on failure) `cloudKitSyncState`.
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
                    cloudKitSyncState = .failed(Self.accountStatusDescription(status))
                    cloudKitLog.notice("account status not available: \(status.rawValue, privacy: .public)")
                    Task { await SyncDiagnosticsLog.shared.record(
                        phase: "account", startDate: nil, endDate: Date.now, succeeded: false,
                        errorCodeName: "accountStatus(\(status.rawValue))") }
                }
            } catch {
                let ns = error as NSError
                cloudKitLog.error("account status check failed: \(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)")
                Task { await SyncDiagnosticsLog.shared.record(
                    phase: "account", startDate: nil, endDate: Date.now, succeeded: false,
                    errorDomain: ns.domain, errorCode: ns.code) }
            }

            // ── Private zone verification ────────────────────────────────────────
            do {
                let zones = try await container.privateCloudDatabase.allRecordZones()
                cloudKitZoneVerified = zones.contains { $0.zoneID.zoneName == Self.ckZoneName }
                if cloudKitZoneVerified == false {
                    cloudKitLog.notice("private zone not found — records will not sync until recreated")
                    Task { await SyncDiagnosticsLog.shared.record(
                        phase: "zone", startDate: nil, endDate: Date.now, succeeded: false) }
                } else {
                    Task { await SyncDiagnosticsLog.shared.record(
                        phase: "zone", startDate: nil, endDate: Date.now, succeeded: true) }
                }
            } catch {
                cloudKitZoneVerified = false
                let ns = error as NSError
                cloudKitLog.error("zone verification failed: \(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)")
                Task { await SyncDiagnosticsLog.shared.record(
                    phase: "zone", startDate: nil, endDate: Date.now, succeeded: false,
                    errorDomain: ns.domain, errorCode: ns.code) }
            }
        }
    }

    /// Human-readable description of a `CKAccountStatus` value for display and logging.
    static func accountStatusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .noAccount:
            return String(localized: "cloudkit.account.noAccount",
                          defaultValue: "Not signed in to iCloud — notes, highlights, and collections won't sync. Sign in via Settings → Apple ID.")
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

    // MARK: - Download Queue

    /// Volume IDs currently queued for download (active + pending).
    ///
    /// Updated by `DownloadManager` via its `onStateChanged` callback. Views observe
    /// this to show download indicators without calling into the actor directly.
    var downloadQueue: [String] = []

    // MARK: - Person Corrections Signal

    /// Bumped after every person-cluster correction (merge / separate / undo) once the
    /// rollup has re-consolidated, so any People surface can refresh reactively via
    /// `.onChange` — the live-signal pattern this codebase prefers over navigation- or
    /// scene-phase-triggered reloads (Session 4 / #243). The value itself is meaningless;
    /// only changes matter.
    var personCorrectionsGeneration: Int = 0

    // MARK: - Tag Stores

    /// Resolves volume-level tag slugs and provides volume-by-tag queries.
    /// Loaded synchronously from `volume-tag-taxonomy.json` and `manifest.json` at init.
    let volumeLevelTagStore: VolumeLevelTagStore = VolumeLevelTagStore()

    /// Loads and merges the volume manifest. Loaded from bundle at init; live data fetched at boot.
    var manifestStore: ManifestStore = ManifestStore()

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
    /// research trail routes through it — `logEvent(_:defaults:)`,
    /// `DocumentViewModel.recordReadingHistory(projectId:in:defaults:)`,
    /// `MacSearchViewModel.recordSearchHistory(projectId:in:defaults:)` and its iOS counterpart
    /// `SearchViewModel.recordSearchHistory(projectId:in:defaults:)` — so the switch cannot
    /// govern one recorder and miss another, which is exactly what it did before Wave R-1:
    /// the gate lived inline in `logEvent` and the two history stores had no gate at all.
    /// Wave R-4's iOS search writer was gated from its first commit for the same reason: an
    /// ungated one would have started collecting search text on a platform that was not.
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

    // MARK: - Research Session Logging

    /// `ModelContext` used exclusively for writing `ResearchSession` and `SessionEvent`
    /// records. Set at boot by `FRUSExplorerApp`; `nil` until boot completes.
    /// Callers do not need to interact with this directly — use `logEvent(_:)`.
    var loggingContext: ModelContext?

    /// In-memory handle to the current open research session.
    /// `nil` at launch; replaced when the previous session expires.
    private var currentResearchSession: ResearchSession?

    /// Timestamp of the last logged event; used to detect session expiry.
    private var lastEventDate: Date?

    /// After this many seconds of inactivity a new `ResearchSession` is started.
    static let sessionExpiryInterval: TimeInterval = 30 * 60

    /// Logs a research event, creating or reusing a `ResearchSession` automatically.
    ///
    /// Fire-and-forget: callers need not `await` or wrap in a `Task`. All writes
    /// are synchronous on the main actor. No-op until `loggingContext` is wired at boot.
    ///
    /// Session lifecycle:
    /// - If no session is open, a new `ResearchSession` is inserted and becomes current.
    /// - If the last event was more than `sessionExpiryInterval` ago, the previous
    ///   session is closed (`endedAt` stamped) and a fresh session is created.
    ///
    /// - Parameters:
    ///   - kind: The event to record.
    ///   - defaults: The store the research-logging gate is read from. Defaults to
    ///     `.standard`; overridden only by tests, so the gate can be exercised without
    ///     mutating process-wide state.
    func logEvent(_ kind: ResearchEventKind, defaults: UserDefaults = .standard) {
        guard Self.isResearchLoggingEnabled(in: defaults) else { return }
        guard let ctx = loggingContext else { return }
        let now = Date.now

        // Expire idle session.
        if let session = currentResearchSession,
           let last = lastEventDate,
           now.timeIntervalSince(last) > Self.sessionExpiryInterval {
            session.endedAt = last
            currentResearchSession = nil
        }

        // Open a new session when needed.
        if currentResearchSession == nil {
            let session = ResearchSession(startedAt: now)
            ctx.insert(session)
            currentResearchSession = session
        }

        guard let session = currentResearchSession else { return }

        let order = session.events?.count ?? 0
        let event = SessionEvent(
            sessionId: session.id,
            timestamp: now,
            kind: kind,
            sortOrder: order
        )
        event.session = session
        ctx.insert(event)
        lastEventDate = now

        #if DEBUG
        print("[ResearchSession] Logged \(kind.typeString)")
        #endif
    }

    /// The shared cross-reference store. Created at boot alongside `indexingPipeline`;
    /// `nil` if the database could not be opened.
    var crossReferenceStore: CrossReferenceStore?

    /// The shared person mention store. Created at boot alongside `crossReferenceStore`;
    /// `nil` if the database could not be opened.
    var personMentionStore: PersonMentionStore?

    /// The shared printed-page lookup store (page_ranges table). Created at boot;
    /// used by document views to resolve printed-page cross-references
    /// (`#pg_313`) to their containing document (Session 162). `nil` if the
    /// database could not be opened.
    var pageRangeStore: PageRangeStore?

    /// Bumped each time `refreshReadOnlyStores` reopens the read-only stores after an index
    /// rebuild. Dashboards that read those stores (`CrossReferenceAnalyticsView`,
    /// `PersonAnalyticsView`) observe this and reload, so a view already on screen when a reindex
    /// finishes refreshes instead of showing the empty results a stale connection returns (#275).
    var readOnlyStoresGeneration: Int = 0

    /// The `frus.db` URL, set at boot alongside the read-only stores. Retained so any in-session
    /// index rebuild (Settings "Reindex All" / "Rebuild Index", boot reindex) can reopen the stores
    /// against it via `refreshReadOnlyStores()` (#275).
    var databaseURL: URL?

    /// The downloaded-volumes directory, set at boot. Retained so `refreshReadOnlyStores()` can
    /// recompute the citation engine's downloaded-volume set after a rebuild.
    var volumesDirectory: URL?

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
    func refreshReadOnlyStores() {
        guard let databaseURL else { return }
        crossReferenceStore = try? CrossReferenceStore(databaseURL: databaseURL)
        personMentionStore = try? PersonMentionStore(databaseURL: databaseURL)
        let freshPageRangeStore = try? PageRangeStore(databaseURL: databaseURL)
        pageRangeStore = freshPageRangeStore
        // The citation engine captures the page-range store by value, so recreating the store on
        // `AppState` alone would leave the engine holding the stale connection; rebuild it too.
        if let searchService, let volumesDirectory {
            let downloadedIds = Set(
                (try? FileManager.default.contentsOfDirectory(
                    at: volumesDirectory, includingPropertiesForKeys: nil
                ).map { $0.deletingPathExtension().lastPathComponent }) ?? []
            )
            citationMatchingEngine = CitationMatchingEngine(
                manifestStore: manifestStore,
                searchService: searchService,
                pageRangeStore: freshPageRangeStore,
                downloadedVolumeIds: downloadedIds
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

    /// One-shot hand-off for the second-project nudge (#377 Phase 5): the id of a project the
    /// researcher just created that brought their project count to ≥ 2. Set by
    /// `ProjectEditorView.saveProject`; the nudge host (iOS `MainTabView` / macOS Settings) presents
    /// a one-time "open Project Home?" prompt for it and clears it. Transient (never persisted) —
    /// the *once-only* gate is the `@AppStorage("frus.hasShownSecondProjectNudge")` flag at the host.
    var pendingSecondProjectNudge: UUID? = nil

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

    /// Cross-platform hand-off channel for opening a document from any tool surface. On **iOS**
    /// `BrowserView` observes it and appends to the Browse tab's path. On **macOS** every
    /// producer now routes directly through `openDocument(_:from:mintWindow:)` (provenance
    /// PR 2), so the only remaining macOS writer is `unregisterHost`'s demotion of an
    /// in-flight `routedBrowse` whose target closed with no surviving host — the hosts'
    /// observers + `onAppear` drains (`routeLegacyPendingBrowse`) stay as its delivery
    /// mechanism, re-resolving the value when the next host mounts.
    ///
    /// Scene-addressed (#338 step 4): iOS producers target the producing window's `\.sceneID` (only
    /// that window's `BrowserView` consumes), so a document hand-off no longer fans out across iPad
    /// windows; the macOS demotion targets `.macLegacyBrowse`, which `routeLegacyPendingBrowse` drains.
    var pendingBrowseDocument: Handoff<DocumentBrowserEntry>? = nil

    // MARK: Window routing — provenance model (macOS; Planning/Window-Routing-Provenance.md)

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
    var liveSceneIDs: Set<SceneID> = []

    /// The raw `\.sceneID` of the window currently launching a value-based auxiliary window (Archival
    /// Neighbors / Related Documents). Set by the launcher immediately before `openWindow(value:)` and
    /// drained by the aux window's `.onAppear` into its own state, so the aux window knows which main
    /// window opened it. Transient (never persisted) — a restored aux window reads nil and falls back
    /// to `.anyWindow`. #338 aux-window origin.
    var pendingAuxWindowOriginRaw: String? = nil

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
    /// selection bar's "Look up in NARA" action), which sets this immediately before
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
    /// guide — `openWindow(id: "frus.researchGuide")` on macOS, or navigating
    /// to `ResearchGuideView` on iOS — so the guide opens pre-scrolled to the
    /// topic the user asked about. `ResearchGuideView` reads and clears it.
    var researchGuideInitialPageId: String? = nil

    /// Controls presentation of the standalone "Research Guide" sheet on iOS,
    /// reachable from Settings independently of the indexing flow.
    var showResearchGuide: Bool = false

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

    /// The most recent per-document indexing progress update, or `nil` when no
    /// indexing is in progress.
    ///
    /// Populated by `connectIndexingProgress(pipeline:)` which subscribes to
    /// `IndexingPipeline.progressStream`. Views observe this to render live
    /// indexing indicators (iOS: inline capsule in VolumeRowLabel; macOS: StatusBarView).
    ///
    /// Version history:
    ///   1.0 — Session 51: initial implementation (iOS only)
    ///   1.1 — New UI scaffolding: promoted to cross-platform for macOS StatusBarView
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
    /// in `connectIndexingProgress` when a volume's `.complete` event fires.
    ///
    /// Replaces per-call `IndexingPipeline.isVolumeIndexed()` lookups from view bodies
    /// (which previously fired SQLite queries on every SwiftUI render pass — up to 10×/s
    /// during indexing — saturating the main thread and making the education sheet laggy).
    var indexedVolumeIds: Set<String> = []

    // MARK: - Live Activity (iOS only)

    #if os(iOS)
    /// The currently-running indexing Live Activity, or `nil` when idle.
    ///
    /// Started by `startIndexingLiveActivity` when indexing begins and ended by
    /// `endIndexingLiveActivity` on `.complete`. Managed entirely within
    /// `connectIndexingProgress` so the lifecycle mirrors the progress stream.
    private var indexingActivity: Activity<IndexingActivityAttributes>?

    /// The currently-running summarization Live Activity, or `nil` when idle.
    /// Driven by `backgroundSummarizationProgress` via `syncSummarizationLiveActivity`.
    /// Started only while the app is foreground (ActivityKit forbids starting one
    /// from the background); a foreground-started run's activity then persists and
    /// updates when the app next becomes active.
    private var summarizationActivity: Activity<IndexingActivityAttributes>?
    #endif

    // MARK: - Queue tracking (Session 116)

    /// Number of volumes that have completed indexing in the current batch session.
    ///
    /// Reset at the start of each new batch. Used to compute `indexingQueuePosition.current`.
    private var indexingBatchCompletedCount: Int = 0

    /// The total number of volumes estimated at the start of the current batch.
    ///
    /// Captured as `downloadQueue.count + 1` when the first volume of a new batch begins
    /// indexing. Stays fixed for the duration of the batch (does not shrink as downloads
    /// complete) so the denominator in "Volume 3 of 12" remains stable.
    private var indexingBatchTotalAtStart: Int = 0

    /// Timestamp of the most recent `.complete` event. Used to distinguish a batch
    /// continuation (brief nil gap between volumes) from a fresh start (long idle period
    /// or empty queue).
    private var lastIndexingCompletionTime: Date? = nil

    /// Rolling mean throughput across completed volumes in the current batch (docs/s).
    ///
    /// Updated on each `.complete` event. Used by `IndexingQueueBannerView` to estimate
    /// ETA for remaining queued volumes.
    var indexingQueueAverageDocsPerSecond: Double = 0

    /// Rolling mean document count across completed volumes in the current batch.
    ///
    /// Falls back to 600 (approximate corpus mean) until at least one volume completes.
    var indexingQueueAverageDocumentCount: Int = 600

    /// The current volume's position within a multi-volume download-and-index batch.
    ///
    /// Returns `nil` when only one volume is in flight (single-volume mode) or when
    /// the current batch was not triggered by a download queue (e.g. manual reindex).
    /// `current` is 1-based. Used to drive `IndexingQueueBannerView`.
    ///
    /// Version history:
    ///   1.0 — Session 116: initial implementation
    var indexingQueuePosition: (current: Int, total: Int)? {
        guard currentIndexingProgress != nil, indexingBatchTotalAtStart >= 2 else { return nil }
        return (current: indexingBatchCompletedCount + 1, total: indexingBatchTotalAtStart)
    }

    /// Volume titles for the volumes currently waiting in the download queue, in order.
    ///
    /// Resolved from `manifestStore`; falls back to `volumeId` when the manifest has no entry.
    /// Used by `IndexingQueueBannerView`'s expanded pending-list section.
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
    /// the SwiftUI render loop.  Called once at boot after the pipeline is created.
    func seedIndexedVolumeIds(pipeline: IndexingPipeline) {
        Task.detached(priority: .utility) { [weak self] in
            let ids = (try? pipeline.allIndexedVolumeIds()) ?? []
            await MainActor.run { [weak self] in self?.indexedVolumeIds = ids }
        }
    }

    /// Subscribes to `pipeline.progressStream` and `pipeline.metadataStream`, forwarding
    /// updates onto the main actor as `currentIndexingProgress`, `lastDiscoveredMetadata`,
    /// and `completedIndexingMetadata`.
    ///
    /// Safe to call multiple times — each call replaces the previous subscription
    /// (the prior Tasks are abandoned; streams are single-consumer by design).
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
                    self.indexedVolumeIds.insert(update.volumeId)
                    // The volume just became locally available — teach the citation
                    // matching engine about it. Its downloaded-volume set is otherwise
                    // a boot-time snapshot, which broke the "download this volume,
                    // then resolve again" loop advertised by CitationLookupView and
                    // the collections Add Documents sheet until the next relaunch.
                    if let engine = self.citationMatchingEngine {
                        let completedVolumeId = update.volumeId
                        Task { await engine.noteVolumeDownloaded(completedVolumeId) }
                    }
                    self.lastIndexingCompletionTime = Date()
                    self.indexingBatchCompletedCount += 1
                    // Update rolling throughput average (Welford online mean).
                    if update.docsPerSecond > 0 {
                        let n = Double(self.indexingBatchCompletedCount)
                        self.indexingQueueAverageDocsPerSecond +=
                            (update.docsPerSecond - self.indexingQueueAverageDocsPerSecond) / n
                    }
                    // Update rolling document-count average.
                    if let meta = self.completedIndexingMetadata, meta.totalDocuments > 0 {
                        let n = Double(self.indexingBatchCompletedCount)
                        self.indexingQueueAverageDocumentCount = Int(
                            Double(self.indexingQueueAverageDocumentCount) +
                            (Double(meta.totalDocuments) - Double(self.indexingQueueAverageDocumentCount)) / n
                        )
                    }
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
                    self.endIndexingLiveActivity()
                    // The index just changed, invalidating the corpus word cloud's
                    // on-disk cache. Queue a background precompute so the next time
                    // the user opens the corpus cloud it's already warm.
                    WordCloudPrecomputeQueue.enqueue(WordCloudScope.corpus.signature)
                    #endif
                } else {
                    let isNewVolume = self.currentIndexingProgress?.volumeId != update.volumeId
                    let isStageTransition = update.stage == .optimizing
                    let elapsed = Date().timeIntervalSince(lastForwardedAt)
                    guard isNewVolume || isStageTransition || elapsed >= 0.1 else { continue }
                    lastForwardedAt = Date()
                    if isNewVolume {
                        self.lastDiscoveredMetadata = nil
                    }
                    if self.currentIndexingProgress == nil {
                        // Transitioning from idle: decide whether this is a new batch or a
                        // batch continuation (brief nil gap between sequential volumes).
                        // A gap > 30 s or an empty download queue signals a fresh start.
                        let gap = self.lastIndexingCompletionTime
                            .map { Date().timeIntervalSince($0) } ?? Double.infinity
                        if gap > 30 || self.downloadQueue.isEmpty {
                            self.indexingBatchCompletedCount = 0
                            self.indexingBatchTotalAtStart = self.downloadQueue.count + 1
                            self.indexingQueueAverageDocsPerSecond = 0
                            self.indexingQueueAverageDocumentCount = 600
                        }
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
    /// Starts a new Live Activity or updates the running one to reflect `update`.
    ///
    /// Creates the activity on the first call when `indexingActivity == nil`.
    /// Subsequent calls update the existing activity's `ContentState` in place so
    /// the Dynamic Island does not flicker between volumes in a multi-volume batch.
    ///
    /// On app restart `indexingActivity` resets to `nil` even when an activity is
    /// still running. To prevent a second widget appearing, the else-branch checks
    /// `Activity<IndexingActivityAttributes>.activities` before calling `request(…)`.
    ///
    /// Checks `SettingsKeys.liveActivityEnabled` (default on, Session 154) before
    /// requesting or updating an activity; when the user has turned the preference
    /// off, any already-running activity is ended instead.
    private func syncIndexingLiveActivity(update: IndexingProgressUpdate) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let liveActivityEnabled = (UserDefaults.standard.object(forKey: SettingsKeys.liveActivityEnabled) as? Bool) ?? true
        guard liveActivityEnabled else {
            endIndexingLiveActivity()
            return
        }
        let title = manifestStore.entry(forVolumeId: update.volumeId)?.title ?? update.volumeId
        let qp = indexingQueuePosition
        let fraction: Double? = update.totalDocuments > 0
            ? Double(update.completedDocuments) / Double(update.totalDocuments)
            : nil
        let eta: Int? = {
            guard update.docsPerSecond > 0, update.totalDocuments > update.completedDocuments else { return nil }
            return Int(Double(update.totalDocuments - update.completedDocuments) / update.docsPerSecond)
        }()
        let state = IndexingActivityAttributes.ContentState(
            kind: .indexing,
            volumeTitle: title,
            progressFraction: fraction,
            etaSeconds: eta,
            completedDocuments: update.completedDocuments,
            totalDocuments: update.totalDocuments,
            isOptimizing: update.stage == .optimizing,
            queueCurrent: qp?.current,
            queueTotal: qp?.total
        )
        if let running = indexingActivity {
            Task { @MainActor in
                await running.update(ActivityContent(state: state, staleDate: nil))
            }
        } else {
            // Adopt an existing activity that survived app restart before creating a
            // new one. `indexingActivity` is in-memory only — after a relaunch it is
            // nil even if a Live Activity widget is still displayed on the Dynamic
            // Island. Without this check, each `syncIndexingLiveActivity` call during
            // an in-progress index run after app restart spawns an additional widget.
            if let existing = Activity<IndexingActivityAttributes>.activities
                .first(where: { $0.content.state.resolvedKind == .indexing }) {
                indexingActivity = existing
                Task { @MainActor in
                    await existing.update(ActivityContent(state: state, staleDate: nil))
                }
            } else {
                indexingActivity = try? Activity.request(
                    attributes: IndexingActivityAttributes(),
                    content: ActivityContent(state: state, staleDate: nil)
                )
            }
        }
    }

    /// Ends the running Live Activity with a 3-second dismissal delay so the completion
    /// state is visible on the Dynamic Island before it disappears.
    private func endIndexingLiveActivity() {
        guard let activity = indexingActivity else { return }
        indexingActivity = nil
        Task { @MainActor in
            await activity.end(nil, dismissalPolicy: .after(.now + 3))
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

    /// Starts/updates/ends the summarization Live Activity from the current progress
    /// state. Mirrors `syncIndexingLiveActivity` but for the on-device summarizer.
    private func syncSummarizationLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let liveActivityEnabled = (UserDefaults.standard.object(forKey: SettingsKeys.liveActivityEnabled) as? Bool) ?? true

        switch backgroundSummarizationProgress.state {
        case let .running(processed, total, _):
            guard liveActivityEnabled else { endSummarizationLiveActivity(); return }
            let fraction: Double? = total > 0 ? Double(processed) / Double(total) : nil
            let content = IndexingActivityAttributes.ContentState(
                kind: .summarizing,
                volumeTitle: String(localized: "liveactivity.summarizing.title",
                                    defaultValue: "Summarizing FRUS documents"),
                progressFraction: fraction,
                etaSeconds: nil,
                completedDocuments: processed,
                totalDocuments: total,
                isOptimizing: false,
                queueCurrent: nil,
                queueTotal: nil
            )
            if let running = summarizationActivity {
                Task { @MainActor in await running.update(ActivityContent(state: content, staleDate: nil)) }
            } else if let existing = Activity<IndexingActivityAttributes>.activities
                .first(where: { $0.content.state.resolvedKind == .summarizing }) {
                summarizationActivity = existing
                Task { @MainActor in await existing.update(ActivityContent(state: content, staleDate: nil)) }
            } else {
                summarizationActivity = try? Activity.request(
                    attributes: IndexingActivityAttributes(),
                    content: ActivityContent(state: content, staleDate: nil)
                )
            }
        case .completed, .cancelled, .failed, .idle:
            endSummarizationLiveActivity()
        }
    }

    /// Ends the summarization Live Activity with a brief dismissal delay.
    private func endSummarizationLiveActivity() {
        guard let activity = summarizationActivity else { return }
        summarizationActivity = nil
        Task { @MainActor in
            await activity.end(nil, dismissalPolicy: .after(.now + 3))
        }
    }
    #endif

    #if os(iOS)
    /// A one-shot request to bring a tab forward, set by cross-view hand-offs (#316).
    ///
    /// The ~22 cross-view hand-offs (search-from-person, browse-from-research, cross-ref tap,
    /// Spotlight, open-with, …) write `pendingTab = .browse/.search/…` alongside their `pendingX`
    /// content field. Each `MainTabView` consumes it into its own per-scene `@SceneStorage`
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
    /// Uses `indexedVolumeIds` (a cached Set seeded at boot) for O(1) per-volume
    /// lookup instead of a live SQLite query, keeping the render loop free of I/O.
    ///
    /// Version history:
    ///   1.0 — Session 45: initial implementation
    ///   1.1 — Session 131: switched to `indexedVolumeIds` cache; no SQLite in render loop
    var unindexedVolumeCount: Int {
        guard let dm = downloadManager else { return 0 }
        let all = manifestStore.diffResult?.known ?? manifestStore.bundledEntries
        return all.filter { entry in
            dm.isVolumeDownloaded(entry.volumeId) && !indexedVolumeIds.contains(entry.volumeId)
        }.count
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
        static let activeTab = "frus.activeTab"
        static let lastActivityTabVisit = "frus.lastActivityTabVisit"
        static let filterDownloadedOnly = "frus.filterDownloadedOnly"
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
struct SceneID: Hashable, Sendable {
    /// Opaque per-scene token — a `UUID` string on iPad.
    let raw: String
    /// Wraps a raw per-scene token.
    init(_ raw: String) { self.raw = raw }

    /// Fixed identity of the macOS singleton **word-cloud** window (`frus.wordcloud`, #338 step 2).
    /// macOS word-cloud hand-offs address this; iPad producers address their own minted per-scene id.
    static let macWordCloud = SceneID("frus.wordcloud")

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

    /// Opens a value-based auxiliary window, recording the launching window's scene as its origin so a
    /// document opened from inside it routes back to that window (#338 aux-window origin). `sceneID` is
    /// the launcher's `@Environment(\.sceneID)` (nil on macOS, where aux windows route via provenance).
    func openAuxWindow<V: Codable & Hashable>(_ value: V, from sceneID: SceneID?,
                                              using openWindow: OpenWindowAction) {
        pendingAuxWindowOriginRaw = sceneID?.raw
        openWindow(value: value)
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
    /// Pass the producer view's `@Environment(\.sceneID)`.
    func openBrowseVolume(_ volumeId: String, from sceneID: SceneID?) {
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

#if os(iOS)
/// #338 aux-window origin: drains the launching window's scene from the transient `AppState` hand-off
/// once on appear and re-publishes it as this auxiliary window's `\.sceneID` (resolved live, else
/// `.anyWindow`). Applied to an aux `WindowGroup`'s content root, it makes origin flow TRANSITIVELY:
/// a document opened here — or a further aux window launched here — routes back to the originating
/// main window. Captured ONCE: a same-request `openWindow(value:)` refocus keeps the first origin
/// (a live window, no black-hole; #338 review, accepted).
struct AuxWindowOriginModifier: ViewModifier {
    let appState: AppState
    @State private var originRaw: String? = nil
    @State private var didCapture = false
    func body(content: Content) -> some View {
        content
            .environment(\.sceneID, appState.resolveOriginScene(originRaw))
            .onAppear {
                guard !didCapture else { return }
                didCapture = true
                originRaw = appState.pendingAuxWindowOriginRaw
                appState.pendingAuxWindowOriginRaw = nil
            }
    }
}

extension View {
    /// Applies ``AuxWindowOriginModifier`` — see it for the origin-propagation contract.
    func auxWindowOrigin(_ appState: AppState) -> some View { modifier(AuxWindowOriginModifier(appState: appState)) }
}
#endif
