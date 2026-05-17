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
/// index queries. `subjectTagStore` provides document-level subject tag lookups.
/// Both are loaded synchronously at init from the app bundle.
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
///   2.1 — Session 44: showSettingsSheet and pendingOnboardingAfterReset guarded to macOS
///   2.2 — Session 45: lastActivityTabVisit and unindexedVolumeCount (iOS)
///   2.3 — Session 46: showSettingsSheet and pendingOnboardingAfterReset removed;
///          Settings is now a Settings scene on macOS (no sheet needed)
///   2.4 — Session 49: pendingDownloadScope added for onboarding → DownloadManager handoff
///   2.5 — Session 50: filterDownloadedOnly (UserDefaults-persisted); showAbout (macOS)
///   2.6 — Session 51: currentIndexingProgress (iOS); connectIndexingProgress(pipeline:)

// MARK: - AppTab

/// The five top-level tabs available on iOS.
///
/// `rawValue` is persisted to `UserDefaults` so the active tab survives app relaunch.
#if os(iOS)
enum AppTab: String, CaseIterable, Sendable {
    case browse      = "browse"
    case search      = "search"
    case activity    = "activity"
    case collections = "collections"
    case settings    = "settings"
}
#endif

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

    #if os(macOS)
    /// Controls presentation of the About FRUS Explorer sheet.
    ///
    /// Set to `true` by the `CommandGroup(replacing: .appInfo)` menu command.
    /// `BrowserView` observes this to present the `AboutView` sheet.
    var showAbout: Bool = false
    #endif

    // MARK: - Pending Download Scope

    /// Set by onboarding or `DownloadManagerSettingsView` when the user confirms a
    /// download scope. `FRUSExplorerApp.bootDownloadManager` (or a `.onChange` watcher
    /// on `ContentView`) enqueues the scope with `DownloadManager` and clears this
    /// property immediately after enqueueing.
    var pendingDownloadScope: DownloadScope? = nil

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

    // MARK: - Tag Stores

    /// Resolves volume-level tag slugs and provides volume-by-tag queries.
    /// Loaded synchronously from `volume-tag-taxonomy.json` and `manifest.json` at init.
    let volumeLevelTagStore: VolumeLevelTagStore = VolumeLevelTagStore()

    /// Provides document-level subject tag lookups by document ID, subject ID, and category.
    /// Loaded synchronously from `taxonomy.json` and `subject-appearances.json` at init.
    let subjectTagStore: SubjectTagStore = SubjectTagStore()

    /// Loads and merges the volume manifest. Loaded from bundle at init; live data fetched at boot.
    var manifestStore: ManifestStore = ManifestStore()

    // MARK: - Search Infrastructure

    /// The shared indexing pipeline. Created at boot by `FRUSExplorerApp` alongside
    /// `DownloadManager`; `nil` if the database could not be opened.
    var indexingPipeline: IndexingPipeline?

    /// The shared search service. Created at boot alongside `indexingPipeline`;
    /// `nil` if the FTS5 database could not be opened.
    var searchService: SearchService?

    /// The shared cross-reference store. Created at boot alongside `indexingPipeline`;
    /// `nil` if the database could not be opened.
    var crossReferenceStore: CrossReferenceStore?

    /// The shared person mention store. Created at boot alongside `crossReferenceStore`;
    /// `nil` if the database could not be opened.
    var personMentionStore: PersonMentionStore?

    /// Set by `PersonDetailSheet` "Find all mentions" to trigger search pre-filled
    /// with a `personRef` filter. `BrowserView` consumes this and clears it.
    var pendingSearch: SearchParameters? = nil

    /// Set by cross-reference navigation to push a document into the Browse tab's
    /// NavigationStack/NavigationSplitView. `BrowserView` observes via `.onChange`
    /// and appends the entry to its path, then this property is cleared.
    var pendingBrowseDocument: DocumentBrowserEntry? = nil

    /// Controls presentation of the full-text Search sheet.
    ///
    /// Promoted from `BrowserView` local `@State` to `AppState` so that macOS
    /// menu commands and the iOS Search tab can trigger the sheet without a direct
    /// view reference. Session 43.
    var showSearch: Bool = false

    /// Controls presentation of the Citation Lookup sheet.
    ///
    /// Promoted from `BrowserView` local `@State` to `AppState`. Session 43.
    var showCitationLookup: Bool = false

    #if os(iOS)
    /// The currently selected tab on iOS.
    ///
    /// Persisted via `UserDefaults` key `"frus.activeTab"` so the active tab
    /// survives app relaunch. Defaults to `.browse`.
    var activeTab: AppTab = {
        guard let raw = UserDefaults.standard.string(forKey: Keys.activeTab),
              let tab = AppTab(rawValue: raw) else { return .browse }
        return tab
    }() {
        didSet {
            UserDefaults.standard.set(activeTab.rawValue, forKey: Keys.activeTab)
            if activeTab == .activity {
                lastActivityTabVisit = .now
            }
            #if DEBUG
            print("[FRUSExplorer] Active tab: \(activeTab.rawValue)")
            #endif
        }
    }

    /// The timestamp of the most recent visit to the Activity tab.
    ///
    /// Persisted via `UserDefaults` so the badge count ("notes since last visit")
    /// survives app relaunch. `MainTabView` stamps `.now` whenever `activeTab` changes
    /// to `.activity`. Defaults to `.distantPast` so all existing notes appear as new
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

    /// The most recent per-document indexing progress update, or `nil` when no
    /// indexing is in progress.
    ///
    /// Populated by `connectIndexingProgress(pipeline:)` which subscribes to
    /// `IndexingPipeline.progressStream`. Views observe this to render an inline
    /// `IndexingCapsule` in `VolumeRowLabel`.
    ///
    /// Version history:
    ///   1.0 — Session 51: initial implementation
    var currentIndexingProgress: IndexingProgressUpdate? = nil

    /// Subscribes to `pipeline.progressStream` and forwards updates onto the main
    /// actor as `currentIndexingProgress`.
    ///
    /// Safe to call multiple times — each call replaces the previous subscription
    /// (the prior Task is abandoned; the stream is single-consumer by design).
    func connectIndexingProgress(pipeline: IndexingPipeline) {
        Task { @MainActor [weak self] in
            for await update in await pipeline.progressStream {
                guard let self else { return }
                if update.stage == .complete {
                    self.currentIndexingProgress = nil
                } else {
                    self.currentIndexingProgress = update
                }
            }
        }
    }

    /// Count of volumes that are downloaded but not yet present in the search index.
    ///
    /// Used to drive the Settings tab badge, prompting the user to run Reindex.
    /// Returns 0 if `downloadManager` or `indexingPipeline` is nil (i.e. during boot).
    /// Uses `try?` so an unexpected SQLite error conservatively returns 0 (no badge)
    /// rather than crashing.
    ///
    /// Version history:
    ///   1.0 — Session 45: initial implementation
    var unindexedVolumeCount: Int {
        guard let dm = downloadManager, let pipeline = indexingPipeline else { return 0 }
        let all = manifestStore.diffResult?.known ?? manifestStore.bundledEntries
        return all.filter { entry in
            dm.isVolumeDownloaded(entry.volumeId)
            && (try? !pipeline.isVolumeIndexed(entry.volumeId)) == true
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
