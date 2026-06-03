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
import CoreData       // NSPersistentCloudKitContainer for sync-event monitoring
import CloudKit       // CKError codes, CKPartialErrorsByItemIDKey for detailed diagnostics
import CoreSpotlight

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
/// ## Window Architecture (macOS)
/// | Scene ID                        | Type          | Purpose                                          |
/// |---------------------------------|---------------|--------------------------------------------------|
/// | (default `WindowGroup`)         | WindowGroup   | Main document window (onboarding → main UI)      |
/// | `"frus.search"`                 | Window        | Full-text search — persists while reading docs   |
/// | `"frus.corpusBrowser"`          | Window        | Corpus browser — independent browsable window    |
/// | `"frus.crossReferenceGraph"`    | Window        | Cross-reference graph — floating, per-document   |
/// | `"frus.sourceExplorer"`         | Window        | Source explorer — floating, per-document         |
/// | `"frus.collections"`            | Window        | Collections — manage, edit, and export           |
/// | `"frus.analytics"`              | Window        | Corpus frequency analytics — Swift Charts        |
/// | `"about"`                       | Window        | About FRUS Explorer                              |
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
///   2.4 — Session 51: connectIndexingProgress wired on iOS; Task.yield() before auto-indexVolume
///   2.5 — Session 61: About sheet replaced with Window scene; openWindow used in CommandGroup
///   2.8 — New UI: Corpus Browser, Cross-Reference Graph, Source Explorer window scenes added
///   2.9 — Collections Window scene added (⌘⇧K); wired to toolbar and Window menu
///   3.0 — Collections Window wired to MacCollectionManagerView (NavigationSplitView with
///          inline editing); defaultSize widened to 760×600; FRUSExplorerMac added to scheme
///          archive action; user-selected file entitlement added for NSSavePanel exports
///   3.1 — Boot-time summary sync: pushes all GeneratedSummary records into FTS5 at launch
///          so summary-only search finds both local and CloudKit-synced summaries
///   3.2 — Session 94: Source Explorer window defaultSize corrected from 380×320 to 700×440
///          (the view enforces minWidth:640, so 380 caused an immediate jarring resize)
///   3.3 — Session 99: Analytics Window scene added (frus.analytics); AnalyticsView wired
///   3.4 — Session 108: iPadOS Stage Manager — UIApplicationSupportsMultipleScenes YES;
///          WindowGroup(for: DocumentWindowID.self) for document windows;
///          WindowGroup id:"frus.sourceExplorer.ios" for source explorer windows
///   3.5 — Session 115: IndexingStateTracker created at boot; interruptedVolumeIds seeded from
///          sentinel store; tracker passed to IndexingPipeline for interrupted-state detection
///   3.6 — Session 130: Research window added (frus.research, ⌘⌥R); iOS Activity tab replaced
///          by Research tab in MainTabView
///   3.7 — Session 130: boot-time DocumentTagAssignment→document_cache FTS5 sync;
///          one-time migration of legacy document_cache.user_tag_ids to DocumentTagAssignment
@main
struct FRUSExplorerApp: App {

    @State private var appState = AppState()
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    // `makeFRUSContainer()` returns a tuple so the CloudKit-enabled flag is available
    // without a second call. `modelContainer` is a computed property for backward
    // compatibility with all existing `.modelContainer(modelContainer)` call sites.
    private let _containerSetup = ModelContainer.makeFRUSContainer()
    private var modelContainer: ModelContainer { _containerSetup.container }

    var body: some Scene {
        mainWindowScene
        #if os(iOS)
        // MARK: - Document Window (iPadOS Stage Manager)
        //
        // Opens individual FRUS documents in dedicated Stage Manager windows on
        // M-chip iPads. WindowGroup(for:) lets SwiftUI restore windows across
        // scene lifecycle events using the Codable DocumentWindowID value.
        // On iPhone and non-Stage-Manager iPads, openWindow(value:) is a no-op.
        WindowGroup(for: DocumentWindowID.self) { $windowID in
            Group {
                if let id = windowID {
                    // NavigationStack is required so DocumentView's .navigationTitle
                    // and toolbar items render in a proper nav bar for the scene window.
                    NavigationStack {
                        DocumentView(entry: DocumentBrowserEntry(
                            documentId: id.documentId,
                            volumeId: id.volumeId,
                            header: id.header
                        ))
                    }
                } else {
                    ContentUnavailableView(
                        String(localized: "documentWindow.empty.title",
                               defaultValue: "No Document"),
                        systemImage: "doc.text",
                        description: Text(
                            String(localized: "documentWindow.empty.detail",
                                   defaultValue: "Open a document from the Browse tab.")
                        )
                    )
                }
            }
            .environment(appState)
            .modelContainer(modelContainer)
        }

        // MARK: - Source Explorer Window (iPadOS Stage Manager)
        //
        // Mirrors the macOS "frus.sourceExplorer" Window scene. Reads
        // appState.currentSourceNote — set by the caller before openWindow(id:).
        WindowGroup("Source Explorer", id: "frus.sourceExplorer.ios") {
            Group {
                if let sourceNote = appState.currentSourceNote {
                    NavigationStack {
                        SourceExplorerView(
                            rawSourceNote: sourceNote,
                            documentYear: appState.currentSourceNoteYear
                        )
                    }
                } else {
                    ContentUnavailableView(
                        String(localized: "sourceExplorerWindow.empty.title",
                               defaultValue: "No Document Selected"),
                        systemImage: "archivebox",
                        description: Text(
                            String(localized: "sourceExplorerWindow.empty.detail",
                                   defaultValue: "Open a document with a source note, then tap Sources in the toolbar.")
                        )
                    )
                }
            }
            .environment(appState)
            .modelContainer(modelContainer)
        }
        #endif
        #if os(macOS)
        // MARK: - Search Window
        Window("Search", id: "frus.search") {
            MacSearchWindowView()
                .environment(appState)
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 820, height: 680)
        .keyboardShortcut("f", modifiers: .command)

        // MARK: - Corpus Browser Window
        Window("Corpus Browser", id: "frus.corpusBrowser") {
            CorpusBrowserWindowView()
                .environment(appState)
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 520, height: 700)
        .keyboardShortcut("b", modifiers: [.command, .shift])

        // MARK: - Cross-Reference Graph Window
        Window("Cross-Reference Graph", id: "frus.crossReferenceGraph") {
            CrossReferenceGraphWindowView()
                .environment(appState)
        }
        .defaultSize(width: 480, height: 440)

        // MARK: - Source Explorer Window
        Window("Source Explorer", id: "frus.sourceExplorer") {
            SourceExplorerWindowView()
                .environment(appState)
        }
        .defaultSize(width: 700, height: 440)

        // MARK: - Analytics Window
        Window("Corpus Analytics", id: "frus.analytics") {
            AnalyticsView()
                .environment(appState)
        }
        .defaultSize(width: 760, height: 560)

        // MARK: - Research Window
        Window(String(localized: "research.window.title", defaultValue: "Research"),
               id: "frus.research") {
            ResearchView()
                .environment(appState)
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 760, height: 600)
        .keyboardShortcut("r", modifiers: [.command, .option])

        // MARK: - Collections Window
        Window("Collections", id: "frus.collections") {
            MacCollectionManagerView()
                .environment(appState)
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 760, height: 600)
        .keyboardShortcut("k", modifiers: [.command, .shift])

        // MARK: - Settings
        Settings {
            FRUSSettingsView()
                .environment(appState)
                .modelContainer(modelContainer)
        }

        // MARK: - About Window
        Window(String(localized: "about.title", defaultValue: "About FRUS Explorer"),
               id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
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
                // Handoff: a FRUS document viewed on another device
                .onContinueUserActivity(AppActivityTypes.document) { activity in
                    continueDocumentActivity(activity)
                }
                // Spotlight: user tapped a search result for a FRUS document
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                    let parts = identifier.split(separator: "/", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { return }
                    navigateToDocument(volumeId: parts[0], documentId: parts[1], title: activity.title)
                }
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Replace the default "About AppName" item with one that opens the
            // dedicated About Window scene.
            CommandGroup(replacing: .appInfo) {
                Button(String(localized: "menu.about",
                              defaultValue: "About FRUS Explorer")) {
                    openWindow(id: "about")
                }
            }


            // Citation Lookup keyboard shortcut (⌘⇧F).
            // Search (⌘F) is handled by the "frus.search" Window scene shortcut.
            CommandGroup(after: .textEditing) {
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
        appState.indexDirectory = dbURL.deletingLastPathComponent()

        // Surface the CloudKit init result in AppState so the status bar and settings
        // panel can show a "Local Only" warning when sync is unavailable.
        appState.cloudKitSyncEnabled = _containerSetup.cloudKitEnabled
        if !_containerSetup.cloudKitEnabled {
            appState.cloudKitInitError = "CloudKit initialisation failed. Check console for details."
        }

        // Seed interrupted volume IDs from the sentinel store before creating the pipeline
        // so the UI can show amber badges immediately after the first render.
        let stateTracker = IndexingStateTracker()
        let interruptedIds = await stateTracker.interruptedVolumeIds()
        appState.interruptedVolumeIds = Set(interruptedIds)

        // Create search infrastructure. Failures are non-fatal: the browser and search
        // views degrade gracefully when indexingPipeline is nil.
        let fts5Store = try? FTS5Store(databaseURL: dbURL)
        if let store = fts5Store,
           let pipeline = try? IndexingPipeline(
               fts5Store: store,
               databaseURL: dbURL,
               volumesDirectory: volumesDir,
               subjectTagStore: appState.subjectTagStore,
               stateTracker: stateTracker
           ) {
            appState.indexingPipeline = pipeline
            appState.connectIndexingProgress(pipeline: pipeline)
            appState.crossReferenceStore = try? CrossReferenceStore(databaseURL: dbURL)
            appState.personMentionStore = try? PersonMentionStore(databaseURL: dbURL)
            appState.searchService = SearchService(
                fts5Store: store,
                pipeline: pipeline,
                personMentionStore: appState.personMentionStore
            )
            appState.analyticsService = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)
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

            // Push all existing SwiftData user annotations into the FTS5 index.
            // FTS5 summary_text, note_text, and user_tag_ids are always NULL after initial
            // indexing because they are created after the fact and stored only in SwiftData.
            // This scan handles prior-session data and CloudKit-synced records from other
            // devices. Runs in a background Task so it doesn't block boot.
            let container = modelContainer
            Task {
                let context = ModelContext(container)

                let summaries = (try? context.fetch(FetchDescriptor<GeneratedSummary>())) ?? []
                for summary in summaries {
                    let vid = summary.volumeId
                    let did = summary.documentId
                    let text = summary.responseText
                    try? await pipeline.updateSummaryText(volumeId: vid, documentId: did, responseText: text)
                }

                let notes = (try? context.fetch(FetchDescriptor<ResearchNote>())) ?? []
                for note in notes {
                    let vid = note.volumeId
                    let did = note.documentId
                    let text = note.bodyText
                    let tagString = note.userTagIds.map(\.uuidString).joined(separator: " ")
                    try? await pipeline.updateNoteText(
                        volumeId: vid, documentId: did,
                        bodyText: text,
                        userTagIds: tagString.isEmpty ? nil : tagString
                    )
                }

                #if DEBUG
                print("[FRUSExplorer] Boot sync: \(summaries.count) summaries, \(notes.count) notes pushed to FTS5")
                #endif
            }
        }

        let summarizationService = SummarizationService(
            modelContainer: modelContainer,
            indexingPipeline: appState.indexingPipeline
        )
        appState.summarizationService = summarizationService
        appState.backgroundSummarizationService = BackgroundSummarizationService(
            summarizationService: summarizationService,
            modelContainer: modelContainer,
            progress: appState.backgroundSummarizationProgress
        )
        SummarizationPromptSeeder.seed(in: modelContainer)

        // Capture the pipeline reference here on the MainActor (where appState is isolated)
        // so the onVolumeDownloaded closure can call indexVolume without a main-actor hop.
        let indexPipeline = appState.indexingPipeline

        let dm = DownloadManager(
            volumesDirectory: volumesDir,
            concurrencyLimit: UserDefaults.standard.integer(forKey: "downloadConcurrencyLimit").nonZeroOrDefault(4),
            onStateChanged: { @MainActor [appState] state in
                appState.downloadQueue = state.allQueuedVolumeIds
            },
            onVolumeDownloaded: indexPipeline.map { pipeline in
                // Capture modelContainer so the closure can sync summaries after indexing.
                let container = modelContainer
                return { @Sendable volumeId in
                    // Yield before indexing so the download completion write can
                    // fully flush before we begin a potentially long CPU/DB task.
                    await Task.yield()
                    try? await pipeline.indexVolume(volumeId)
                    // After document_cache is populated, push any existing summaries
                    // for this volume into FTS5. This handles the re-download-after-reset
                    // case where CloudKit-synced summaries arrived before the volume was
                    // re-indexed, so the boot-time sync found an empty document_cache.
                    let vid = volumeId
                    let context = ModelContext(container)

                    let summaryDescriptor = FetchDescriptor<GeneratedSummary>(
                        predicate: #Predicate { $0.volumeId == vid }
                    )
                    let summaries = (try? context.fetch(summaryDescriptor)) ?? []
                    for summary in summaries {
                        let did = summary.documentId
                        let text = summary.responseText
                        try? await pipeline.updateSummaryText(volumeId: vid, documentId: did, responseText: text)
                    }

                    let noteDescriptor = FetchDescriptor<ResearchNote>(
                        predicate: #Predicate { $0.volumeId == vid }
                    )
                    let notes = (try? context.fetch(noteDescriptor)) ?? []
                    for note in notes {
                        let did = note.documentId
                        let text = note.bodyText
                        let tagString = note.userTagIds.map(\.uuidString).joined(separator: " ")
                        try? await pipeline.updateNoteText(
                            volumeId: vid, documentId: did,
                            bodyText: text,
                            userTagIds: tagString.isEmpty ? nil : tagString
                        )
                    }

                    #if DEBUG
                    print("[FRUSExplorer] Auto-indexed \(volumeId): \(summaries.count) summaries, \(notes.count) notes synced.")
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
                await dm.enqueueDownload(volumeId: entry.volumeId, downloadUrl: entry.downloadUrl)
            }
            #if DEBUG
            print("[FRUSExplorer] Deferred onboarding scope enqueued: \(toEnqueue.count) volumes.")
            #endif
        }

        // Observe real-time CloudKit sync events so the UI can surface failures
        // (e.g. schema migration needed, network error, quota exceeded) that occur
        // after container init — these are invisible without this observer.
        // Only installed when CloudKit was successfully initialised; the observer
        // captures only Sendable values before crossing into the @MainActor Task.
        if appState.cloudKitSyncEnabled {
            let eventNotificationName = NSPersistentCloudKitContainer.eventChangedNotification
            let eventUserInfoKey = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            NotificationCenter.default.addObserver(
                forName: eventNotificationName,
                object: nil,
                queue: .main
            ) { [appState] notification in
                // Extract only Sendable values on the calling thread before the
                // @MainActor hop, avoiding Sendable warnings on NSPersistentCloudKitContainer.Event.
                guard let event = notification.userInfo?[eventUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { return }
                let hasEnded  = event.endDate != nil
                let succeeded = event.succeeded
                let endDate   = event.endDate ?? Date.now

                // Build a detailed diagnostic from the error.
                // For CKError.partialFailure (code 2), the per-item sub-errors inside
                // CKPartialErrorsByItemIDKey are the real diagnosis; localizedDescription
                // only returns the useless "Some items failed." string.
                let errorMsg: String?
                if let error = event.error as? NSError {
                    errorMsg = Self.cloudKitDiagnostic(error)
                } else {
                    errorMsg = event.error?.localizedDescription
                }

                Task { @MainActor in
                    if !hasEnded {
                        appState.cloudKitSyncState = .syncing
                    } else if succeeded {
                        appState.cloudKitSyncState = .succeeded(endDate)
                    } else {
                        let msg = errorMsg ?? String(localized: "cloudkit.error.unknown",
                                                     defaultValue: "Unknown sync error")
                        appState.cloudKitSyncState = .failed(msg)
                        print("[CloudKit] ⚠️ Sync event failed: \(msg)")
                    }
                }
            }
        }

        // Proactively check iCloud account status and private zone existence.
        // The eventChanged notification only fires when NSPersistentCloudKitContainer
        // actually attempts an operation — silent failures (not signed in, zone deleted,
        // change token expired) never trigger it and are invisible without this check.
        appState.checkCloudKitHealth()

        // Re-check whenever the app returns to the foreground so the status bar
        // reflects sign-in/sign-out changes made in Settings while the app was suspended.
        let foregroundNotification: Notification.Name
        #if os(iOS)
        foregroundNotification = UIApplication.willEnterForegroundNotification
        #else
        foregroundNotification = NSApplication.willBecomeActiveNotification
        #endif
        NotificationCenter.default.addObserver(
            forName: foregroundNotification,
            object: nil,
            queue: .main
        ) { [appState] _ in
            Task { @MainActor in
                appState.checkCloudKitHealth()
            }
        }

        // Sync DocumentTagAssignment records from SwiftData into document_cache (FTS5)
        // so search tag-filtering reflects the CloudKit-synced state. Also runs the
        // one-time migration that promotes legacy document_cache.user_tag_ids values
        // (pre-DocumentTagAssignment) to proper SwiftData records.
        if let pipeline = appState.indexingPipeline,
           let store = appState.crossReferenceStore {
            Task {
                await syncDocumentTagAssignmentsToFTS5(
                    pipeline: pipeline,
                    store: store,
                    modelContainer: modelContainer
                )
            }
        }

        // Wire the logging context last so the session log is ready before any
        // user interaction fires (document opens, searches) but after the
        // SwiftData container and schema are fully initialised.
        appState.loggingContext = ModelContext(modelContainer)
    }

    // MARK: - Activity Continuation

    /// Handles a Handoff or deep-link continuation for a specific document.
    @MainActor
    private func continueDocumentActivity(_ activity: NSUserActivity) {
        guard let volumeId = activity.userInfo?["volumeId"] as? String,
              let documentId = activity.userInfo?["documentId"] as? String else { return }
        navigateToDocument(volumeId: volumeId, documentId: documentId, title: activity.title)
    }

    /// Pushes navigation to the requested document on both platforms.
    @MainActor
    private func navigateToDocument(volumeId: String, documentId: String, title: String?) {
        let entry = DocumentBrowserEntry(
            documentId: documentId,
            volumeId: volumeId,
            header: title ?? documentId
        )
        appState.pendingBrowseDocument = entry
        #if os(iOS)
        appState.activeTab = .browse
        #endif
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

    // MARK: - Document Tag Sync

    /// Synchronises `DocumentTagAssignment` records from SwiftData into
    /// `document_cache.user_tag_ids` (SQLite/FTS5) so that search tag-filtering
    /// reflects the CloudKit-synced state on every device.
    ///
    /// Also performs a **one-time migration** (guarded by a UserDefaults flag) that
    /// promotes legacy `document_cache.user_tag_ids` values written before
    /// `DocumentTagAssignment` existed into proper SwiftData records. This ensures
    /// devices that had direct tags before the migration don't lose them.
    ///
    /// Both operations are idempotent and run in a background Task so they don't
    /// block app launch.
    @MainActor
    private func syncDocumentTagAssignmentsToFTS5(
        pipeline: IndexingPipeline,
        store: CrossReferenceStore,
        modelContainer: ModelContainer
    ) async {
        let context = ModelContext(modelContainer)

        // MARK: One-time migration: document_cache.user_tag_ids → DocumentTagAssignment
        let migrationKey = "frus.migration.documentTagAssignment.v1"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            let legacyRows = (try? await store.documentsWithUserTags()) ?? []
            if !legacyRows.isEmpty {
                for row in legacyRows {
                    let vId = row.volumeId
                    let dId = row.documentId
                    // Only create records when no assignments already exist for this doc.
                    let existing = (try? context.fetch(
                        FetchDescriptor<DocumentTagAssignment>(
                            predicate: #Predicate<DocumentTagAssignment> { a in
                                a.volumeId == vId && a.documentId == dId
                            }
                        )
                    )) ?? []
                    if existing.isEmpty {
                        for tagId in row.userTagIds {
                            context.insert(DocumentTagAssignment(
                                volumeId: vId, documentId: dId, tagId: tagId
                            ))
                        }
                    }
                }
                try? context.save()
                #if DEBUG
                print("[FRUSExplorer] Migrated \(legacyRows.count) document(s) from document_cache.user_tag_ids to DocumentTagAssignment")
                #endif
            }
            UserDefaults.standard.set(true, forKey: migrationKey)
        }

        // MARK: Sync DocumentTagAssignment → document_cache.user_tag_ids
        // Groups assignments by (volumeId, documentId) and pushes the tag string to
        // the pipeline so the FTS5 search index reflects the SwiftData state.
        let allAssignments = (try? context.fetch(FetchDescriptor<DocumentTagAssignment>())) ?? []
        var byDocument: [String: [UUID]] = [:]
        for a in allAssignments {
            let key = "\(a.volumeId)/\(a.documentId)"
            byDocument[key, default: []].append(a.tagId)
        }
        for (key, tagIds) in byDocument {
            let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let tagString = tagIds.map(\.uuidString).joined(separator: " ")
            try? await pipeline.updateUserTagIds(
                volumeId: parts[0],
                documentId: parts[1],
                userTagIds: tagString.isEmpty ? nil : tagString
            )
        }
        #if DEBUG
        if !byDocument.isEmpty {
            print("[FRUSExplorer] Boot sync: pushed \(byDocument.count) document tag assignment(s) to FTS5")
        }
        #endif
    }

    // MARK: - CloudKit Diagnostics

    /// Converts a CloudKit `NSError` into a human-readable diagnostic string.
    ///
    /// For `CKError.partialFailure` (code 2), `localizedDescription` returns the
    /// useless "Some items failed." string. This function extracts the per-item
    /// sub-errors from `CKPartialErrorsByItemIDKey`, counts them by error code,
    /// and returns a summary like:
    ///
    ///   `"Partial sync failure (12 records): 10× changeTokenExpired, 2× serverRecordChanged"`
    ///
    /// The detailed breakdown is also written to the console via `print` so it
    /// survives app relaunch and can be captured in Console.app (subsystem:
    /// `bottsywattsy.FRUS-Explorer`).
    ///
    /// ## Interpreting common sub-error codes
    /// - **changeTokenExpired (21)**: Sync token stale after a schema change — usually
    ///   self-healing as `NSPersistentCloudKitContainer` fetches a new token.
    /// - **zoneNotFound (26)** / **userDeletedZone (28)**: The iCloud private database zone
    ///   was deleted (user reset iCloud data). The container should recreate it; if it does
    ///   not, sign out of iCloud and back in.
    /// - **serverRecordChanged (14)**: Merge conflict — auto-resolved by the container.
    /// - **notAuthenticated (9)**: No iCloud account. User must sign in via Settings.
    /// - **serverRejectedRequest (15)** / **incompatibleVersion (18)**: Schema or data
    ///   mismatch between the app and the deployed CloudKit schema. May require a
    ///   CloudKit Dashboard schema reset or an app update.
    /// - **unknownItem (11)**: Record being updated does not exist on the server. Usually
    ///   follows a zone/token reset; resolves after the container re-uploads.
    static func cloudKitDiagnostic(_ error: NSError) -> String {
        // Human-readable labels for the CloudKit error codes most likely to appear
        // in a SwiftData+CloudKit app during normal operation and schema migration.
        let codeNames: [Int: String] = [
            1:  "internalError",
            2:  "partialFailure",
            3:  "networkUnavailable",
            4:  "networkFailure",
            5:  "badContainer",
            6:  "serviceUnavailable",
            7:  "requestRateLimited",
            8:  "missingEntitlement",
            9:  "notAuthenticated",
            10: "permissionFailure",
            11: "unknownItem",
            12: "invalidArguments",
            14: "serverRecordChanged",
            15: "serverRejectedRequest",
            18: "incompatibleVersion",
            19: "constraintViolation",
            20: "operationCancelled",
            21: "changeTokenExpired",
            22: "batchRequestFailed",
            23: "zoneBusy",
            24: "badDatabase",
            25: "quotaExceeded",
            26: "zoneNotFound",
            28: "userDeletedZone",
        ]

        // For partialFailure, drill into the per-item errors.
        if error.domain == CKErrorDomain, error.code == CKError.partialFailure.rawValue,
           let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {

            var byCode: [Int: Int] = [:]
            for (_, subError) in partialErrors {
                byCode[(subError as NSError).code, default: 0] += 1
            }

            // Log the full breakdown (visible in Console.app).
            let breakdown = byCode.sorted { $0.value > $1.value }
                .map { code, count in "\(count)× \(codeNames[code] ?? "code \(code)")" }
                .joined(separator: ", ")
            print("[CloudKit] ⚠️ Partial failure: \(partialErrors.count) records — \(breakdown)")

            // Log a sample of item IDs for cross-referencing in CloudKit Dashboard.
            let sample = partialErrors.prefix(5)
            for (itemID, subError) in sample {
                let sub = subError as NSError
                print("[CloudKit]   item \(itemID): \(sub.domain) \(codeNames[sub.code] ?? "code \(sub.code)") — \(sub.localizedDescription)")
            }

            // Return the user-visible summary.
            return "Partial sync failure (\(partialErrors.count) record\(partialErrors.count == 1 ? "" : "s")): \(breakdown)"
        }

        // Non-partial error: include the code name if known.
        let name = codeNames[error.code] ?? "code \(error.code)"
        print("[CloudKit] ⚠️ \(error.domain) \(name): \(error.localizedDescription)")
        return "\(error.domain) \(name): \(error.localizedDescription)"
    }
}

// MARK: - Int Helper

private extension Int {
    /// Returns this value if positive, otherwise returns `default`.
    func nonZeroOrDefault(_ default: Int) -> Int { self > 0 ? self : `default` }
}
