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
///   4.8 — Wave R-2a: `logEvent(_:defaults:)`, `loggingContext`, `currentResearchSession`,
///         `lastEventDate` and `sessionExpiryInterval` removed. `AppState` no longer writes
///         the research trail at all — the three typed writers do, sessions are derived by
///         `ResearchTrailSessions`, and the idle interval moved to `ResearchTrailSessions
///         .idleInterval`. `isResearchLoggingEnabled(in:)` stays: it is still the one gate.
///   4.9 — Wave R-6: `checkCloudKitHealth()`'s two `catch` blocks run the error through
///         `CloudKitErrorInspector`, so an account or zone failure records the retry-after hint
///         and the "looked for per-item detail" fact instead of a bare domain and code.

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
    /// Browse tab lists (and downloads from), the word-cloud vectors, the semantic map's 314,483
    /// placements, and every archival-analytics index. Declining the 3.3 GB is a reasonable
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

    /// True once the first CloudKit **import** has finished this launch, so the local `Project`
    /// store is stable. Until then the macOS "Switch Project" menu shows a "Syncing…" placeholder
    /// instead of a list that would churn/reshuffle as records arrive one batch at a time — a native
    /// menu handles live content mutation poorly, which made the menu hard to use during the initial
    /// sync of a fresh launch. Session-only (not persisted): a relaunch re-shows the placeholder only
    /// while its own import runs, and an already-synced launch (no import work) never shows it because
    /// the sync state never reaches `.syncing`. (#377 Phase 5)
    var hasInitialProjectSyncSettled = false

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
    func semanticShardsAwaitingDownload() async -> [String] {
        guard let store = semanticShardStore, let fetcher = semanticShardFetcher,
              let downloads = downloadManager else { return [] }
        let onDisk = Set(await store.volumeIDsOnDisk())
        let known = manifestStore.diffResult?.known ?? manifestStore.bundledEntries
        var awaiting: [String] = []
        for entry in known where downloads.isVolumeDownloaded(entry.volumeId) {
            guard !onDisk.contains(entry.volumeId) else { continue }
            guard await fetcher.hasShard(for: entry.volumeId) else { continue }
            awaiting.append(entry.volumeId)
        }
        return awaiting.sorted()
    }

    /// Fetches every shard the device is missing for the volumes it holds.
    ///
    /// Serial, deliberately: 552 shards at ~145 KB are many small requests rather than a few large
    /// ones, and the app's own volume downloads are already queued through `DownloadManager` with a
    /// concurrency limit the reader controls. Racing an unbounded fan-out against that would
    /// contend with the downloads this feature exists to accompany.
    ///
    /// Ignores ``automaticSemanticShardDownloads`` — see its note.
    func downloadAllSemanticShards() async {
        guard let store = semanticShardStore, let fetcher = semanticShardFetcher else { return }
        // A remembered failure blocks a re-request for the session, which is right for the lazy
        // path and wrong for someone who just pressed a button.
        await fetcher.clearFailures()

        let awaiting = await semanticShardsAwaitingDownload()
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
    /// eagerly, because 148 KB beside a ~6 MB volume is invisible and it makes the volume
    /// semantic-ready exactly when it becomes search-ready. Everything already on disk is fetched
    /// **lazily**, when a semantic surface first wants that volume — so an existing library does not
    /// silently pull 82 MB at launch to enable a feature the user has not opened yet.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// Why a shard fetch is being started — which decides whether the off switch applies.
    ///
    /// Stated at every call site rather than defaulted, so a future one cannot inherit the wrong
    /// answer silently.
    enum SemanticShardFetchReason {
        /// A volume finished downloading and its shard is riding along. **Honours the switch** —
        /// these are the bytes #926 is about: 552 requests fired by a corpus download for an axis
        /// that is off by default and may never be read.
        case volumeDownloaded
        /// A semantic surface is being used right now and wants this shard. **Ignores the switch.**
        ///
        /// Reaching here already required a finer and later act of consent than the toggle:
        /// `.semanticSimilarity` has `defaultWeight` 0 and is the only axis with
        /// `skipsGenerationAtZeroWeight`, so `RelatedDocumentsEngine` does not even run the
        /// generator until the reader has deliberately raised an experimental axis off zero.
        /// Gating this as well would let a coarse, earlier setting overrule a specific, later
        /// request — and the result would be an axis the reader switched on that scores nothing,
        /// forever, with the remedy buried in Settings.
        case readerAskedForSemantics
    }

    func fetchSemanticShardIfNeeded(for volumeID: String,
                                    reason: SemanticShardFetchReason) {
        guard let store = semanticShardStore, let fetcher = semanticShardFetcher else { return }
        guard isOnline else { return }
        // **The off switch (#926)**, read the way `DownloadManager` reads its cellular twin —
        // straight from `UserDefaults` with the default spelled here, so no view owns it and a
        // device that has never seen the toggle behaves as it always did.
        //
        // It applies to the ride-along only. That is what the control says on screen — "Download
        // With Volumes" — and a switch that quietly governed more than its label would be the
        // defect this review keeps removing, committed in the copy instead of the code.
        if reason == .volumeDownloaded, !Self.automaticSemanticShardDownloads { return }
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
    }

    // MARK: - Download Queue

    /// Volume IDs currently queued for download (active + pending).
    ///
    /// Updated by `DownloadManager` via its `onStateChanged` callback. Views observe
    /// this to show download indicators without calling into the actor directly.
    var downloadQueue: [String] = []

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
    /// `ResearchTrailMigration` deliberately does **not** consult it: moving records the user
    /// already has is not collection, and skipping the move when the switch is off would destroy
    /// them instead of preserving them.
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
    // `idleInterval` is the 30 minutes this constant used to hold. `ResearchTrailMigration` moves
    // what is worth keeping out of the legacy tables.

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
    ///   correctness, not convenience — see `PersonRollupRefresh.afterCorpusChange`.
    func refreshAfterCorpusChange(context: ModelContext?) {
        refreshReadOnlyStores()
        // #777: a side-loaded volume is a corpus change the catalogue cannot see. Reconciling here
        // means the volume is browsable the moment its import finishes, and — because this also
        // runs at boot — that a volume side-loaded before #777 shipped gains its metadata on the
        // next launch rather than needing to be imported again.
        if let volumesDirectory {
            manifestStore.refreshLocalEntries(volumesDirectory: volumesDirectory)
        }
        guard let indexingPipeline else { return }
        Task { @MainActor in
            if await PersonRollupRefresh.afterCorpusChange(context: context,
                                                           pipeline: indexingPipeline,
                                                           appState: self) {
                refreshReadOnlyStores()
            }
        }
    }

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

    /// Bumped when the user asks to **type a new query** — ⌘S (Find ▸ Search…) or the main
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

    /// Whether the indexing-education sheet has auto-opened in this app session (#757 / audit L-46).
    ///
    /// Lives here because `AppState` **is** the session — created once per launch, outliving every
    /// view recreation. The flag was `@AppStorage`, which made the designed once-per-session
    /// introduction a once-per-**install** one: a researcher who indexed a batch months ago never
    /// saw it again on their next tranche, because nothing ever reset the key.
    var hasShownIndexingEducationThisSession = false

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
    var liveSceneIDs: Set<SceneID> = []

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
    /// ``openAuxWindow(_:from:using:)`` is the only writer, it writes **unconditionally immediately
    /// before every open**, and it is the only iOS path that mints any of the five
    /// `.auxWindowOrigin`-bearing scenes. Every open therefore overwrites the slot with its own
    /// launcher before the new root reads it — a parked value can only ever be re-read by the window
    /// that parked it. And a value that outlives its window degrades through
    /// ``resolveOriginScene(_:)`` to `.anyWindow`, which is a live window rather than nowhere.
    ///
    /// What *is* true, and is #338-accepted rather than a bug: an aux window refocused from a
    /// **different** main window keeps the origin it captured first, so an action inside it routes to
    /// the window that originally opened it. See ``AuxWindowOriginModifier``.
    var pendingAuxWindowOriginRaw: String? = nil

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

    /// Re-reads the real backlog and either raises the queue's total or ends the queue.
    ///
    /// `downloadQueue.count + 1` only describes a queue whose downloads are still in
    /// flight. When the downloads finished first — a subseries on a fast connection — the
    /// provisional total is 1 while dozens of volumes wait, which is what hid the queue
    /// banner (#541). `unindexedDownloadedVolumeIds()` is the authoritative answer, and is
    /// what the background indexing pass already uses to decide its own work.
    ///
    /// - Parameter mayEnd: `true` after a volume completes, when an empty backlog means
    ///   the whole queue is done. `false` at queue start, where an empty result could only
    ///   be a race with the volume that is indexing right now.
    ///
    /// Runs off the main actor (`IndexingPipeline` is an actor) and only ever raises the
    /// total, so a slow query cannot retract a count the banner is already showing.
    private func syncIndexingBatchWithBacklog(mayEnd: Bool) {
        guard let pipeline = indexingPipeline else {
            // Nothing can answer "is there more?", so ending on the volume that just
            // finished beats leaving a banner up with nothing driving it.
            if mayEnd { endIndexingBatch() }
            return
        }
        Task { @MainActor [weak self] in
            let backlog = try? await pipeline.unindexedDownloadedVolumeIds()
            guard let self, var batch = self.indexingBatch else { return }
            guard let backlog else { return }  // transient failure: retry on the next volume
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
                batch.total = max(batch.total, batch.completed + backlog.count)
                // Union, never replace: the backlog shrinks as volumes are indexed, and
                // the cloud's scope must describe the queue the user started, not what is
                // left of it.
                let known = Set(batch.volumeIds)
                batch.volumeIds += backlog.filter { !known.contains($0) }.sorted()
                self.indexingBatch = batch
                if mayEnd {
                    self.armIndexingBatchWatchdog(generation: batch.generation,
                                                  seconds: Self.indexingBatchStallTimeout)
                }
            }
        }
    }

    /// Tears the queue down and hands the summary card its queue-grain count.
    private func endIndexingBatch() {
        indexingBatchWatchdog?.cancel()
        indexingBatchWatchdog = nil
        guard let batch = indexingBatch else { return }
        completedIndexingBatchVolumeCount = batch.completed > 1 ? batch.completed : nil
        indexingBatch = nil
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
    /// the SwiftUI render loop.  Called once at boot after the pipeline is created.
    func seedIndexedVolumeIds(pipeline: IndexingPipeline) {
        Task.detached(priority: .utility) { [weak self] in
            let ids = (try? pipeline.allIndexedVolumeIds()) ?? []
            await MainActor.run { [weak self] in
                self?.indexedVolumeIds = ids
                #if os(iOS)
                self?.refreshUnindexedVolumeCount()
                #endif
            }
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
                    #if os(iOS)
                    // The Browse-tab badge counts downloaded-but-unindexed volumes, and one
                    // just left that set.
                    self.refreshUnindexedVolumeCount()
                    #endif
                    // The volume just became locally available — teach the citation
                    // matching engine about it. Its downloaded-volume set is otherwise
                    // a boot-time snapshot, which broke the "download this volume,
                    // then resolve again" loop advertised by CitationLookupView and
                    // the collections Add Documents sheet until the next relaunch.
                    if let engine = self.citationMatchingEngine {
                        let completedVolumeId = update.volumeId
                        Task { await engine.noteVolumeDownloaded(completedVolumeId) }
                    }
                    if var batch = self.indexingBatch {
                        batch.completed += 1
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
                    self.endIndexingLiveActivity()
                    // Nothing is queued here any more. The background word-cloud precompute this
                    // site fed was removed: it ran NLTagger over the corpus at 97% CPU until iOS
                    // terminated the app, and an entry it managed to write was invalidated by the
                    // next volume indexed — which is to say, by the very event this call sits in.
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
                    if var batch = self.indexingBatch {
                        // A queue already in flight simply advances. There is no
                        // idle-gap heuristic any more: #541 fixed one wrong reading of
                        // "is this a new batch?" (`downloadQueue.isEmpty`, which is true
                        // at every transition once downloads outpace indexing) and a
                        // 30-second timer was only ever a second guess at the same
                        // question. The queue's own presence is the answer.
                        batch.latest = update
                        batch.generation += 1
                        self.indexingBatch = batch
                    } else {
                        // A new queue. The provisional total is correct for a
                        // download-led queue and an undercount when the downloads already
                        // finished; the backlog query below replaces it either way.
                        self.indexingBatch = IndexingBatch(
                            total: max(1, self.downloadQueue.count + 1),
                            completed: 0,
                            latest: update,
                            volumeIds: self.downloadQueue + [update.volumeId]
                        )
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
        case let .running(tally, _, _):
            guard liveActivityEnabled else { endSummarizationLiveActivity(); return }
            let processed = tally.finished
            let total = tally.attemptable
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
struct SceneID: Hashable, Sendable {
    /// Opaque per-scene token — a `UUID` string on iPad.
    let raw: String
    /// Wraps a raw per-scene token.
    init(_ raw: String) { self.raw = raw }

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
///
/// The consequence of capturing once, stated plainly (#752 / L-48): an aux window **refocused from a
/// different main window** keeps its *first* origin, so a related-document tap inside it routes to
/// the window that originally opened it rather than the one that just refocused it. That is the
/// accepted trade — the alternative, re-capturing on every appear, would let a background window's
/// stale launch overwrite a foreground one's — and since #752/L-40 it is the behaviour
/// `SourceExplorerWindowContent` inherits, so it is worth knowing before reading that code.
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
