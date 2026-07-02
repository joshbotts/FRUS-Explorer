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
import CryptoKit      // SHA-256 content digest for open-with collection de-duplication
import TipKit
#if os(iOS)
import BackgroundTasks
import os
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
/// | `"frus.history"`                | Window        | Complete reading + search history, project filter|
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
///   3.8 — Session 2026-06-07: macOS "History" CommandMenu added (Documents Visited /
///          Searches Executed submenus, last ten each, "Complete History…" item);
///          frus.history Window scene added hosting the new HistoryWindowView
///   3.9 — Session 2026-07-02: open-with .fruscollection import surfaces its result —
///          macOS opens/foregrounds the Collections window with the import selected
///          (pendingCollectionSelection hand-off), failures alert on both platforms
///          (previously a DEBUG print), and re-opening a byte-identical file
///          re-surfaces the prior import instead of minting a CloudKit-synced duplicate
#if os(iOS)
/// Receives the UIKit lifecycle callbacks SwiftUI does not surface.
///
/// The only one this app needs is the background-`URLSession` wake-up: when all
/// events for `BackgroundDownloadEngine`'s session have been delivered after the
/// system relaunched the app in the background, UIKit requires the stored
/// completion handler to be invoked. The engine calls it from
/// `urlSessionDidFinishEvents(forBackgroundURLSession:)`.
final class FRUSAppDelegate: NSObject, UIApplicationDelegate {

    /// Stores the completion handler and ensures the engine's session is alive so
    /// the queued events (finished volume downloads) are delivered and the files
    /// moved into the volumes directory.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == BackgroundDownloadEngine.sessionIdentifier else {
            completionHandler()
            return
        }
        // UIKit's completion handler is not Sendable by signature, but its
        // contract is "call once, on the main thread" — the MainActor hop below
        // honours that, making the unsafe transfer sound.
        nonisolated(unsafe) let handler = completionHandler
        BackgroundDownloadEngine.shared.storeBackgroundCompletionHandler {
            Task { @MainActor in handler() }
        }
    }
}
#endif

@main
struct FRUSExplorerApp: App {

    @State private var appState = AppState()
    #if os(iOS)
    @UIApplicationDelegateAdaptor(FRUSAppDelegate.self) private var appDelegate
    #endif
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    /// Non-nil to present an alert for a failed open-with `.fruscollection` import.
    /// Set by `importOpenedCollection` on both platforms — before Session 2026-07-02
    /// a malformed file failed with only a DEBUG print, so the double-click looked
    /// like the app silently ignored it.
    @State private var collectionOpenError: String? = nil

    /// Session-scoped memory of open-with collection imports: SHA-256 digest of the
    /// file's bytes → the id of the `Collection` it created. Re-opening a byte-identical
    /// file re-surfaces that collection (if it still exists) instead of minting a
    /// duplicate — each `NativeCollectionSerializer.apply` otherwise creates a fresh
    /// `Collection.id` that syncs everywhere via CloudKit. Deliberately not persisted:
    /// the in-app Import button remains the way to intentionally import a copy.
    @State private var openedCollectionImports: [Data: UUID] = [:]

    // `makeFRUSContainer()` returns a tuple so the CloudKit-enabled flag (and, on
    // failure, the actual `NSError` — see `bootDownloadManager`'s use of
    // `cloudKitDiagnostic(_:)`) are available without a second call. `modelContainer`
    // is a computed property for backward compatibility with all existing
    // `.modelContainer(modelContainer)` call sites.
    private let _containerSetup = ModelContainer.makeFRUSContainer()
    private var modelContainer: ModelContainer { _containerSetup.container }

    // MARK: - TipKit

    /// One-time TipKit bootstrap shared by both platform inits. Drives the
    /// curated discovery tips in `DiscoveryTips.swift`. Failure is non-fatal —
    /// the tips simply never appear.
    private static func configureTipKit() {
        do {
            try Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault),
            ])
        } catch {
            #if DEBUG
            print("[FRUSExplorerApp] TipKit configuration failed: \(error)")
            #endif
        }
    }

    #if os(macOS)
    /// macOS launch setup: TipKit only (no background-task registration).
    init() {
        Self.configureTipKit()
    }
    #endif

    // MARK: - Background Task Registration (iOS)

    #if os(iOS)
    /// Task identifier registered in BGTaskSchedulerPermittedIdentifiers (Info.plist).
    private static let indexingBGTaskID = "bottsywattsy.FRUS-Explorer.indexing"

    #if DEBUG
    /// DEBUG accessor so the summarization probe view can name the identifier to
    /// simulate. The probe reuses the indexing task (no second BG identifier) — when
    /// armed, an indexing wake runs the probe instead of indexing.
    static var debugIndexingBGTaskID: String { indexingBGTaskID }
    #endif

    /// Conservative per-wake cap for background summarization. Sized small because a
    /// single on-device summary runs several seconds under background QoS; the run
    /// is resumable, so the rest are picked up on later wakes.
    private static let backgroundSummarizationBatchSize = 6

    /// Resumes the persisted background-summarization request (if the user opted in)
    /// for a bounded batch, rebuilding the run's dependencies from `AppState`. Clears
    /// the request once its scope is fully summarized.
    @MainActor
    private static func runBackgroundSummarizationBatch(appState: AppState, modelContext: ModelContext) async {
        guard BackgroundSummarizationRequestStore.isEnabled,
              let request = BackgroundSummarizationRequestStore.load(),
              let service = appState.backgroundSummarizationService,
              let downloadManager = appState.downloadManager else { return }

        let descriptor = FetchDescriptor<SummarizationPrompt>(
            predicate: #Predicate { $0.id == request.promptId }
        )
        guard let prompt = try? modelContext.fetch(descriptor).first else {
            // The prompt was deleted — drop the stale request.
            BackgroundSummarizationRequestStore.clear()
            return
        }
        let snapshot = SummarizationPromptSnapshot(from: prompt)
        let manifest = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        var urls: [String: URL] = [:]
        for entry in manifest where downloadManager.isVolumeDownloaded(entry.volumeId) {
            urls[entry.volumeId] = downloadManager.volumeURL(for: entry.volumeId)
        }

        let result = await service.processBackgroundBatch(
            scope: request.scope,
            snapshot: snapshot,
            promptId: request.promptId,
            provider: AppleIntelligenceProvider.shared,
            downloadedVolumeURLs: urls,
            manifestEntries: manifest,
            activeProjectId: appState.activeProjectId,
            maxDocuments: Self.backgroundSummarizationBatchSize
        )
        if result.scopeComplete {
            BackgroundSummarizationRequestStore.clear()
        }
    }

    /// Drains the word-cloud precompute queue within the background task's remaining
    /// budget, one scope at a time. A scope is dequeued only when finished; if the
    /// task is cancelled (budget expired) the loop stops and the rest stay queued
    /// for the next wake.
    @MainActor
    private static func drainWordCloudPrecompute(appState: AppState, modelContext: ModelContext) async {
        guard WordCloudPrecomputeQueue.isEnabled else { return }
        for signature in WordCloudPrecomputeQueue.pending() {
            if Task.isCancelled { break }
            let finished = await WordCloudLoader.precompute(
                signature: signature, appState: appState, modelContext: modelContext
            )
            if finished {
                WordCloudPrecomputeQueue.remove(signature)
            } else {
                break
            }
        }
    }

    /// Registers the BGProcessingTask handler with the system.
    ///
    /// Must be called before the app finishes launching. `appState` is a reference-type
    /// @Observable class; capturing it here is safe because the App struct is instantiated
    /// exactly once per process lifetime and @State persists the same instance.
    init() {
        Self.configureTipKit()
        let state = appState
        let container = modelContainer
        // The launch handler MUST be `@Sendable` (non-isolated). BGTaskScheduler invokes
        // it on its own background dispatch queue (`com.apple.BGTaskScheduler …`), not the
        // main actor. Without `@Sendable` the closure inherits `App.init`'s `@MainActor`
        // isolation, and Swift's executor assertion (`swift_task_isCurrentExecutor`) traps
        // the instant the system runs it off-main. The actual work still hops to the main
        // actor via the inner `Task { @MainActor in … }`.
        let launchHandler: @Sendable (BGTask) -> Void = { task in
            guard let bgTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            // The expiration handler fires on a background thread while the @MainActor Task
            // may be completing concurrently. Guard with a lock so setTaskCompleted is called
            // at most once regardless of which side wins the race.
            let completed = OSAllocatedUnfairLock(initialState: false)
            let complete: @Sendable (Bool) -> Void = { success in
                let first = completed.withLock { called -> Bool in
                    guard !called else { return false }
                    called = true
                    return true
                }
                if first { bgTask.setTaskCompleted(success: success) }
            }
            // Run on MainActor so we can read @MainActor-isolated AppState properties.
            let indexingTask = Task { @MainActor in
                guard let pipeline = state.indexingPipeline else {
                    complete(false)
                    return
                }
                #if DEBUG
                // When the summarization probe is armed, spend this wake measuring
                // FoundationModels under background conditions instead of indexing.
                if SummarizationBackgroundProbe.isArmed {
                    SummarizationBackgroundProbe.disarm()
                    await SummarizationBackgroundProbe.runUntilExpiration(appState: state)
                    complete(true)
                    return
                }
                #endif
                let volumesToIndex = Array(state.interruptedVolumeIds)
                if volumesToIndex.isEmpty {
                    // No interrupted volumes: index only downloaded-but-unindexed
                    // volumes, never the whole corpus. A healthy, fully-indexed corpus
                    // yields an empty list, so a backgrounding whose only pending work
                    // is word-cloud precompute no longer triggers a spurious full
                    // reindex (which lit the genuine "Indexing…" banner and looked like
                    // an unexplained reindex after a manual rebuild).
                    let unindexed = (try? await pipeline.unindexedDownloadedVolumeIds()) ?? []
                    for volumeId in unindexed {
                        try? await pipeline.indexVolume(volumeId)
                    }
                } else {
                    for volumeId in volumesToIndex {
                        try? await pipeline.indexVolume(volumeId)
                    }
                }
                // With any remaining budget, precompute queued heavy word clouds
                // (corpus / subseries) into the on-disk cache so they open instantly.
                await Self.drainWordCloudPrecompute(appState: state, modelContext: container.mainContext)
                // Then summarize a small, resumable batch if the user opted in. Last
                // because it's the most expensive/thermal work; the cap + expiration
                // keep it conservative, and `shouldSkip` resumes it next wake.
                await Self.runBackgroundSummarizationBatch(appState: state, modelContext: container.mainContext)
                complete(true)
            }
            // System calls this when budget expires. Cancel in-flight work; the
            // IndexingStateTracker already marks any in-progress volume as interrupted.
            bgTask.expirationHandler = {
                indexingTask.cancel()
                complete(false)
            }
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.indexingBGTaskID,
            using: nil,
            launchHandler: launchHandler
        )
    }

    #endif

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
                            documentYear: appState.currentSourceNoteYear,
                            indexingPipeline: appState.indexingPipeline,
                            onRelatedDocumentTapped: { vid, did in
                                let entry = DocumentBrowserEntry(
                                    documentId: did, volumeId: vid,
                                    documentNumber: nil, header: did, dateline: nil, sourceNote: nil
                                )
                                appState.pendingBrowseDocument = entry
                            },
                            documentHeader: appState.currentSourceNoteHeader,
                            documentDateline: appState.currentSourceNoteDateline,
                            documentVolumeId: appState.currentSourceNoteVolumeId,
                            documentId: appState.currentSourceNoteDocumentId
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

        // MARK: - Cross-Reference Graph Window (iPadOS Stage Manager)
        //
        // Mirrors the macOS "frus.crossReferenceGraph" Window scene. Reads
        // appState.currentGraphEntry — set by the caller before openWindow(id:).
        // Single-instance: opening the same id focuses the existing window, and
        // `.id(entry.id)` retargets the graph when reopened for another document.
        WindowGroup("Cross-Reference Graph", id: "frus.crossReferenceGraph.ios") {
            Group {
                if let entry = appState.currentGraphEntry,
                   let store = appState.crossReferenceStore {
                    let downloaded: Set<String> = {
                        guard let dm = appState.downloadManager else { return [] }
                        let known = appState.manifestStore.diffResult?.known ?? []
                        return Set(known.compactMap {
                            dm.isVolumeDownloaded($0.volumeId) ? $0.volumeId : nil
                        })
                    }()
                    CrossReferenceGraphView(
                        entry: entry,
                        crossReferenceStore: store,
                        downloadedVolumeIds: downloaded
                    )
                    .id(entry.id)
                } else {
                    ContentUnavailableView(
                        String(localized: "graphWindow.empty.title",
                               defaultValue: "No Document Selected"),
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text(
                            String(localized: "graphWindow.empty.detail",
                                   defaultValue: "Open a document, then tap Cross-References in the toolbar.")
                        )
                    )
                }
            }
            .environment(appState)
            .modelContainer(modelContainer)
        }
        #endif
        #if os(macOS)
        // MARK: - Document Window (macOS native tabbing)
        //
        // Opening documents as separate windows lets macOS gather them into native
        // tabs (Window ▸ Merge All Windows / the window tab bar) and view them side
        // by side. Additive — the primary `mainWindowScene` remains the default;
        // these open only via openWindow(value: DocumentWindowID(...)) (the "New
        // Window" button in ResearchStripView). Value identity is (volumeId,
        // documentId), so reopening the same document focuses its existing window.
        WindowGroup(for: DocumentWindowID.self) { $windowID in
            Group {
                if let id = windowID {
                    MacDocumentWindowView(windowID: id)
                } else {
                    ContentUnavailableView(
                        String(localized: "documentWindow.empty.title",
                               defaultValue: "No Document"),
                        systemImage: "doc.text"
                    )
                }
            }
            .environment(appState)
            .modelContainer(modelContainer)
        }

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

        // MARK: - Word Cloud Window
        Window(String(localized: "wordcloud.window.title", defaultValue: "Word Cloud"),
               id: "frus.wordcloud") {
            WordCloudWindowContent()
                .environment(appState)
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 760, height: 620)

        // MARK: - Chronology Window
        Window(String(localized: "chronology.window.title", defaultValue: "Chronology"),
               id: "frus.chronology") {
            ChronologyView()
                .environment(appState)
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 720, height: 600)

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

        // MARK: - Complete History Window
        //
        // Standalone combined reading + search history list with an optional
        // project filter, reachable via the "History" menu's "Complete
        // History…" item. The menu itself shows only the ten most-recent
        // documents visited and searches executed.
        Window(String(localized: "history.window.title", defaultValue: "History"),
               id: "frus.history") {
            HistoryWindowView()
                .environment(appState)
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 640, height: 600)

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

        // MARK: - Research Guide Window
        //
        // Standalone presentation of the educational pages normally shown
        // while the first index builds. Reachable independently of indexing
        // via the Help menu, for researchers who want to revisit the FRUS
        // primer or jump straight to a specific topic (Source Explorer,
        // research strategies, etc. open it pre-scrolled to the relevant
        // page via `appState.researchGuideInitialPageId`).
        Window(String(localized: "researchGuide.window.title", defaultValue: "FRUS Research Guide"),
               id: "frus.researchGuide") {
            ResearchGuideView()
                .environment(appState)
        }
        .defaultSize(width: 880, height: 620)
        #endif
    }

    /// The primary `WindowGroup` scene, with macOS-specific modifiers applied conditionally.
    private var mainWindowScene: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(modelContainer)
                #if os(macOS)
                // Widened from the implicit default so the toolbar's leading
                // back button, centred document title, and trailing tool
                // launchers (Search/Graph/Info/Research) never need to
                // collapse into the system overflow chevron at typical
                // window widths — that collapse was combining the custom
                // "Search" button with the system back-history popover into
                // a single confusing overflow menu.
                .frame(minWidth: 980, minHeight: 600)
                #endif
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
                // A shared native collection opened from Files / Finder / AirDrop (Phase 4 / D9).
                .onOpenURL { url in
                    importOpenedCollection(url)
                }
                // Failed open-with import → user-visible alert (both platforms). The main
                // window is what the OS activates on an open-with, so it is where the user
                // is looking when the import fails.
                .alert(String(localized: "collections.open.error.title",
                              defaultValue: "Couldn’t Open Collection"),
                       isPresented: Binding(get: { collectionOpenError != nil },
                                            set: { if !$0 { collectionOpenError = nil } })) {
                    Button(String(localized: "collections.import.error.ok", defaultValue: "OK"),
                           role: .cancel) { collectionOpenError = nil }
                } message: {
                    Text(collectionOpenError ?? "")
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

            // Append a "FRUS Research Guide" item to the Help menu (after the
            // system search field) so the standalone primer is reachable
            // independently of the first-run indexing flow — mirroring the
            // dedicated About Window pattern above, but surfaced from Help
            // rather than the app menu since it's reference content, not
            // settings or app metadata.
            CommandGroup(after: .help) {
                Button(String(localized: "menu.researchGuide",
                              defaultValue: "FRUS Research Guide")) {
                    openWindow(id: "frus.researchGuide")
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

            // "History" menu — last ten documents visited and searches executed,
            // plus a "Complete History…" item opening the combined, project-
            // filterable HistoryWindowView (frus.history). appState/openWindow
            // are passed as explicit init params (mirroring how the surrounding
            // CommandGroup blocks capture them directly) rather than relying on
            // @Environment propagation into .commands content.
            CommandMenu(String(localized: "menu.history", defaultValue: "History")) {
                HistoryMenuContent(appState: appState, openWindow: openWindow)
                    .modelContainer(modelContainer)
            }
        }
        #endif
    }

    // MARK: - Private

    /// Imports a native `.fruscollection` file opened from Files / Finder / AirDrop (Phase 4 /
    /// D9): reconstructs the collection into the shared store, scopes it to the active project
    /// (so it's visible under the active-project filter, as new/imported collections are), and
    /// surfaces the result — switching to the Collections tab on iOS, opening/foregrounding
    /// the Collections window with the import selected on macOS (before Session 2026-07-02
    /// macOS gave no feedback at all, so users re-opened the file and minted silent,
    /// CloudKit-synced duplicates). Re-opening a byte-identical file this session re-surfaces
    /// the collection it already created (see `openedCollectionImports`) instead of importing
    /// a duplicate. Failures present the `collectionOpenError` alert on the main window.
    @MainActor
    private func importOpenedCollection(_ url: URL) {
        guard url.pathExtension.lowercased() == NativeCollectionSerializer.fileExtension else { return }
        let context = modelContainer.mainContext
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)

            let digest = Data(SHA256.hash(data: data))
            if let existingId = openedCollectionImports[digest],
               collectionExists(existingId, in: context) {
                surfaceOpenedCollection(existingId)
                return
            }

            let file = try NativeCollectionSerializer.decode(data)
            let imported = NativeCollectionSerializer.apply(file, into: context)
            if let pid = appState.activeProjectId { imported.projectIds = [pid] }
            try context.save()
            openedCollectionImports[digest] = imported.id
            surfaceOpenedCollection(imported.id)
        } catch {
            #if DEBUG
            print("[FRUSExplorerApp] .fruscollection import failed: \(error)")
            #endif
            collectionOpenError = error.localizedDescription
        }
    }

    /// Surfaces a just-imported (or re-opened) collection: switches to the Collections tab on
    /// iOS; on macOS opens the Collections window, raises it in front of the main window the
    /// OS just activated, and hands the id off via `appState.pendingCollectionSelection` so
    /// `MacCollectionManagerView` selects it. The hand-off is set *before* `openWindow` so a
    /// freshly created window's `.task` consumer sees it (mirroring the `currentGraphEntry` /
    /// `currentSourceNote` ordering).
    @MainActor
    private func surfaceOpenedCollection(_ id: UUID) {
        #if os(iOS)
        appState.activeTab = .collections
        #else
        appState.pendingCollectionSelection = id
        openWindow(id: "frus.collections")
        bringMacWindowToFront(id: "frus.collections")
        #endif
    }

    /// Whether a `Collection` with `id` still exists in the store — a prior open-with import
    /// may have been deleted since; in that case re-opening the file imports it anew.
    @MainActor
    private func collectionExists(_ id: UUID, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Collection>(predicate: #Predicate { $0.id == id })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

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
        //
        // `cloudKitInitError` previously held a hardcoded "CloudKit initialisation
        // failed. Check console for details." placeholder — useless to anyone who
        // can't attach a console, and it discarded the actual NSError that
        // `makeFRUSContainer()` already had in hand. Run it through the same
        // `cloudKitDiagnostic(_:)` formatter used for live sync-event failures so
        // the UI shows the real domain/code/description (e.g. "CKErrorDomain
        // serverRejectedRequest: …" — the signature of an undeployed CloudKit
        // schema change; see the "schema migrations" note on `frusModelTypes`).
        appState.cloudKitSyncEnabled = _containerSetup.cloudKitEnabled
        if !_containerSetup.cloudKitEnabled {
            if let initError = _containerSetup.initError {
                appState.cloudKitInitError = Self.cloudKitDiagnostic(initError)
            } else {
                appState.cloudKitInitError = String(
                    localized: "cloudkit.initError.skipped",
                    defaultValue: "CloudKit was skipped for this session (test or preview mode)."
                )
            }
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
            // Collapse any CloudKit-sync duplicate tags / projects / collections
            // (SwiftData + CloudKit can't enforce unique `id`s) so they stop
            // appearing twice in lists.
            DuplicateRecordCleanup.run(context: modelContainer.mainContext)
            // Optional cross-device settings sync: mirror UserDefaults to/from a
            // CloudKit-synced record when this device has opted in. Starting it
            // installs the change observer and performs an initial pull if enabled.
            let settingsSync = SettingsSyncCoordinator(context: modelContainer.mainContext)
            appState.settingsSync = settingsSync
            settingsSync.start()
            // The Zotero API key syncs via iCloud Keychain but its resolved account
            // identity doesn't; re-resolve it from the synced key on this device.
            Task { await ZoteroAccountStore.shared.resolveAccountIfNeeded() }
            #if os(iOS)
            // Mirror background-summarization progress onto a Live Activity.
            appState.startObservingSummarizationProgress()
            #endif
            // Seed cached indexed-volume IDs so StatusBarView / MainTabView badges
            // use O(1) Set lookup instead of per-volume SQLite queries in the render loop.
            appState.seedIndexedVolumeIds(pipeline: pipeline)
            appState.crossReferenceStore = try? CrossReferenceStore(databaseURL: dbURL)
            appState.personMentionStore = try? PersonMentionStore(databaseURL: dbURL)
            appState.searchService = SearchService(
                fts5Store: store,
                pipeline: pipeline,
                personMentionStore: appState.personMentionStore
            )
            appState.analyticsService = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)
            appState.wordFrequencyService = WordFrequencyService(pipeline: pipeline)
            let pageRangeStore = try? PageRangeStore(databaseURL: dbURL)
            appState.pageRangeStore = pageRangeStore
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

            // Trigger background index migrations when schema versions require it.
            // Two independent flags, with different costs:
            //   • FTS rebuild (didRebuildSchema OR a previous rebuild never finished):
            //     the FTS5 tables were recreated (external-content redesign). The
            //     index is rebuilt from document_cache via the FTS5 `rebuild`
            //     command — tens of seconds, no XML re-parse. The OR with
            //     needsFTSRebuildReindex makes this self-healing: if the app is
            //     killed between the schema drop and the rebuild, the UserDefaults
            //     flag is still unset on next launch and the rebuild re-runs.
            //   • Date re-index: the date-extraction strategy changed; requires a
            //     full XML re-parse via indexAllVolumes (which also repopulates the
            //     FTS tables through the document_cache sync triggers, so a pending
            //     FTS rebuild is satisfied by it too).
            let ftsRebuildNeeded = store.didRebuildSchema || pipeline.needsFTSRebuildReindex
            let dateReindexNeeded = pipeline.needsDateReindex
            // Snapshot the user's person-cluster corrections (Phase 3) so consolidation re-applies
            // them as constraints. Captured here on the MainActor; the value type is Sendable.
            let personOverrides = PersonClusterOverrideStore.snapshot(context: modelContainer.mainContext)
            if dateReindexNeeded {
                Task {
                    #if DEBUG
                    print("[FRUSExplorer] Background re-index triggered (dateReindex=true, ftsRebuild=\(ftsRebuildNeeded)).")
                    #endif
                    try? await pipeline.indexAllVolumes()
                    await pipeline.markDateReindexComplete()
                    if ftsRebuildNeeded { await pipeline.markFTSRebuildReindexComplete() }
                    // Rebuild the materialised person rollup after the persons table changes.
                    try? await pipeline.consolidatePersonRollupIfNeeded(overrides: personOverrides)
                    #if DEBUG
                    print("[FRUSExplorer] Background re-index complete.")
                    #endif
                }
            } else if ftsRebuildNeeded {
                Task {
                    #if DEBUG
                    print("[FRUSExplorer] FTS rebuild from document_cache triggered.")
                    #endif
                    if (try? await pipeline.rebuildSearchIndexFromCache()) != nil {
                        await pipeline.markFTSRebuildReindexComplete()
                    }
                    try? await pipeline.consolidatePersonRollupIfNeeded(overrides: personOverrides)
                    #if DEBUG
                    print("[FRUSExplorer] FTS rebuild from document_cache complete.")
                    #endif
                }
            } else {
                // Normal launch: rebuild the person rollup if its version was bumped or the
                // member set has drifted (volumes added/removed). Cheap no-op when up to date.
                Task { try? await pipeline.consolidatePersonRollupIfNeeded(overrides: personOverrides) }
            }

            // Reconcile downloads that completed without a post-download indexing
            // pass — e.g. transfers the background session daemon finished while
            // the app was not running, or volumes whose indexing previously failed.
            // Volumes marked interrupted are excluded (the user resolves those
            // explicitly from the amber badge). Skipped when a full date re-index
            // is queued above, which re-parses everything anyway.
            if !dateReindexNeeded {
                let indexedIds = (try? pipeline.allIndexedVolumeIds()) ?? []
                let interrupted = appState.interruptedVolumeIds
                let unindexed = IndexingPipeline
                    .findDownloadedVolumes(in: volumesDir)
                    .map(\.volumeId)
                    .filter { !indexedIds.contains($0) && !interrupted.contains($0) }
                if !unindexed.isEmpty {
                    Task {
                        #if DEBUG
                        print("[FRUSExplorer] Reconciling \(unindexed.count) downloaded-but-unindexed volumes.")
                        #endif
                        for volumeId in unindexed.sorted() {
                            try? await pipeline.indexVolume(volumeId)
                        }
                    }
                }
            }

            // Push all existing SwiftData user annotations into the search index.
            // Summaries/notes are created after indexing and stored only in SwiftData;
            // this scan handles prior-session data and CloudKit-synced records from
            // other devices. Runs in a background Task so it doesn't block boot.
            //
            // Cost: in the steady state this is nearly free — updateCacheColumns
            // skips rows whose values are already current (zero-row UPDATE, no FTS5
            // trigger fires), so only new or changed records cause index writes.
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
            concurrencyLimit: UserDefaults.standard.integer(forKey: SettingsKeys.concurrentDownloadLimit).nonZeroOrDefault(4),
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
            },
            onVolumeDeleted: indexPipeline.map { pipeline in
                // Remove the volume's FTS5 rows, auxiliary-table rows, and Spotlight
                // items whenever a volume file is deleted, regardless of which UI
                // path triggered the deletion. removeVolume is idempotent, so paths
                // that already cleaned the index themselves are unaffected.
                { @Sendable [appState] volumeId in
                    try? await pipeline.removeVolume(volumeId)
                    await MainActor.run {
                        appState.indexedVolumeIds.remove(volumeId)
                    }
                    // Drop any cached document ASTs so a re-download can never
                    // serve stale content from the deleted file.
                    await appState.documentASTCache.removeVolume(volumeId)
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
                        // A completed import may have brought down updated settings;
                        // pull them into UserDefaults if this device syncs settings.
                        appState.settingsSync?.syncNowIfEnabled()
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
                // Returning to the foreground is a natural moment to adopt any settings
                // changed on another device while this one was suspended.
                appState.settingsSync?.syncNowIfEnabled()
                // The Zotero key may have synced in via iCloud Keychain while suspended.
                await ZoteroAccountStore.shared.resolveAccountIfNeeded()
            }
        }

        // When the app enters the background on iOS, submit a BGProcessingTask so
        // in-progress or interrupted indexing can continue for up to 30 minutes.
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [appState] _ in
            Task { @MainActor in
                let hasIndexingWork = appState.currentIndexingProgress != nil
                    || !appState.interruptedVolumeIds.isEmpty
                let hasPrecomputeWork = WordCloudPrecomputeQueue.isEnabled
                    && WordCloudPrecomputeQueue.hasPending
                let hasSummarizationWork = BackgroundSummarizationRequestStore.hasPending
                guard hasIndexingWork || hasPrecomputeWork || hasSummarizationWork else { return }
                let request = BGProcessingTaskRequest(identifier: Self.indexingBGTaskID)
                request.requiresNetworkConnectivity = false
                request.requiresExternalPower = false
                try? BGTaskScheduler.shared.submit(request)
                #if DEBUG
                print("[FRUSExplorer] BGProcessingTask scheduled on background entry.")
                #endif
            }
        }
        #endif

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
