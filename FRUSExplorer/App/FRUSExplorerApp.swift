// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import SwiftData
#if os(macOS) && DIRECT_DISTRIBUTION
import Sparkle
#endif

/// Root entry point for FRUS Explorer.
///
/// Bootstraps `AppState`, the SwiftData `ModelContainer`, and `DownloadManager`, and
/// injects them into the SwiftUI environment. All descendant views can access:
///   - Persistent models via `@Environment(\.modelContext)`
///   - Application state via `@Environment(AppState.self)`
///   - Download operations via `appState.downloadManager`
///
/// ## Boot Sequence
/// 1. `AppState` initialises synchronously: restores `activeProjectId`, starts `NWPathMonitor`.
/// 2. `ModelContainer` is created synchronously via `makeFRUSContainer()`.
/// 3. On the first `.task {}` fire (main actor, after first render):
///    a. `IndexingPipeline` and `SearchService` are created (failures are non-fatal).
///    b. `DownloadManager` is created with an `onVolumeDownloaded` closure that calls
///       `pipeline.indexVolume(_:)` automatically after each successful download.
///    c. If online, `resumeQueuedDownloads()` is called to continue any persisted queue.
/// 4. `onChange(of: appState.isOnline)` enables/suspends the download manager in real time.
///
/// Version history:
///   1.0 — Session 01: initial implementation
///   1.1 — Session 04: inject SwiftData ModelContainer
///   1.2 — Session 05: create and wire DownloadManager; respond to network state changes
///   1.3 — Session 10: fetch live manifest at boot
///   1.4 — Session 19: wire SummarizationService at boot
///   1.5 — Session 20: seed standard prompts on first launch
///   1.6 — Session 21: wire BackgroundSummarizationService at boot
///   1.7 — Session 29: DirectDistribution Sparkle "Check for Updates" menu command
///   1.8 — Session 31: fix CitationLookupView download URL construction
///   1.9 — Session 33: wire onVolumeDownloaded → indexVolume for automatic post-download indexing
///   2.0 — Session 46: macOS Settings scene added; ⌘F / ⌘⇧F Search/CitationLookup commands added
///   2.1 — Session 48: background re-index wired for FTS5 schema rebuild and date reindex migrations
///   2.2 — Session 49: deferred onboarding scope enqueue after DownloadManager boot
///   2.3 — Session 50: CommandGroup(replacing: .appInfo) → About FRUS Explorer sheet
@main
struct FRUSExplorerApp: App {

    @State private var appState = AppState()

    private let modelContainer: ModelContainer = ModelContainer.makeFRUSContainer()

    var body: some Scene {
        mainWindowScene
        #if os(macOS)
        Settings {
            MacSettingsView()
                .environment(appState)
                .modelContainer(modelContainer)
        }
        #endif
    }

    /// The primary `WindowGroup` scene, with macOS-specific modifiers applied conditionally.
    private var mainWindowScene: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task {
                    await bootDownloadManager()
                }
                .onChange(of: appState.isOnline) { _, isOnline in
                    guard let dm = appState.downloadManager else { return }
                    Task {
                        if isOnline {
                            await dm.resumeQueuedDownloads()
                        } else {
                            await dm.suspend()
                        }
                    }
                }
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Replace the default "About AppName" item with one that opens
            // the custom AboutView sheet (via AppState.showAbout).
            CommandGroup(replacing: .appInfo) {
                Button(String(localized: "menu.about",
                              defaultValue: "About FRUS Explorer")) {
                    appState.showAbout = true
                }
            }

            #if DIRECT_DISTRIBUTION
            CommandGroup(after: .appInfo) {
                Button(String(localized: "menu.checkForUpdates",
                              defaultValue: "Check for Updates\u{2026}")) {
                    SparkleUpdater.shared.checkForUpdates()
                }
                .disabled(!SparkleUpdater.shared.canCheckForUpdates)
            }
            #endif

            // Search and Citation Lookup keyboard shortcuts (⌘F and ⌘⇧F).
            // These write to AppState properties observed by BrowserView's sheet modifiers.
            CommandGroup(after: .textEditing) {
                Button(String(localized: "menu.search",
                              defaultValue: "Search\u{2026}")) {
                    appState.showSearch = true
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(appState.searchService == nil)

                Button(String(localized: "menu.citationLookup",
                              defaultValue: "Find by Citation\u{2026}")) {
                    appState.showCitationLookup = true
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
        #endif
    }

    // MARK: - Private

    /// Creates the DownloadManager the first time `.task` fires, then immediately
    /// resumes any queue that was persisted from the previous app session.
    @MainActor
    private func bootDownloadManager() async {
        guard appState.downloadManager == nil else { return }

        let volumesDir = Self.makeVolumesDirectory()
        let dbURL = Self.makeDatabaseURL()

        // Create search infrastructure. Failures are non-fatal: the browser and search
        // views degrade gracefully when indexingPipeline is nil.
        let fts5Store = try? FTS5Store(databaseURL: dbURL)
        if let store = fts5Store,
           let pipeline = try? IndexingPipeline(
               fts5Store: store,
               databaseURL: dbURL,
               volumesDirectory: volumesDir,
               subjectTagStore: appState.subjectTagStore
           ) {
            appState.indexingPipeline = pipeline
            appState.crossReferenceStore = try? CrossReferenceStore(databaseURL: dbURL)
            appState.personMentionStore = try? PersonMentionStore(databaseURL: dbURL)
            appState.searchService = SearchService(
                fts5Store: store,
                pipeline: pipeline,
                personMentionStore: appState.personMentionStore
            )
            let pageRangeStore = try? PageRangeStore(databaseURL: dbURL)
            let downloadedIds = Set(
                (try? FileManager.default.contentsOfDirectory(
                    at: volumesDir, includingPropertiesForKeys: nil
                ).map { $0.deletingPathExtension().lastPathComponent }) ?? []
            )
            appState.citationMatchingEngine = CitationMatchingEngine(
                manifestStore: appState.manifestStore,
                searchService: appState.searchService,
                pageRangeStore: pageRangeStore,
                downloadedVolumeIds: downloadedIds
            )

            // Trigger a background re-index when schema migrations require it.
            // Two independent flags can each demand a re-index:
            //   • store.didRebuildSchema + pipeline.needsFTSRebuildReindex:
            //     FTS5 table was rebuilt (is_editorial_note column was absent).
            //   • pipeline.needsDateReindex:
            //     Date extraction strategy was upgraded in Session 36.
            //
            // Both conditions are checked before launching the task so the captures
            // are immutable and don't require actor isolation inside the Task closure.
            let ftsRebuildNeeded = store.didRebuildSchema && pipeline.needsFTSRebuildReindex
            let dateReindexNeeded = pipeline.needsDateReindex
            if ftsRebuildNeeded || dateReindexNeeded {
                Task {
                    #if DEBUG
                    print("[FRUSExplorer] Background re-index triggered (ftsRebuild=\(ftsRebuildNeeded), dateReindex=\(dateReindexNeeded)).")
                    #endif
                    try? await pipeline.indexAllVolumes()
                    if ftsRebuildNeeded  { await pipeline.markFTSRebuildReindexComplete() }
                    if dateReindexNeeded { await pipeline.markDateReindexComplete() }
                    #if DEBUG
                    print("[FRUSExplorer] Background re-index complete.")
                    #endif
                }
            }
        }

        let summarizationService = SummarizationService(modelContainer: modelContainer)
        appState.summarizationService = summarizationService
        appState.backgroundSummarizationService = BackgroundSummarizationService(
            summarizationService: summarizationService,
            modelContainer: modelContainer,
            progress: appState.backgroundSummarizationProgress
        )
        SummarizationPromptSeeder.seed(in: modelContainer)

        // Capture the pipeline reference here on the MainActor (where appState is isolated)
        // so the onVolumeDownloaded closure can call indexVolume without a main-actor hop.
        // If pipeline setup failed above, indexPipeline is nil and no callback is registered.
        let indexPipeline = appState.indexingPipeline

        let dm = DownloadManager(
            volumesDirectory: volumesDir,
            concurrencyLimit: UserDefaults.standard.integer(forKey: "downloadConcurrencyLimit").nonZeroOrDefault(4),
            onStateChanged: { @MainActor [appState] state in
                appState.downloadQueue = state.allQueuedVolumeIds
            },
            onVolumeDownloaded: indexPipeline.map { pipeline in
                // Called on an unstructured Task after each successful download.
                // Errors are suppressed with try? — a failed index attempt is recoverable
                // via Settings > Reindex.
                { @Sendable volumeId in
                    try? await pipeline.indexVolume(volumeId)
                    #if DEBUG
                    print("[FRUSExplorer] Auto-indexed \(volumeId) after download.")
                    #endif
                }
            }
        )
        appState.downloadManager = dm

        if appState.isOnline {
            Task { await appState.manifestStore.fetchLiveManifest() }
        }

        if appState.isOnline {
            await dm.resumeQueuedDownloads()
        }

        // If onboarding completed before DownloadManager booted, a scope was parked in
        // AppState. Enqueue it now and clear the pending value.
        if let scope = appState.pendingDownloadScope {
            appState.pendingDownloadScope = nil
            let manifestStore = appState.manifestStore
            let allEntries = manifestStore.diffResult?.known ?? manifestStore.bundledEntries
            let toEnqueue: [VolumeManifestEntry]
            switch scope {
            case .corpus:
                toEnqueue = allEntries
            case .subseries(let id):
                toEnqueue = allEntries.filter { $0.subseries == id }
            case .volume(let id):
                toEnqueue = allEntries.filter { $0.volumeId == id }
            }
            for entry in toEnqueue {
                let url = "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(entry.filename)"
                await dm.enqueueDownload(volumeId: entry.volumeId, downloadUrl: url)
            }
            #if DEBUG
            print("[FRUSExplorer] Deferred onboarding scope enqueued: \(toEnqueue.count) volumes.")
            #endif
        }
    }

    /// Returns (and creates if necessary) the volumes storage directory.
    /// `{Application Support}/FRUSExplorer/Volumes/`
    private static func makeVolumesDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("FRUSExplorer/Volumes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Returns (and creates if necessary) the SQLite database URL.
    /// `{Application Support}/FRUSExplorer/frus.db`
    private static func makeDatabaseURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("FRUSExplorer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("frus.db")
    }
}

// MARK: - Int Helper

private extension Int {
    /// Returns this value if positive, otherwise returns `default`.
    func nonZeroOrDefault(_ default: Int) -> Int { self > 0 ? self : `default` }
}
