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
    func logEvent(_ kind: ResearchEventKind) {
        let enabled = UserDefaults.standard.object(forKey: "researchSessionLoggingEnabled") as? Bool ?? true
        guard enabled else { return }
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
    /// used by `StorageManagementView` to report index disk usage.
    var indexDirectory: URL?

    /// Set by `PersonDetailSheet` "Find all mentions" to trigger search pre-filled
    /// with a `personRef` filter. `BrowserView` consumes this and clears it.
    var pendingSearch: SearchParameters? = nil

    /// Cross-view handoff from Search to Corpus Analytics (and vice versa).
    ///
    /// Set by `SearchView` when the result count hits `SearchViewModel
    /// .searchHardLimit` and the user chooses to "Visualize in Corpus Analytics" —
    /// seeding the chart with the submitted keywords (and active date filter, if
    /// any) so they can see the distribution over time and pick a narrower range.
    /// `MainTabView` (iOS sheet) and `MainWindowView`/`AnalyticsView` (macOS
    /// `frus.analytics` window) observe this via `.onChange`, apply it, and clear
    /// it — mirroring the `pendingSearch` pattern.
    var pendingAnalytics: AnalyticsParameters? = nil

    /// Cross-view handoff into the corpus Chronology browser.
    ///
    /// Set when another surface wants to open Chronology pre-seeded with a date range
    /// (e.g. a future "browse this range chronologically" affordance from Search or
    /// Corpus Analytics). `BrowserTabView` (iOS sheet) and `ChronologyView` (macOS
    /// `frus.chronology` window) observe this via `.onChange`, apply it, and clear it —
    /// mirroring the `pendingSearch` / `pendingAnalytics` pattern.
    var pendingChronology: ChronologyParameters? = nil

    /// Cross-view handoff into the Word Cloud analytics view.
    ///
    /// Set by any surface (document toolbar, volume/subseries browser, collection,
    /// user tag, saved search) that wants to open a word cloud for a given scope.
    /// `MainTabView` (iOS sheet) and the macOS `frus.wordcloud` window observe this
    /// via `.onChange`, present the cloud, and clear it — mirroring the
    /// `pendingSearch` / `pendingAnalytics` pattern.
    var pendingWordCloud: WordCloudScope? = nil

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
    /// `BrowserView` observes it and appends to the Browse tab's path. On **macOS** every document
    /// host translates it (via `routeBrowseToActiveHost()`) into a `routedBrowse` targeting the
    /// active window — so producers never write `routedBrowse` directly.
    var pendingBrowseDocument: DocumentBrowserEntry? = nil

    /// The document-hosting window most recently made key (macOS). Each host
    /// (`MainWindowView`, `MacDocumentWindowView`) updates it from its `controlActiveState`
    /// observer, and resets it to `.main` when it closes. Tool-window navigation targets it so a
    /// selected document opens in the window the user launched the tool from rather than always the
    /// main window (visual-review finding, 2026-07-18).
    var activeDocumentHost: DocumentHostID = .main

    /// A tool-window document selection routed to `activeDocumentHost` (macOS). The matching host
    /// consumes it via `.onChange` (appends to its navigation path, fronts itself) and clears it.
    /// Producers still set `pendingBrowseDocument`; every open document host translates it into this
    /// routed form, so no producer needs to know about window routing.
    var routedBrowse: RoutedBrowse? = nil

    /// Translates a pending `pendingBrowseDocument` into a `routedBrowse` aimed at the active
    /// document window, then clears the pending value. Called by EVERY macOS document host from its
    /// `pendingBrowseDocument` observer — the clear-first step makes it exactly-once no matter how
    /// many hosts are open, and having every host (not just the main window) run it means the
    /// translation survives even when the main window is closed (a user living in document windows).
    /// No-op when nothing is pending.
    func routeBrowseToActiveHost() {
        guard let entry = pendingBrowseDocument else { return }
        pendingBrowseDocument = nil
        routedBrowse = RoutedBrowse(host: activeDocumentHost, entry: entry)
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
    var pendingBrowseVolume: String? = nil

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

    /// Cross-window hand-off into the Source Explorer window's **NARA Lookup** mode
    /// (UI audit B3): the selected document text a caller wants pre-filled as the
    /// catalog query.
    ///
    /// Set by the ResearchStripView `onNARALookup` closures (`MainWindowView`,
    /// `MacDocumentWindowView`) immediately before
    /// `openWindow(id: "frus.sourceExplorer")`. `SourceExplorerWindowView` consumes
    /// it (`.task` for a freshly created window, `.onChange` for one already open),
    /// switches to the NARA Lookup segment with a fresh view identity so the query
    /// field shows the new text, and clears it — mirroring the `pendingSearch` /
    /// `pendingCollectionSelection` pattern. macOS-only in practice; iOS presents
    /// `NARACatalogLookupView` as a local sheet.
    var pendingNARALookup: NARALookupRequest? = nil

    /// Cross-window hand-off into the research-note composer window (UI audit C1):
    /// the document context (and optional existing note / linked highlight) a note
    /// should be composed against.
    ///
    /// Set by the macOS note entry points (ResearchStripView's "Add note" and
    /// highlight-note buttons; MacDocumentView's research-panel note rows and
    /// "Add Note" button) immediately before `openWindow(id: "frus.noteComposer")`.
    /// `NoteComposerWindowView` consumes it (`.task` for a freshly created window,
    /// `.onChange` for one already open) and clears it — mirroring the
    /// `pendingNARALookup` pattern, including the fresh view identity per hand-off
    /// (`handoffId`) so the editor repopulates. One composer at a time by design:
    /// a new hand-off replaces the window's content. macOS-only in practice; iOS
    /// keeps its local `ResearchNoteEditorView` sheets.
    var pendingNoteComposer: NoteComposerRequest? = nil

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
    var pendingTab: AppTab? = nil

    /// Adopts and clears the consume-once tab hand-off (#316): returns the pending tab (the
    /// caller selects it) and nils the channel in the same step, so exactly one consumer ever
    /// adopts a given request — a second window (or the post-clear `onChange` re-fire) gets
    /// `nil` and keeps its own selection. Factored out of `MainTabView`'s `onChange`/`onAppear`
    /// drains so the adopt-then-clear contract is directly unit-testable.
    func consumePendingTab() -> AppTab? {
        guard let pending = pendingTab else { return nil }
        pendingTab = nil
        return pending
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
