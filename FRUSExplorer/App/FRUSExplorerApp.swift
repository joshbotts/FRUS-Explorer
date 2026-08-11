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
import os              // Logger — CloudKit sync telemetry (both platforms, #188-C.1)
#if os(iOS)
// @preconcurrency: BGProcessingTask is not Sendable, but the BGTaskScheduler contract
// requires capturing the task in both the expiration handler and the work closure. The
// capture below is guarded by an OSAllocatedUnfairLock so setTaskCompleted runs at most
// once whichever side wins the race — the framework simply predates Sendable annotation.
@preconcurrency import BackgroundTasks
#endif

/// os.Logger for CloudKit sync events (#188-C.1), shared by the app boot code and `AppState`'s
/// health check. Fields are marked `.public` only when they are on the redaction allow-list
/// (phase, domain/code/code-name, aggregate counts); anything user-identifying is simply never
/// passed to it (default-deny — an unmarked value redacts).
let cloudKitLog = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "CloudKit")

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
/// ## Window Architecture
/// Recounted from this file's scene body, 2026-07-18 (provenance PR 2). **Keep this table in
/// sync when adding a scene** — it drifted before (six scenes missing at the 2026-07-15 #241
/// count, then `relatedDocumentsScene` omitted again by #308), and
/// `Planning/Completed/241-iPad-Windowing-Investigation.md` depends on it being true.
///
/// **Shared:** the default `WindowGroup` main window (onboarding → `MainTabView` on iOS,
/// `MainWindowView` on macOS), plus `archivalNeighborsScene` and `relatedDocumentsScene`,
/// declared once and referenced from both platform regions.
///
/// **iOS auxiliary scenes (5)** — all `WindowGroup`; windowed multitasking only — and note
/// `supportsMultipleWindows` is plist-derived, NOT strictly "Stage Manager" (an iPad in Full
/// Screen Apps mode may still report true — unprobed; #241 review). `openWindow` is a no-op
/// where it is false, so every caller keeps a sheet/inline fallback:
/// | Scene                           | Type          | State source                                     |
/// |---------------------------------|---------------|--------------------------------------------------|
/// | (`DocumentWindowID`)            | WindowGroup   | Value-based — value restores; CONTENT dead-ends in a permanent spinner when the volume is gone or boot loses the race (#323) |
/// | (`SourceExplorerRequest`)       | WindowGroup   | Value-based — restores correctly (#317 port from the old `currentSourceNote`-reading id scene) |
/// | (`GraphWindowRequest`)          | WindowGroup   | Value-based — restores correctly (#317 port from the old `currentGraphEntry`-reading id scene) |
/// | (`ArchivalNeighborsRequest`)    | WindowGroup   | Value-based — restores correctly (#241 port): boot-race guard + honest empty state verified by the #241 review |
/// | (`RelatedDocumentsRequest`)     | WindowGroup   | Value-based — find-related work list (#308 Phase 2b), shared `relatedDocumentsScene` |
///
/// **macOS auxiliary scenes (22)** — 17 singleton `Window`, 4 `WindowGroup`, 1 `Settings`.
/// `SwiftUI.Window` is `@available(iOS, unavailable)`, which is why no singleton scene below
/// can port to iPad as-is; each would become a `WindowGroup` (#241 §3):
/// | Scene ID                        | Type          | Purpose                                          |
/// |---------------------------------|---------------|--------------------------------------------------|
/// | (`DocumentWindowID`)            | WindowGroup   | Document windows — native tabbing                |
/// | `"frus.search"`                 | Window        | Full-text search — persists while reading docs   |
/// | `"frus.citationLookup"`         | Window        | Citation lookup (⌘⇧F) — the other find flow      |
/// | `"frus.corpusBrowser"`          | Window        | Corpus browser — independent browsable window    |
/// | `"frus.people"`                 | Window        | Cross-volume person index (B5)                   |
/// | `"frus.crossReferenceGraph"`    | Window        | Cross-reference graph — floating, per-document   |
/// | `"frus.sourceExplorer"`         | Window        | Source explorer — floating, per-document         |
/// | (`ArchivalNeighborsRequest`)    | WindowGroup   | Archival Neighbors — value-based, per source (S6)|
/// | (`RelatedDocumentsRequest`)     | WindowGroup   | Related Documents — value-based work list (#308 Phase 2b)|
/// | (`CrossVolumeProvenanceRequest`)| WindowGroup   | Cross-volume provenance — value-based, per collection (B2)|
/// | `"frus.analytics"`              | Window        | Corpus frequency analytics — Swift Charts        |
/// | `"frus.personAnalytics"`        | Window        | Person analytics — most-mentioned + trajectories |
/// | `"frus.crossRefAnalytics"`      | Window        | Cross-reference analytics — in-degree, distribution, heat matrix, PageRank |
/// | `"frus.archivalAnalytics"`      | Window        | Archival analytics — era × collection rankings, co-citation network, reference flows, your library |
/// | `"frus.wordcloud"`              | Window        | Word cloud (note the lowercase `c`)              |
/// | `"frus.chronology"`             | Window        | Chronology                                       |
/// | `"frus.research"`               | Window        | Research — notes, tags, collections, highlights  |
/// | `"frus.collections"`            | Window        | Collections — manage, edit, and export           |
/// | (`NoteComposerRequest`)         | WindowGroup   | Note composer — value-based, off the Window menu (#363) |
/// | `"frus.history"`                | Window        | Complete reading + search history, project filter|
/// | (`Settings`)                    | Settings      | Settings scene (`FRUSSettingsView`)              |
/// | `"about"`                       | Window        | About FRUS Explorer                              |
/// | (`ResearchGuideWindowID`)       | WindowGroup   | FRUS Research Guide — value-based, off the Window menu (#363) |
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
///          value-based WindowGroup(for: SourceExplorerRequest/GraphWindowRequest) for the
///          Source Explorer + cross-reference-graph windows (#317; formerly id-based scenes
///          reading process-global pending state that restored empty)
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
///   4.0 — Session 2026-07-03 (ui-audit #2): TextFormattingCommands() added to .commands —
///          the macOS rich-text prose editors (NSTextView-backed) rely on the Format menu
///          for their ⌘B/⌘I/⌘U key equivalents, which were inoperative without it
///   4.1 — Session 2026-07-04 (Source Explorer Phase 5 S6): macOS Archival Neighbors
///          window scene added — value-based WindowGroup(for: ArchivalNeighborsRequest.self)
///          replacing every macOS `.sheet` presentation of ArchivalNeighborsSheet
///          (window-per-distinct-request, Codable restoration; see the scene comment)
///   4.2 — Session 2026-07-04 (macOS UI audit B2/B4): Cross-Volume Provenance window
///          scene added (value-based WindowGroup(for: CrossVolumeProvenanceRequest.self),
///          same pattern as S6); Citation Lookup became the frus.citationLookup Window
///          scene owning ⌘⇧F (mirroring frus.search's ⌘F) — the CommandGroup item that
///          set the removed appState.showCitationLookup flag is gone
///   4.3 — Session 2026-07-04 (macOS UI audit B5): People window scene added
///          (frus.people hosting PeopleWindowView) — replaces the Corpus Browser's
///          PersonIndexView sheet and its stacked person-detail sheet
///   4.4 — Session 2026-07-04 (macOS UI audit C1 + gaps 16/19): Research Note
///          composer window scene added (frus.noteComposer hosting
///          NoteComposerWindowView) — replaces the document-window note-editor
///          sheets; Cross-Reference Graph defaultSize 480×440 → 900×640 (Session-94
///          class of bug: cramped for a graph canvas + legend); main window
///          minWidth 980 → 700 so it can tile side-by-side on 13″ displays
///   4.5 — Session 2026-07-04 (macOS UI audit gaps 5/6): "Document" and "Collection"
///          CommandMenus added, routed through focused-scene values
///          (`DocumentCommandActions`, published by MacDocumentView;
///          `CollectionManagerCommandActions`/`CollectionDetailCommandActions`,
///          published by the Collections window) so each menu is enabled exactly
///          when its window is key — reading shortcuts ⌥⌘↑/⌥⌘↓ (prev/next document),
///          ⌘⇧N (add note), ⌘⇧H (highlight selection), ⌘⇧R (research panel);
///          authoring shortcuts ⌥⌘N (new collection), ⌘⇧A (add documents — moved
///          here from the toolbar button so the equivalent has a single owner),
///          ⌥⌘P (preview), ⌘E (export)
///   4.7 — Wave R / R-6: `cloudKitDiagnostic(_:)` delegates to `CloudKitErrorInspector`, which
///          walks the underlying-error chain for the per-item dictionary instead of checking one
///          level, records whether it looked, and recovers the server's `CD_…` schema
///          identifiers. The CloudKit code table is no longer applied to non-`CKErrorDomain`
///          errors, where it named codes it had no business naming.
///   4.8 — The About window injects `appState` + `modelContainer`. It was the only one of 28 scenes
///          injecting neither, which trapped the app on **FRUS Explorer ▸ About FRUS Explorer** (and,
///          since a singleton `Window` is restorable, on the launch after quitting with it open).
///          `frus.crossReferenceGraph` and `frus.sourceExplorer` gained the container they were also
///          missing — latent, not live. `SceneEnvironmentAuditTests` now fails the suite if any scene
///          omits either, because nothing else can: the scenes are `#if os(macOS)` and both test
///          bundles are iOS.
///   4.6 — Wave R / R-9: `bootDownloadManager()` calls `UITestVolumeSeeder.seedIfRequested`
///          (DEBUG-only, inert unless `FRUS_UI_TEST_SEED_VOLUME` is set) before building the
///          `IndexingPipeline`, so a UI test can reach the compilation level — coverage the
///          R-9 defect was able to hide behind because no test could get a volume on disk
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
    /// Keeps `lastModified` current on every synced model, at save time.
    ///
    /// Four models relied on `didSet` observers for this — 73 of them — and none ever fired: the
    /// `@Model` macro rewrites stored properties into computed pairs, which cannot carry observers.
    /// `lastModified` is what CloudKit's last-writer-wins resolves on, so it was frozen at creation
    /// and a stale device won every merge. Measured in `ModelLastModifiedTests`.
    @State private var modificationStamper = ModelModificationStamper()
    #if os(iOS)
    @UIApplicationDelegateAdaptor(FRUSAppDelegate.self) private var appDelegate
    #endif
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    /// Opens the Settings scene (macOS 14+). Threaded into the Research menu so "Manage Projects…"
    /// can land on the Projects pane; the app has no prior `openSettings` call site. (#377 Phase 5)
    @Environment(\.openSettings) private var openSettings
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
    ///
    /// ## `.hourly`, not `.immediate` (#597 Phase 0)
    /// `.immediate` was set when there were three tips and two display sites, and never revisited.
    /// It is the app-wide anti-pile-on lever, and Phase 1 starts adding anchors to surfaces a new
    /// user meets in their first minutes — with `.immediate` they would collect several popovers in
    /// one sitting, which reads as an interruption rather than a hint. `.hourly` gives one per
    /// sitting; a user exploring across a week still meets all of them. `.daily` would stretch a
    /// four-tip set over four days.
    ///
    /// ## Tips are suppressed under UI test
    /// A popover intercepts `app.buttons[…].tap()`, and the symptom is "the tap did nothing" —
    /// the exact misdiagnosis `UIObstructionTests` records having cost three investigations. This
    /// is `hideAllTipsForTesting()`, never `showAllTipsForTesting()`: the latter forces display
    /// regardless of rules, which is the opposite of what a deterministic suite wants.
    private static func configureTipKit() {
        do {
            try Tips.configure([
                .displayFrequency(.hourly),
                .datastoreLocation(.applicationDefault),
            ])
            // Suppressed under UI test — EXCEPT when `FRUS_UI_TEST_SHOW_TIPS` forces them on.
            // That seam exists for MANUAL verification: a tip popover over the navigation bar is
            // the #486 shape and wants checking, but every XCUI query made while the document
            // reader is on screen times out against its WKWebView, so it cannot be automated
            // (see the withdrawn scenario 7 in `UIObstructionTests`).
            if ProcessInfo.processInfo.environment["FRUS_UI_TEST_MODE"] == "1",
               ProcessInfo.processInfo.environment["FRUS_UI_TEST_SHOW_TIPS"] != "1" {
                Tips.hideAllTipsForTesting()
            }
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
                    StandaloneDocumentWindowContent(id: id)
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
            .task { await bootSearchInfrastructureOnce() }
            // #338 aux-window origin: republish the launching window's scene so this document window's
            // rail producers (cross-ref, edge-tap, word cloud) route back to it, not `.anyWindow`.
            .auxWindowOrigin(appState)
        }
        .defaultSize(width: 820, height: 680)

        // MARK: - Source Explorer Window (iPadOS Stage Manager)
        //
        // Value-based (#317): the restorable SourceExplorerRequest fully describes the content,
        // so a backgrounded/relaunched window rebuilds correctly instead of restoring blank the
        // way the old id-based scene did (it read process-global currentSourceNote, which died
        // with the process). Mirrors the macOS "frus.sourceExplorer" Window scene, which keeps
        // the AppState fields because SwiftUI.Window is iOS-unavailable.
        WindowGroup(for: SourceExplorerRequest.self) { $request in
            Group {
                if let request {
                    // Extracted to a View so the related-documents tap can read `\.sceneID`
                    // (#752 / L-40). Inline, it was a plain closure that could not, and it
                    // addressed `.anyWindow` with no paired `openTab` — the only unpaired
                    // `openBrowseDocument` producer in the app.
                    SourceExplorerWindowContent(request: request, appState: appState)
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
            .task { await bootSearchInfrastructureOnce() }
            // #338 aux-window origin: republish the launching window's scene so nested launchers here
            // (Archival Neighbors) route documents back to it, not `.anyWindow`.
            .auxWindowOrigin(appState)
        }
        .defaultSize(width: 700, height: 560)

        // MARK: - Cross-Reference Graph Window (iPadOS Stage Manager)
        //
        // Value-based (#317): the restorable GraphWindowRequest carries the document's display
        // fields, so a restored window rebuilds the graph instead of restoring blank (the old
        // id-based scene read process-global currentGraphEntry). GraphWindowRequest identity is
        // (volumeId, documentId), preserving the former `.id(entry.id)` retarget. The store,
        // manifest, and download state stay read from AppState (live services). Mirrors the macOS
        // "frus.crossReferenceGraph" Window scene, which keeps the AppState field.
        WindowGroup(for: GraphWindowRequest.self) { $request in
            Group {
                if let request,
                   let store = appState.crossReferenceStore {
                    let downloaded: Set<String> = {
                        guard let dm = appState.downloadManager else { return [] }
                        let known = appState.manifestStore.diffResult?.known ?? []
                        return Set(known.compactMap {
                            dm.isVolumeDownloaded($0.volumeId) ? $0.volumeId : nil
                        })
                    }()
                    CrossReferenceGraphView(
                        entry: request.entry,
                        crossReferenceStore: store,
                        downloadedVolumeIds: downloaded
                    )
                    // Keyed on the store generation as well as the entry: the view captures the
                    // store instance at init, and an in-session reindex REPLACES that instance
                    // (#275 — the stale one reads empty). The generation bump tears the view down
                    // and rebuilds it against the fresh store, matching the macOS graph window.
                    .id("\(request.entry.id)-gen\(appState.readOnlyStoresGeneration)")
                } else if request != nil {
                    // #753 (audit M-22): the request restored fine — the STORE is still booting.
                    // The combined guard above collapsed those two states into one else branch, so
                    // a restored window told the user "No Document Selected" and instructed them to
                    // go open one, while holding a perfectly good request that appeared seconds
                    // later. The sibling value scenes (Archival Neighbors, Related Documents) were
                    // given this distinction for exactly this restored-window race; the graph scene
                    // was the one guarded-value scene without it.
                    BootPlaceholderView(
                        detail: String(localized: "graphWindow.preparing.detail",
                                       defaultValue: "The cross-reference graph will appear in a moment."))
                } else {
                    // Genuinely no request: an empty window, correctly stated.
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
            .task { await bootSearchInfrastructureOnce() }
            // #338 aux-window origin: republish the launching window's scene so the graph's Archival
            // Neighbors launcher routes documents back to it.
            .auxWindowOrigin(appState)
        }
        .defaultSize(width: 900, height: 640)

        // MARK: - Archival Neighbors Window (iPadOS Stage Manager, #241)
        //
        // The first macOS aux window ported to iPad (#241 Session R). Shares the exact
        // scene declaration with macOS — see `archivalNeighborsScene` for why this one
        // ports cleanly (value-based, restores by construction) while the two
        // pending-state scenes above do not.
        archivalNeighborsScene

        // MARK: - Related Documents Window (#308 Phase 2b)
        //
        // Same value-based pattern: `RelatedDocumentsRequest` fully describes the ranked
        // find-related query, so the window restores by construction.
        relatedDocumentsScene
        #endif
        #if os(macOS)
        // MARK: - Document Window (macOS native tabbing)
        //
        // Opening documents as separate windows lets macOS gather them into native
        // tabs (Window ▸ Merge All Windows / the window tab bar) and view them side
        // by side. Additive — the primary `mainWindowScene` remains the default;
        // these open only via openWindow(value: DocumentWindowID(...)) (the File
        // menu's "Open Document in New Window", C2.2). Value identity is (volumeId,
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
            .task { await bootSearchInfrastructureOnce() }
            // Same 640 pt reading-column floor as the main window (C2.3); the rail overlays below
            // the 900 pt breakpoint so the document never squeezes below ~340 pt.
            .frame(minWidth: 640, minHeight: 600)
        }

        // MARK: - Search Window
        Window("Search", id: "frus.search") {
            MacSearchWindowView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 820, height: 680)
        // #363 #5: Search's key equivalent is now ⌘S, owned by the Find command menu
        // (FindMenuContent) — ⌘F was remapped to Find in Document. Removed from the scene so
        // there is a single owner (mirrors the #2 duplicate-binding fix).

        // MARK: - Citation Lookup Window (UI audit B4)
        //
        // The other "find a document" flow. Its sibling, full-text Search, is a window —
        // Citation Lookup was a modal sheet on the same mental model (the audit's gap 7).
        // #363 #5: ⌘⇧F is now owned by the Find command menu (FindMenuContent), removed from
        // this scene for a single owner. Parsed matches stay around while the researcher reads
        // documents; result taps open the document in its own window via DocumentWindowID (#239 —
        // matching the Search window; the earlier in-window push used a constant navigationPath
        // that broke prev/next).
        Window(String(localized: "citationLookup.window.title", defaultValue: "Citation Lookup"),
               id: "frus.citationLookup") {
            CitationLookupWindowView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 620, height: 560)

        // MARK: - Corpus Browser Window
        Window("Corpus Browser", id: "frus.corpusBrowser") {
            CorpusBrowserWindowView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 520, height: 700)
        // ⌘⇧B lives on the Research-menu item, NOT here (#749 / audit L-37). A shortcut declared on
        // a Window scene runs no app code — AppState.bindTool relies on exactly that — so it cannot
        // call `bringMacWindowToFront`, leaving the only keyboard route to Browse unable to raise an
        // open-but-buried browser. It also put the shortcut on no visible menu item, so nothing
        // advertised it.

        // MARK: - People Window (UI audit B5)
        //
        // The cross-volume person index was a Corpus Browser sheet that stacked a
        // second sheet (person detail) on top of itself — the audit's sheet-on-sheet
        // smell. As a window the index is browsable alongside documents and the
        // detail presentation becomes a single window-level modal.
        // `PeopleWindowView` copies the S6 boot guard: while
        // `appState.personMentionStore` is nil (app still booting) it shows a
        // "Preparing your index…" placeholder, so a window restored at launch never
        // renders the definitive "No People Indexed" empty state as a lie.
        Window(String(localized: "people.window.title", defaultValue: "People"),
               id: "frus.people") {
            PeopleWindowView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 520, height: 640)

        // MARK: - Cross-Reference Graph Window
        Window("Cross-Reference Graph", id: "frus.crossReferenceGraph") {
            CrossReferenceGraphWindowView()
                .environment(appState)
                // Parity with every other scene. Nothing under `CrossReference/` reads `@Query` or
                // `\.modelContext` today, so this is latent rather than a live defect — but the
                // About window is what a latent one looks like after two months, so it is closed
                // here rather than left for the first `@Query` added to this subtree.
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        // Sized for a graph canvas + side legend/info panel (UI audit gap 16).
        // Same class of bug Session 94 fixed for Source Explorer: the old
        // 480×440 default forced an immediate manual resize before the volume
        // and corpus graphs were readable.
        .defaultSize(width: 900, height: 640)

        // MARK: - Source Explorer Window
        Window("Source Explorer", id: "frus.sourceExplorer") {
            SourceExplorerWindowView()
                .environment(appState)
                // Latent, same as the Cross-Reference Graph window above: no `@Query` under
                // `SourceExplorer/` today.
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 700, height: 440)

        // MARK: - Archival Neighbors Window (Source Explorer Phase 5, S6)
        //
        // Owner decision S6 (Source-Explorer-Provenance-Scope.md / UI audit B1):
        archivalNeighborsScene

        // MARK: - Related Documents Window (#308 Phase 2b)
        //
        // The find-related ranked list, value-based like Archival Neighbors above.
        relatedDocumentsScene

        // MARK: - Cross-Volume Provenance Window (UI audit B2)
        //
        // Same pattern as the S6 Archival Neighbors scene above: the Codable+Hashable
        // `CrossVolumeProvenanceRequest` fully describes the listing (collection title
        // + citing-volume ids, both captured from the bundled authority at tap time),
        // so the window renders from the value alone — no pending-state hand-off, no
        // indexingPipeline dependency, and restoration across relaunches cannot race
        // app boot (volume titles resolve against the always-available bundled
        // manifest). Row taps hand the volume to the Corpus Browser window via
        // `pendingBrowseVolume`; this window stays open. iOS keeps its `.sheet`.
        WindowGroup(for: CrossVolumeProvenanceRequest.self) { $request in
            Group {
                if let request {
                    CrossVolumeProvenanceWindowView(request: request)
                } else {
                    ContentUnavailableView(
                        String(localized: "browser.sources.crossVolume.window.empty.title",
                               defaultValue: "No Collection"),
                        systemImage: "books.vertical",
                        description: Text(
                            String(localized: "browser.sources.crossVolume.window.empty.detail",
                                   defaultValue: "Open Cross-Volume Provenance from a collection in a volume's Sources list.")
                        )
                    )
                }
            }
            .environment(appState)
            .modelContainer(modelContainer)
            .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 440, height: 520)

        // MARK: - Analytics Window
        Window("Corpus Analytics", id: "frus.analytics") {
            AnalyticsView()
                .environment(appState)
                // #258 Phase 3: AnalyticsScopeBar now hosts a @Query (custom scopes), so
                // this window needs the shared container — without it the query has no
                // store (the Phase-2 review's unreachable-pane class, container edition).
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 760, height: 560)

        // MARK: - Person Analytics Window (CA-5, CA-8)
        //
        // Trends mode: most-mentioned-people-by-era + multi-person mention-trajectory
        // comparison + two-person relationship dynamics. Network mode (CA-8): the
        // full-frame person co-mention ego graph. Over the local index; degrades to a
        // placeholder while `appState.personMentionStore` is nil (index unavailable).
        Window(String(localized: "personAnalytics.window.title", defaultValue: "Person Analytics"),
               id: "frus.personAnalytics") {
            PersonAnalyticsView()
                .environment(appState)
                // #258 Phase 3: AnalyticsScopeBar now hosts a @Query (custom scopes), so
                // this window needs the shared container — without it the query has no
                // store (the Phase-2 review's unreachable-pane class, container edition).
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 780, height: 620)

        // MARK: - Cross-Reference Analytics Window (CA-6)
        //
        // Most-referenced documents (in-degree), the citation degree distribution, a bounded
        // volume-to-volume heat matrix, and offline-PageRank landmark documents — over the
        // local index. A sibling of frus.analytics / frus.personAnalytics; degrades to a
        // placeholder while `appState.crossReferenceStore` is nil (index unavailable).
        Window(String(localized: "crossRefAnalytics.window.title", defaultValue: "Cross-Reference Analytics"),
               id: "frus.crossRefAnalytics") {
            CrossReferenceAnalyticsView()
                .environment(appState)
                // #258 Phase 3: AnalyticsScopeBar now hosts a @Query (custom scopes), so
                // this window needs the shared container — without it the query has no
                // store (the Phase-2 review's unreachable-pane class, container edition).
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 820, height: 660)

        // MARK: - Archival Analytics Window (#765)
        //
        // Where the editors found what they published: era × collection rankings and collection
        // rankings from the bundled authority + usage index (corpus-wide, needs no downloads),
        // and the archival profile of the user's own indexed volumes from `document_sources`.
        Window(String(localized: "archival.window.title", defaultValue: "Archival Analytics"),
               id: "frus.archivalAnalytics") {
            ArchivalAnalyticsView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 820, height: 680)

        // MARK: - Word Cloud Window
        Window(String(localized: "wordcloud.window.title", defaultValue: "Word Cloud"),
               id: "frus.wordcloud") {
            WordCloudWindowContent()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 760, height: 620)

        // MARK: - Chronology Window
        Window(String(localized: "chronology.window.title", defaultValue: "Chronology"),
               id: "frus.chronology") {
            ChronologyView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 720, height: 600)

        // MARK: - Research Window
        Window(String(localized: "research.window.title", defaultValue: "Research"),
               id: "frus.research") {
            ResearchView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 760, height: 600)
        // #363 #2: ⌘⌥R now lives solely on the Research command menu (ResearchMenuContent) —
        // it was previously declared here AND on the toolbar button, a duplicate key equivalent.

        // MARK: - Project Home Window (#377 Phase 1)
        //
        // The per-project research workspace. Value-based on `ProjectHomeRequest` (the project id)
        // so it stays off the Window menu and a multi-project researcher can keep several open;
        // opened from Research ▸ Project Home (⌘P). A request-less restored window shows a picker hint.
        WindowGroup(String(localized: "project.home.window.title", defaultValue: "Project Home"),
                    for: ProjectHomeRequest.self) { $request in
            NavigationStack {
                if let request {
                    ProjectHomeView(projectId: request.projectId)
                } else {
                    ContentUnavailableView(
                        String(localized: "project.home.missing.title", defaultValue: "No Project Selected"),
                        systemImage: "folder",
                        description: Text(String(localized: "project.home.missing.detail",
                                                 defaultValue: "Choose a project from the project picker to see its workspace."))
                    )
                }
            }
            .environment(appState)
            .modelContainer(modelContainer)
            .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 720, height: 720)

        // MARK: - New Project Window (#377 Phase 5)
        // Hosts the create editor for the Research ▸ New Project… command — a menu command can't
        // present a sheet, so it opens this small singleton window. `showsInlineHeader: false` drops
        // the editor's internal title (the window titlebar already reads "New Project"). Injects
        // AppState (the second-project nudge signal) + the container (the editor's modelContext).
        // NOTE: the once-ever second-project nudge does NOT fire from here — this transient window
        // dismisses on Save before it could present, and it isn't a `.secondProjectNudge()` host (the
        // hosts are the iOS tab shell and the macOS Settings pane). This matches the Project Home
        // create path; the nudge stays best-effort/host-dependent by design rather than adding a
        // multi-instance main-window host, which would reintroduce the multi-fire the #456 review guarded.
        Window(String(localized: "project.new.window.title", defaultValue: "New Project"),
               id: "frus.newProject") {
            ProjectEditorView(showsInlineHeader: false)
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .windowResizability(.contentSize)

        // MARK: - Collections Window
        Window("Collections", id: "frus.collections") {
            MacCollectionManagerView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        // Composer v2 (§B): wide enough for Contents (372) + live preview + the optional Document
        // inspector (320) on a 13-inch screen.
        .defaultSize(width: 1180, height: 760)
        // #363 #2: ⌘⇧K now lives solely on the Research command menu (ResearchMenuContent) —
        // it was previously declared here AND on the toolbar button, a duplicate key equivalent.

        // MARK: - Research Note Composer Window (UI audit C1)
        //
        // Utility window for composing/editing a research note while the document
        // being annotated stays readable — the modal sheets this replaces covered
        // the passage the user was writing about. Value-based (#363): the restorable
        // `NoteComposerRequest` fully describes the composer, so it no longer clutters the Window menu
        // (a value-based `WindowGroup` isn't auto-listed the way a singleton `Window(id:)` is) and a
        // relaunch-restored window rebuilds its editor instead of returning on a dead placeholder.
        // Mirrors the Archival-Neighbors / Related-Documents value-based scenes.
        WindowGroup(String(localized: "note.composer.window.title", defaultValue: "Research Note"),
                    for: NoteComposerRequest.self) { $request in
            Group {
                if let request {
                    NoteComposerWindowView(request: request)
                } else {
                    ContentUnavailableView(
                        String(localized: "note.composer.empty.title",
                               defaultValue: "No Note Being Composed"),
                        systemImage: "note.text",
                        description: Text(
                            String(localized: "note.composer.empty.detail",
                                   defaultValue: "Use “Add note” in a document's Research strip, or open a note from its Research panel.")
                        )
                    )
                }
            }
            .environment(appState)
            .modelContainer(modelContainer)
            .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 560, height: 620)

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
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 640, height: 600)

        // MARK: - Settings
        Settings {
            FRUSSettingsView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }

        // MARK: - About Window
        //
        // The injections below are what keep this window from trapping on open. `AboutView`
        // declares `@Environment(AppState.self)` (AboutView.swift:73) — non-optional, so SwiftUI
        // resolves it EAGERLY in `EnvironmentBox.update` during the dynamic-property update phase,
        // before `body` is ever evaluated. The macOS body does not read `appState` at all (the one
        // read is in the iOS arm), and it trapped anyway. So the rule this scene broke is
        // "declared without injection", not "read without injection" — grepping for reads would
        // clear this window wrongly.
        //
        // It was the only one of 28 scenes injecting nothing, bare since 2026-05-17. Harmless until
        // S-5a moved the Research Guide row in on 2026-07-25 and added that declaration, which
        // turned a dormant omission into a hard trap: `openWindow(id: "about")` builds the window
        // synchronously inside the menu action, so the trap fires on the click. Worse, a singleton
        // `Window` scene is restorable — left open at quit, it trapped during the next LAUNCH.
        // `SceneEnvironmentAuditTests` now fails the suite if any scene omits either injection.
        Window(String(localized: "about.title", defaultValue: "About FRUS Explorer"),
               id: "about") {
            AboutView()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
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
        //
        // #363 #7: value-based (`WindowGroup(for: ResearchGuideWindowID.self)`) rather than a
        // singleton `Window(id:)`, so the guide no longer clutters the macOS Window menu.
        // `ResearchGuideWindowID` is an always-equal marker → one reused window; the requested
        // topic still flows through `appState.researchGuideInitialPageId` (read by the view), not
        // the window value, so a restored value-less window simply opens on the first page.
        WindowGroup(String(localized: "researchGuide.window.title", defaultValue: "FRUS Research Guide"),
                    for: ResearchGuideWindowID.self) { _ in
            ResearchGuideView()
                .environment(appState)
                // #258 Phase 4: the Series dashboards' scope bar hosts a @Query (custom
                // scopes) and this window reaches them via IndexingEducationView — without
                // the container the query has no store (the Phase-3 container class).
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 880, height: 620)
        #endif
    }

    /// The **Archival Neighbors** scene — macOS since Source Explorer Phase 5 (S6), iPad
    /// with Stage Manager since #241.
    ///
    /// Archival Neighbors is a WINDOW, not a sheet: the result is a work list the
    /// researcher steps through, and a sheet dies on the first navigation. Row taps route
    /// the document to the window's provenance host (`AppState.openDocument`) and this
    /// window stays open beside it.
    ///
    /// Value-based `WindowGroup(for:)`: the `Codable + Hashable` `ArchivalNeighborsRequest`
    /// fully describes the query (all four shapes resolve through
    /// `appState.indexingPipeline`), so the fetch is reconstructed from the value inside
    /// the window — no pending-state hand-off — and SwiftUI restores the window across
    /// relaunches by re-running the cheap local query. That self-sufficiency is exactly
    /// why #241 ported this scene to iPad first — and why #317 then applied the same
    /// value-based pattern to the Source Explorer (`SourceExplorerRequest`) and cross-reference
    /// graph (`GraphWindowRequest`) scenes, which formerly read process-global pending state and
    /// restored empty. All three iPad aux windows now restore correctly by construction.
    ///
    /// Reuse semantics: `openWindow(value:)` focuses the existing window for an equal
    /// request and opens a new one otherwise — one window per distinct archival source,
    /// browsable side by side.
    ///
    /// Declared once and referenced from **both** platform regions of `body` (rather than
    /// hoisted above them) so the macOS Window-menu ordering is unchanged. Callers gate on
    /// `supportsMultipleWindows` and fall back to the sheet where windows are unavailable
    /// (iPhone, iPads without Stage Manager).
    private var archivalNeighborsScene: some Scene {
        WindowGroup(for: ArchivalNeighborsRequest.self) { $request in
            Group {
                if let request {
                    ArchivalNeighborsWindowView(request: request)
                } else {
                    ContentUnavailableView(
                        String(localized: "archivalNeighbors.window.empty.title",
                               defaultValue: "No Archival Source"),
                        systemImage: "archivebox",
                        description: Text(
                            String(localized: "archivalNeighbors.window.empty.detail",
                                   defaultValue: "Open Archival Neighbors from a document, search result, or a volume's Sources list.")
                        )
                    )
                }
            }
            .environment(appState)
            .modelContainer(modelContainer)
            .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 520, height: 560)
    }

    /// Value-based `WindowGroup(for:)` for the #308 find-related list: the `Codable + Hashable`
    /// `RelatedDocumentsRequest` fully describes the ranked query (anchor + weights + scope + limit),
    /// so the window reconstructs the fetch from the value alone and SwiftUI restores it — with its
    /// exact tuning — across relaunches. Declared once and referenced from both platform regions of
    /// `body` (like `archivalNeighborsScene`) so the macOS Window-menu ordering is unchanged. Callers
    /// gate on `supportsMultipleWindows` and fall back to `RelatedDocumentsSheet` where windows are
    /// unavailable (iPhone, iPads without Stage Manager).
    private var relatedDocumentsScene: some Scene {
        WindowGroup(for: RelatedDocumentsRequest.self) { $request in
            Group {
                if let request {
                    RelatedDocumentsWindowView(request: request)
                } else {
                    ContentUnavailableView(
                        String(localized: "related.window.empty.title",
                               defaultValue: "No Document Selected"),
                        systemImage: "doc.on.doc",
                        description: Text(
                            String(localized: "related.window.empty.detail",
                                   defaultValue: "Open Related Documents from a document you're reading.")))
                }
            }
            .environment(appState)
            .modelContainer(modelContainer)
            .task { await bootSearchInfrastructureOnce() }
        }
        .defaultSize(width: 520, height: 600)
    }

    /// The primary `WindowGroup` scene, with macOS-specific modifiers applied conditionally.
    private var mainWindowScene: some Scene {
        WindowGroup {
            ContentViewWithSplash()
                .environment(appState)
                .modelContainer(modelContainer)
                .task { await bootSearchInfrastructureOnce() }
                #if os(macOS)
                // 640 pt = the reading-column floor (340 pt) + the 300 pt Research rail. At the
                // C2.3 900 pt breakpoint the rail is side-by-side; below it the rail OVERLAYS and the
                // document keeps full width, so 640 never squeezes the reading column below 340 pt.
                // The C2 titlebar is a fixed 5-tool set (identity pill yields first), so there's no
                // strip/label-truncation concern any more; 640 lets the window tile comfortably as a
                // split-screen half of a 13″ MacBook Air (≈722 pt).
                .frame(minWidth: 640, minHeight: 600)
                #endif
                .task {
                    await bootSearchInfrastructureOnce()
                    // O-2: decode the core cloud vectors AFTER the first frame and off the
                    // main actor. Deliberately last in this task and never in a view body:
                    // O-0's trace put `FRUSExplorerApp.init()` at 119–158 ms, most of it a
                    // synchronous store open, and adding a decode to that window would make
                    // the launch this backdrop exists to decorate measurably worse. Until
                    // it resolves, `WordCloudBackdropView` renders nothing.
                    await BundledCloudVectors.prepareCore()
                    // Same schedule, same reason: the keyness reference is ~1.2 MB and nothing on
                    // the launch path needs it. Without this call every keyness read returns
                    // `.unavailable(.noArtifact)` — a failure indistinguishable from a missing
                    // bundle resource, so the feature would look wired and be permanently dark.
                    await BundledKeynessBaseline.prepare()
                    // Before anything can edit a synced model. Cheap: one notification observer.
                    modificationStamper.start(observing: modelContainer.mainContext)
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
                // Handoff / Spotlight / open-with. On iOS these live inside `ContinuationHost`, a
                // per-window modifier that mints this window's scene identity above the tab view so
                // each handler can address the window it fired in (#752 / M-25). Before, the
                // identity was minted two levels below them and they addressed `.anyWindow`, so on
                // an iPad the OS fronted one window and the navigation could land in another — or
                // split, the tab switch going to one and the document to a second.
                //
                // macOS keeps the plain modifiers: there is one scene identity concept there
                // (`.global` + `fallbackHost()`'s most-recently-key stamp), the import fronts its
                // own window, and neither needs a scene token.
                #if os(iOS)
                .modifier(ContinuationHost(
                    onDocumentActivity: { activity, sceneID in
                        continueDocumentActivity(activity, from: sceneID)
                    },
                    onSpotlight: { activity, sceneID in
                        continueSpotlightActivity(activity, from: sceneID)
                    },
                    onOpenURL: { url, sceneID in
                        importOpenedCollection(url, from: sceneID)
                    }))
                #else
                // Handoff: a FRUS document viewed on another device
                .onContinueUserActivity(AppActivityTypes.document) { activity in
                    continueDocumentActivity(activity, from: nil)
                }
                // Spotlight: user tapped a search result for a FRUS document
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    continueSpotlightActivity(activity, from: nil)
                }
                // A shared native collection opened from Files / Finder / AirDrop (Phase 4 / D9).
                .onOpenURL { url in
                    importOpenedCollection(url, from: nil)
                }
                #endif
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
                // Debug-only: the store on disk and this build declare different record types, so
                // the app is running local-only on a different store than the one holding the
                // data. A pass-through on release builds. See `storeSchemaMismatchAlert(_:)`.
                .storeSchemaMismatchAlert(appState)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Replace the default "About AppName" item with one that opens the
            // dedicated About Window scene.
            CommandGroup(replacing: .appInfo) {
                Button(String(localized: "menu.about",
                              defaultValue: "About FRUS Explorer")) {
                    openWindow.fronting(id: "about")
                }
            }

            // File ▸ (after "New Window") "Open Document in New Window" (Research-rail C2.2) —
            // opens the key document surface's current document in its own window via
            // \.documentCommands, replacing the retired research strip's New Window verb.
            CommandGroup(after: .newItem) {
                OpenDocumentInNewWindowMenuItem()
            }

            // #377 Phase 1: the app implements no document printing, and ⌘P is used for
            // Research ▸ Project Home. Remove the system Print menu items so nothing else
            // claims ⌘P (an empty replacement drops the group).
            CommandGroup(replacing: .printItem) { }

            // Append a "FRUS Research Guide" item to the Help menu (after the
            // system search field) so the standalone primer is reachable
            // independently of the first-run indexing flow — mirroring the
            // dedicated About Window pattern above, but surfaced from Help
            // rather than the app menu since it's reference content, not
            // settings or app metadata.
            CommandGroup(after: .help) {
                Button(String(localized: "menu.researchGuide",
                              defaultValue: "FRUS Research Guide")) {
                    openWindow(value: ResearchGuideWindowID())   // #363 #7: value-based guide window
                }
            }

            // Format menu with the system text-formatting items (Bold/Italic/Underline,
            // fonts, alignment). The collection rich-text prose editors are NSTextView-
            // backed, and AppKit routes their ⌘B/⌘I/⌘U key equivalents through these menu
            // items — without the menu the shortcuts are dead and formatting is reachable
            // only via the right-click Font submenu (ui-audit #2).
            TextFormattingCommands()

            // Search (⌘S), Citation Lookup (⌘⇧F), and Find in Document (⌘F) are all owned by the
            // "Find" command menu below (#363 #5). The scene-level shortcuts on frus.search /
            // frus.citationLookup were removed so the Find menu is the single owner (do NOT re-add
            // a scene `.keyboardShortcut` — ⌘F now belongs to Find in Document, not Search).

            // "Document" menu (UI audit gap 6) — reading shortcuts for whichever
            // document surface is frontmost (the main window's pushed document or a
            // standalone document window). Routed through the focused-scene value
            // `\.documentCommands` that MacDocumentView publishes, so every item is
            // enabled exactly when a document window is key and a document is loaded,
            // and each acts on THAT window's navigation/highlight/panel state. The
            // items mirror existing buttons only (Prev/Next volume navigation, the
            // research strip's Highlight color picker and Add note, the Read/Research
            // panel toggle) — no new behaviors.
            CommandMenu(String(localized: "menu.document", defaultValue: "Document")) {
                DocumentMenuContent()
            }

            // "Find" menu (#363 #5) — the three finding flows: Find in Document (⌘F, in-page find
            // on the key document's web view), Search (⌘S, full-text corpus), Citation Lookup (⌘⇧F).
            // ⌘F was remapped off Search (which moves to ⌘S) so the document's own find bar owns it.
            CommandMenu(String(localized: "menu.find", defaultValue: "Find")) {
                FindMenuContent(openWindow: openWindow, appState: appState)
            }

            // "Collection" menu (UI audit gap 5) — collection-authoring commands,
            // enabled only while the Collections window (frus.collections) is key:
            // `\.collectionManagerCommands` is published by the window's root view
            // (New Collection works with nothing selected) and
            // `\.collectionDetailCommands` by its detail pane (everything else needs
            // a selected collection). ⌘⇧A moved here from the detail pane's toolbar
            // button so the key equivalent has a single owner in the menu bar.
            CommandMenu(String(localized: "menu.collection", defaultValue: "Collection")) {
                CollectionMenuContent()
            }

            // "Analytics" menu (#363 #4) — the five analytics windows in the menu bar,
            // no longer only reachable via the toolbar dropdown + the auto Window menu.
            CommandMenu(String(localized: "menu.analytics", defaultValue: "Analytics")) {
                AnalyticsMenuContent(appState: appState, openWindow: openWindow)
            }

            // "Research" menu (#363 #4) — the researcher's own-work windows (Research ⌘⌥R,
            // Collections ⌘⇧K) with the former standalone History menu folded in as a
            // submenu. This menu is the single owner of ⌘⌥R / ⌘⇧K (#363 #2 — the duplicate
            // declarations on the window scenes and toolbar buttons were removed).
            // `.modelContainer` feeds the embedded History submenu's @Query; appState/
            // openWindow are explicit init params (mirroring the surrounding CommandGroup
            // blocks) rather than relying on @Environment propagation into .commands.
            // Corpus Browser lives in the WINDOW menu, not Research. It opens a window and does
            // nothing else — the Research menu's other items each act on research state (bind a
            // project, open a collection), and grouping "show me this window" with them made the
            // menu a list of two unlike things.
            //
            // ⌘⇧B stays on this Button rather than moving back to the `Window` scene: a
            // scene-level shortcut runs no app code, so it cannot front a buried browser, and it
            // appears on no menu at all (#749 / audit L-37). That is the defect this item exists
            // to have fixed, and it is independent of which menu the item sits in.
            CommandMenu(String(localized: "menu.research", defaultValue: "Research")) {
                ResearchMenuContent(appState: appState, openWindow: openWindow, openSettings: openSettings)
                    .modelContainer(modelContainer)
                    .task { await bootSearchInfrastructureOnce() }
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
    private func importOpenedCollection(_ url: URL, from sceneID: SceneID?) {
        guard url.pathExtension.lowercased() == NativeCollectionSerializer.fileExtension else { return }
        // #752 / M-25. The content-hash guard below already stops a second *import*, but not a
        // second surfacing, and with the surfacing now addressed to a scene two windows acting on
        // one open-with would each surface it in themselves.
        guard appState.claimContinuation("openURL|\(url.absoluteString)") else { return }
        let context = modelContainer.mainContext
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)

            let digest = Data(SHA256.hash(data: data))
            if let existingId = openedCollectionImports[digest],
               collectionExists(existingId, in: context) {
                surfaceOpenedCollection(existingId, from: sceneID)
                return
            }

            let file = try NativeCollectionSerializer.decode(data)
            let imported = NativeCollectionSerializer.apply(file, into: context)
            if let pid = appState.activeProjectId { imported.projectIds = [pid] }
            try context.save()
            openedCollectionImports[digest] = imported.id
            surfaceOpenedCollection(imported.id, from: sceneID)
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
    private func surfaceOpenedCollection(_ id: UUID, from sceneID: SceneID?) {
        #if os(iOS)
        // #755 (audit M-24): set the hand-off on iOS too. `CollectionListView` has had the consumer
        // since #369 BUG-12 — `.task` + `.onChange` draining the selection to push the imported
        // collection's editor — but the ONLY writer in the codebase was the macOS branch below, so
        // the iOS half could never fire. The collection imported fine and then the user had to go
        // find it by name, while macOS opened straight onto it.
        //
        // Set BEFORE the tab switch, for the same reason macOS sets it before `openWindow`: a
        // freshly created consumer's `.task` must see it.
        //
        // #752 / M-25: both halves are addressed to the window the open-with was delivered to, and
        // through a scene-targeted slot of their own. The untargeted `pendingCollectionSelection`
        // is drained by every open window's `CollectionListView`, so the imported collection could
        // surface in a different window from the one that switched to Collections.
        appState.pendingCollectionSelectionScene = Handoff(target: sceneID ?? .anyWindow, payload: id)
        appState.openTab(.collections, from: sceneID)
        #else
        appState.pendingCollectionSelection = id
        openWindow.fronting(id: "frus.collections")
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
    /// Boots the search infrastructure exactly once, from whichever scene appears first.
    ///
    /// ## The defect this closes
    /// `bootDownloadManager()` builds the FTS5 store, the indexing pipeline and
    /// `appState.searchService`, and it was awaited from ONE place: a `.task` on the primary
    /// `WindowGroup`. Every standalone macOS window — Search, Corpus Browser, People, the
    /// analytics windows — boots nothing. So an app that came up showing only the Search window
    /// (a restored session, or ⌘S before the main window) had `searchService == nil` for the
    /// whole session: every query returned zero, Facets stayed disabled, and the Advanced
    /// popover rendered an empty box. Silently — search reported "No Results" over an index
    /// holding 316,839 documents.
    ///
    /// ## Why a stored `Task` rather than the callee's own guard
    /// `bootDownloadManager` guards on `appState.downloadManager == nil`, which is idempotent for
    /// *sequential* calls but not concurrent ones: it awaits several times between that check and
    /// the assignment, so two scenes appearing together could both pass the guard and build two
    /// pipelines over one database. Holding the `Task` makes the second caller await the first's
    /// work instead of repeating it. The check-and-store below is synchronous on the main actor,
    /// so it cannot interleave.
    private func bootSearchInfrastructureOnce() async {
        if let running = appState.searchInfrastructureBoot {
            await running.value
            return
        }
        let task = Task { @MainActor in await bootDownloadManager() }
        appState.searchInfrastructureBoot = task
        await task.value
    }

    private func bootDownloadManager() async {
        guard appState.downloadManager == nil else { return }

        let volumesDir = Self.makeVolumesDirectory()
        // DEBUG-only, and inert unless a UI test names a volume in FRUS_UI_TEST_SEED_VOLUME.
        // Placed before the pipeline is built so the fixture is on disk for the first read.
        #if DEBUG
        UITestVolumeSeeder.seedIfRequested(in: volumesDir)
        #endif
        let dbURL = Self.makeDatabaseURL()
        appState.indexDirectory = dbURL.deletingLastPathComponent()
        // Retained so any in-session index rebuild can reopen the read-only stores against them (#275).
        appState.databaseURL = dbURL
        appState.volumesDirectory = volumesDir

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
        // The store-vs-build record-type comparison, when the container fell back. Published
        // before the error message below, which appends its summary.
        appState.storeSchemaMismatch = _containerSetup.storeDiagnostic
        if !_containerSetup.cloudKitEnabled {
            if let storeDiagnostic = _containerSetup.storeDiagnostic, storeDiagnostic.isMismatch {
                // A second log entry rather than folding these names into the CloudKit entry's
                // `schemaIdentifiers`: that field holds CloudKit's `CD_`-prefixed mirrored
                // identifiers, and these are local Core Data entity names. The distinct phase keeps
                // the two readable apart in an exported log, where the whole value is being able
                // to tell which layer disagreed.
                let names = storeDiagnostic.missingFromStore + storeDiagnostic.absentFromModel
                Task {
                    await SyncDiagnosticsLog.shared.record(
                        phase: "storeSchema", startDate: nil, endDate: Date.now, succeeded: false,
                        schemaIdentifiers: names)
                }
            }
            if let initError = _containerSetup.initError {
                let diag = Self.cloudKitDiagnostic(initError)
                // Append the store comparison to the message the status bar and Settings already
                // show. A tester's screenshot of "Local Only" then carries the diagnosis instead
                // of only the CloudKit error code, which on this failure named nothing useful
                // (`SwiftDataError.internalError`).
                if let storeDiagnostic = _containerSetup.storeDiagnostic {
                    appState.cloudKitInitError = "\(diag.message)\n\n\(storeDiagnostic.summary)"
                } else {
                    appState.cloudKitInitError = diag.message
                }
                Task {
                    await SyncDiagnosticsLog.shared.record(
                        phase: "init", startDate: nil, endDate: Date.now, succeeded: false,
                        errorDomain: diag.domain, errorCode: diag.code, errorCodeName: diag.codeName,
                        partialItemCount: diag.partialCount, subErrorHistogram: diag.histogram,
                        hadPartialDictionary: diag.inspection.hadPartialDictionary,
                        partialDictionaryDepth: diag.inspection.partialDictionaryDepth,
                        schemaIdentifiers: diag.inspection.schemaIdentifiers.isEmpty
                            ? nil : diag.inspection.schemaIdentifiers,
                        retryAfterSeconds: diag.inspection.retryAfterSeconds,
                        chainTruncated: diag.inspection.chainTruncated)
                }
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
               stateTracker: stateTracker
           ) {
            appState.indexingPipeline = pipeline
            appState.connectIndexingProgress(pipeline: pipeline)
            // Collapse any CloudKit-sync duplicate tags / projects / collections
            // (SwiftData + CloudKit can't enforce unique `id`s) so they stop
            // appearing twice in lists.
            DuplicateRecordCleanup.run(context: modelContainer.mainContext)
            // #406: reconstruct orphaned tag associations. On a local-only store there is no
            // CloudKit import to wait for and the local store is authoritative, so run it now.
            // When CloudKit IS enabled we DEFER this to the sync-event observer below, which runs
            // it only after imports settle — never against a mid-import partial store, where a
            // not-yet-arrived tag would look like an orphan and be reconstructed (and pushed to
            // CloudKit) as a duplicate of a live record.
            if !appState.cloudKitSyncEnabled {
                OrphanedTagRepair.run(context: modelContainer.mainContext)
            }
            // Wave R-2a: retire the legacy session tables into the typed trail. Unconditional,
            // unlike the repair above. The CloudKit-settled observer below runs it too — that is
            // the *preferred* moment, because a second device that has already migrated will
            // usually have delivered its rows by then — but it cannot be the only moment: a device
            // signed out of iCloud, or one whose first import fails, never gets that event, and
            // since this release nothing reads `SessionEvent` any more, so its recorded searches
            // and exports would be invisible for as long as that lasted. The pass is
            // self-limiting — one array-literal check plus one `fetchCount` once the legacy tables
            // are empty — so calling it here as well costs nothing, and it is idempotent by
            // construction (migrated rows take the source event's id).
            ResearchTrailMigration.run(context: modelContainer.mainContext)
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
            // The user's person-cluster corrections (Phase 3) are snapshotted AT CALL TIME
            // inside each Task, not once at boot: the migration paths below run after
            // multi-minute awaits, during which the user can merge/undo in the People
            // browser (Session 4). A boot-time snapshot would rebuild the rollup WITHOUT
            // those fresh corrections and stamp their stale fingerprint — visibly un-doing
            // the user's change until the next launch. (These Tasks inherit the MainActor,
            // so the SwiftData snapshot reads are plain calls.)
            if dateReindexNeeded {
                Task {
                    #if DEBUG
                    print("[FRUSExplorer] Background re-index triggered (dateReindex=true, ftsRebuild=\(ftsRebuildNeeded)).")
                    #endif
                    try? await pipeline.indexAllVolumes()
                    await pipeline.markDateReindexComplete()
                    if ftsRebuildNeeded { await pipeline.markFTSRebuildReindexComplete() }
                    // Rebuild the materialised person rollup after the persons table changes.
                    let overrides = PersonClusterOverrideStore.snapshot(context: modelContainer.mainContext)
                    if (try? await pipeline.consolidatePersonRollupIfNeeded(overrides: overrides)) == true {
                        // A launch-time rebuild renumbers every rollup id, and the People browser
                        // and analytics can already be on screen by the time it finishes (#747).
                        PersonRollupRefresh.published(appState: appState)
                    }
                    try? await pipeline.applyBrokenRefsIndexIfNeeded()
                    // Reopen the read-only stores now that the rebuild + WAL checkpoints have
                    // settled — the boot-time connections opened before this Task can be left
                    // stale, blanking cross-reference / person analytics until relaunch (#275).
                    appState.refreshReadOnlyStores()
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
                    let overrides = PersonClusterOverrideStore.snapshot(context: modelContainer.mainContext)
                    if (try? await pipeline.consolidatePersonRollupIfNeeded(overrides: overrides)) == true {
                        // A launch-time rebuild renumbers every rollup id, and the People browser
                        // and analytics can already be on screen by the time it finishes (#747).
                        PersonRollupRefresh.published(appState: appState)
                    }
                    try? await pipeline.applyBrokenRefsIndexIfNeeded()
                    // See the date-reindex branch: reopen the read-only stores post-rebuild (#275).
                    appState.refreshReadOnlyStores()
                    #if DEBUG
                    print("[FRUSExplorer] FTS rebuild from document_cache complete.")
                    #endif
                }
            } else {
                // Normal launch: rebuild the person rollup if its version was bumped or the
                // member set has drifted (volumes added/removed). Cheap no-op when up to date.
                Task {
                    let overrides = PersonClusterOverrideStore.snapshot(context: modelContainer.mainContext)
                    if (try? await pipeline.consolidatePersonRollupIfNeeded(overrides: overrides)) == true {
                        // A launch-time rebuild renumbers every rollup id, and the People browser
                        // and analytics can already be on screen by the time it finishes (#747).
                        PersonRollupRefresh.published(appState: appState)
                    }
                    // Backfill cross_references.is_broken for already-indexed volumes (#240B).
                    // Gated + idempotent; a no-op once the current index has been applied.
                    try? await pipeline.applyBrokenRefsIndexIfNeeded()
                    // Both steps above can mutate the persons rollup / is_broken column even on an
                    // otherwise-normal launch, so reopen the read-only stores here too (#275). When
                    // they were no-ops this is a cheap reconnect with no dashboard open to reload.
                    appState.refreshReadOnlyStores()
                }
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
                        _ = appState.indexedVolumeIds.remove(volumeId)
                        #if os(iOS)
                        // Both inputs to the Browse-tab badge just changed: the volume left
                        // the indexed set AND left the disk.
                        appState.refreshUnindexedVolumeCount()
                        #endif
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
                await dm.enqueueDownload(entry)
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
            ) { [appState, modelContainer] notification in
                // Extract only Sendable values on the calling thread before the
                // @MainActor hop, avoiding Sendable warnings on NSPersistentCloudKitContainer.Event.
                guard let event = notification.userInfo?[eventUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { return }
                // Decompose the (non-Sendable) Event into allow-listed value locals BEFORE the
                // actor/MainActor hop — the Event itself must not cross the boundary (#188-C.1).
                let hasEnded  = event.endDate != nil
                let succeeded = event.succeeded
                let startDate = event.startDate
                let endDate   = event.endDate ?? Date.now
                let phase: String
                switch event.type {
                case .setup:  phase = "setup"
                case .import: phase = "import"
                case .export: phase = "export"
                @unknown default: phase = "unknown"
                }
                // Build a redacted diagnostic from the error. For CKError.partialFailure the
                // per-item sub-errors are the real diagnosis, aggregated by code (never by id).
                let diag = (event.error as? NSError).map { Self.cloudKitDiagnostic($0) }

                Task { @MainActor in
                    if !hasEnded {
                        appState.cloudKitSyncState = .syncing
                    } else if succeeded {
                        appState.cloudKitSyncState = .succeeded(endDate)
                        // A completed import may have brought down updated settings; pull them
                        // into UserDefaults if this device syncs settings — **debounced**
                        // (#665).
                        //
                        // This ran on every successful event. `syncNowIfEnabled()` is
                        // `pull()` → a `FetchDescriptor<SyncedPreferences>` fetch, possible
                        // duplicate deletes plus a `context.save()`, then
                        // `applyModelToDefaults()` writing UserDefaults — which fans out to
                        // every `@AppStorage`-bound view in the app. A large import emits many
                        // success events, so that whole chain ran repeatedly on the main actor
                        // while the user was reading.
                        //
                        // Same debounce, same reason, as its two neighbours below: what the
                        // user's settings should be is a property of the *settled* store, and
                        // reading it from a partial one mid-import is both wasted work and a
                        // chance to apply a value that a later batch supersedes.
                        appState.settingsPullDebounce?.cancel()
                        appState.settingsPullDebounce = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            guard !Task.isCancelled else { return }
                            appState.settingsSync?.syncNowIfEnabled()
                        }
                        // #406: after a successful IMPORT, reconstruct any orphaned tag
                        // associations — but debounced, so the repair runs once a few seconds
                        // after imports go quiet (a settled store), never against the partial
                        // store mid-sync where a not-yet-arrived tag would look like an orphan.
                        // We dedupe FIRST: if an earlier debounce minted a placeholder and the
                        // real tag has since arrived in a later import, `DuplicateRecordCleanup`
                        // collapses that same-id pair now (keeping the real record) instead of
                        // leaving a visible duplicate until the next cold boot; the repair then
                        // fills only the ids that are still genuinely orphaned.
                        if phase == "import" {
                            appState.orphanedTagRepairDebounce?.cancel()
                            appState.orphanedTagRepairDebounce = Task { @MainActor in
                                try? await Task.sleep(for: .seconds(8))
                                guard !Task.isCancelled else { return }
                                DuplicateRecordCleanup.run(context: modelContainer.mainContext)
                                OrphanedTagRepair.run(context: modelContainer.mainContext)
                                // #561: standard prompts are seeded per device with fresh ids and
                                // collapsed by NAME, and that collapse runs inside boot — before
                                // this import existed. A second device therefore shows 16 prompts
                                // for the rest of the session, collapsing only at the next cold
                                // launch. Same debounce, same reason as its two neighbours: a
                                // settled store, not a partial one mid-sync.
                                SummarizationPromptSeeder.collapseDuplicates(
                                    context: modelContainer.mainContext)
                                // Wave R-2a: same debounce, same reason. Running the trail
                                // migration only after imports go quiet means a second device
                                // that has already migrated will usually have delivered its rows
                                // by now, and this device recognises them by id and skips —
                                // which is what keeps the two from both writing the same row.
                                ResearchTrailMigration.run(context: modelContainer.mainContext)
                            }
                        }
                    } else {
                        let msg = diag?.message ?? String(localized: "cloudkit.error.unknown",
                                                          defaultValue: "Unknown sync error")
                        appState.cloudKitSyncState = .failed(msg)
                    }
                    // #377 Phase 5: once the first IMPORT ends (success or failure), the local Project
                    // store reflects whatever CloudKit brought, so the Switch Project menu can reveal
                    // its list instead of the "Syncing…" placeholder. Gated to `import` so an earlier
                    // `setup`/`export` completion doesn't reveal a still-empty list mid-import.
                    if hasEnded && phase == "import" {
                        appState.hasInitialProjectSyncSettled = true
                    }
                }

                // Record a redacted telemetry row for every *ended* event (success or failure),
                // so a tester can confirm sync now works — or export the exact failure (#188-C.1).
                if hasEnded {
                    Task {
                        await SyncDiagnosticsLog.shared.record(
                            phase: phase,
                            startDate: startDate,
                            endDate: endDate,
                            succeeded: succeeded,
                            errorDomain: diag?.domain,
                            errorCode: diag?.code,
                            errorCodeName: diag?.codeName,
                            partialItemCount: diag?.partialCount,
                            subErrorHistogram: diag?.histogram,
                            // Wave R-6. Recorded for every ended event that carried an error, so
                            // "the app looked and there was no per-item detail" is a fact in the
                            // row rather than an absence the reader has to guess at.
                            hadPartialDictionary: diag?.inspection.hadPartialDictionary,
                            partialDictionaryDepth: diag?.inspection.partialDictionaryDepth,
                            schemaIdentifiers: (diag?.inspection.schemaIdentifiers).flatMap {
                                $0.isEmpty ? nil : $0
                            },
                            retryAfterSeconds: diag?.inspection.retryAfterSeconds,
                            chainTruncated: diag?.inspection.chainTruncated
                        )
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
                // Keyed on the QUEUE. `currentIndexingProgress` is nil in the gap
                // between two volumes, and backgrounding the app in that gap left a
                // 26-volume queue with no BGProcessingTask submitted — the rest of the
                // download simply did not index until the app was reopened.
                let hasIndexingWork = appState.indexingBatch != nil
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

        // Wave R-2a: `appState.loggingContext` was wired here — a hand-made `ModelContext` that
        // existed only for `AppState.logEvent`. Both are gone; the three trail writers use the
        // view's `@Environment(\.modelContext)`, which is the container's main context.
    }

    // MARK: - Activity Continuation

    /// Handles a Handoff or deep-link continuation for a specific document.
    @MainActor
    private func continueDocumentActivity(_ activity: NSUserActivity, from sceneID: SceneID?) {
        guard let volumeId = activity.userInfo?["volumeId"] as? String,
              let documentId = activity.userInfo?["documentId"] as? String else { return }
        guard appState.claimContinuation("handoff|\(volumeId)/\(documentId)") else { return }
        navigateToDocument(volumeId: volumeId, documentId: documentId,
                           title: activity.title, from: sceneID)
    }

    /// A Spotlight result tapped: the identifier is `"<volumeId>/<documentId>"`, minted by
    /// `IndexingPipeline` when it donates the item.
    @MainActor
    private func continueSpotlightActivity(_ activity: NSUserActivity, from sceneID: SceneID?) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return }
        let parts = identifier.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        guard appState.claimContinuation("spotlight|\(identifier)") else { return }
        navigateToDocument(volumeId: parts[0], documentId: parts[1],
                           title: activity.title, from: sceneID)
    }

    /// Pushes navigation to the requested document on both platforms. Handoff/Spotlight
    /// continuations have no spawning window, so on macOS the open is `.global` — resolved
    /// straight through the fallback chain (owner decision D3), minting a standalone
    /// document window when no host is live.
    @MainActor
    private func navigateToDocument(volumeId: String, documentId: String, title: String?,
                                    from sceneID: SceneID?) {
        let entry = DocumentBrowserEntry(
            documentId: documentId,
            volumeId: volumeId,
            header: title ?? documentId
        )
        #if os(macOS)
        appState.openDocument(entry, from: .global) { orphan in
            openWindow(value: DocumentWindowID(entry: orphan))
        }
        #else
        // #752 / M-25: address the window the continuation was delivered to, published by
        // `ContinuationHost`. It used to be `.anyWindow` on the reasoning that a continuation has
        // no spawning window — true of a deep link, but a user activity *is* delivered to a scene,
        // and `.anyWindow` is first-observer-wins across every open iPad window. `sceneID` is nil
        // only if the host is not wrapped, in which case `openTab`/`openBrowseDocument` fall back
        // to the wildcard and the old behaviour returns.
        //
        // Tab first, then content — and both to the SAME target, which is what makes the BUG-7
        // guarantee (`openTab`'s doc) true here. With two wildcards it was not: `MainTabView`
        // exists in every window while `BrowserView` must have bootstrapped, so the tab switch and
        // the document could be awarded to different windows.
        appState.openTab(.browse, from: sceneID)
        appState.openBrowseDocument(entry, from: sceneID)
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

    /// A **redacted** CloudKit diagnostic: a user-facing, identifier-free `message` plus the safe
    /// aggregate used by the sync-telemetry log (#188-C.1). Carries no record ids, zone/owner
    /// names, `localizedDescription`, or any `userInfo` value.
    struct CloudKitDiagnosticResult {
        /// A short id-free summary suitable for the sync-status UI.
        let message: String
        /// The top-level error domain (e.g. `CKErrorDomain`).
        let domain: String?
        /// The top-level error code.
        let code: Int?
        /// The top-level error's human code name.
        let codeName: String?
        /// For a `partialFailure`: how many items failed (a scalar count, not ids).
        let partialCount: Int?
        /// For a `partialFailure`: the sub-errors bucketed by code name.
        let histogram: [SubErrorBucket]?
        /// The full allow-listed inspection of the error chain (Wave R-6) — where the per-item
        /// dictionary was found, the schema identifiers the server named, the retry-after hint,
        /// and whether the walk was bounded. Passed straight through to the telemetry row.
        let inspection: CloudKitErrorInspection
    }

    /// Converts a CloudKit `NSError` into a redacted diagnostic: an identifier-free `message` for
    /// the sync-status UI plus the allow-listed aggregate the sync-telemetry log stores.
    ///
    /// For `CKError.partialFailure` (code 2) `localizedDescription` returns the useless "Some
    /// items failed." string, so the diagnosis lives entirely in `CKPartialErrorsByItemIDKey` —
    /// which this counts by sub-error code, never by record id, to produce:
    ///
    ///   `"Partial sync failure (12 records): 10× changeTokenExpired, 2× serverRecordChanged"`
    ///
    /// A one-line summary also goes to `cloudKitLog` (subsystem `bottsywattsy.FRUS-Explorer`,
    /// category `CloudKit`) so it survives relaunch and can be read in Console.app.
    ///
    /// ## Wave R-6 — why this is not one `userInfo` lookup
    /// It used to be, and #488 is what that cost. The lookup ran at exactly one level and, on a
    /// miss, fell through to domain + code; when `NSPersistentCloudKitContainer` re-vended the
    /// failure with the sub-errors one hop down, the log line was `CKErrorDomain partialFailure
    /// (2)` and nothing else, and the cause had to be reconstructed from the CloudKit Console.
    /// ``CloudKitErrorInspector`` now walks the underlying-error chain (bounded), reports whether
    /// it *looked and found nothing* as distinct from never having looked, and recovers the
    /// server's `CD_…` schema identifiers — the four of which named #488's actual cause.
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
    ///   CloudKit Dashboard schema reset or an app update. If `schemaIdentifiers` is non-empty,
    ///   those are the identifiers Production has not been taught about — check
    ///   `CloudKitSchemaInventory.identifiersAwaitingDeploy` (R-7) before anything else.
    /// - **unknownItem (11)**: Record being updated does not exist on the server. Usually
    ///   follows a zone/token reset; resolves after the container re-uploads.
    ///
    /// - Parameter error: The error as CloudKit or SwiftData handed it over.
    /// - Returns: A result carrying no record ids, zone/owner names, `localizedDescription`, or
    ///   any other free text from the error.
    nonisolated static func cloudKitDiagnostic(_ error: NSError) -> CloudKitDiagnosticResult {
        let inspection = CloudKitErrorInspector.inspect(error)

        // The CloudKit code table is only meaningful for CKErrorDomain. Applying it to, say, an
        // NSCocoaErrorDomain error produced a confident wrong name ("code 4" → "networkFailure"),
        // which reads as a diagnosis and is not one.
        let name: String = error.domain == CKErrorDomain
            ? (CloudKitErrorInspector.codeName(for: error.code) ?? "code \(error.code)")
            : "code \(error.code)"
        let schema = inspection.schemaIdentifiers

        // The per-item dictionary is the real diagnosis, wherever in the chain it turned up.
        // The record ids keying it are deliberately NEVER read/logged: a `CKRecord.ID` exposes
        // only its `recordName` (a leaky token) and zone identity, and the record *type* is not
        // recoverable from it — so we key purely on the sub-error code.
        if inspection.hadPartialDictionary, let count = inspection.partialItemCount {
            let histogram = inspection.subErrorHistogram ?? []
            let breakdown = histogram.isEmpty
                ? "no per-item errors reported"
                : histogram.map { "\($0.count)× \($0.key)" }.joined(separator: ", ")
            let depth = inspection.partialDictionaryDepth ?? 0
            cloudKitLog.error("""
                partialFailure records=\(count, privacy: .public) \
                depth=\(depth, privacy: .public) \
                breakdown=\(breakdown, privacy: .public) \
                schema=\(schema.joined(separator: ","), privacy: .public)
                """)
            return CloudKitDiagnosticResult(
                message: "Partial sync failure (\(count) record\(count == 1 ? "" : "s")): \(breakdown)",
                domain: error.domain,
                code: error.code,
                codeName: name,
                partialCount: count,
                histogram: histogram.isEmpty ? nil : histogram,
                inspection: inspection
            )
        }

        // No per-item detail anywhere in the chain: domain + code name only (never
        // localizedDescription — it can embed ids), plus whatever schema identifiers the server
        // named, which is the one thing that made #488 diagnosable after the fact.
        cloudKitLog.error("""
            \(error.domain, privacy: .public) \(name, privacy: .public) \
            code=\(error.code, privacy: .public) \
            partialDict=none visited=\(inspection.errorsVisited, privacy: .public) \
            schema=\(schema.joined(separator: ","), privacy: .public)
            """)
        return CloudKitDiagnosticResult(message: "\(error.domain) \(name)",
                                        domain: error.domain, code: error.code, codeName: name,
                                        partialCount: nil, histogram: nil,
                                        inspection: inspection)
    }
}

// MARK: - Int Helper

private extension Int {
    /// Returns this value if positive, otherwise returns `default`.
    func nonZeroOrDefault(_ default: Int) -> Int { self > 0 ? self : `default` }
}

// MARK: - Menu-Bar Command Plumbing (UI audit gaps 5/6)
//
// The "Document" and "Collection" CommandMenus act on whichever window is key via
// SwiftUI's focused-value mechanism: the window's content publishes an actions
// struct with `.focusedSceneValue(...)`, and the menu content reads it back with
// `@FocusedValue`. When no publishing window is key the value is nil and every
// item is disabled — the gating the audit asked for, with no global state.
//
// The structs are Equatable BY THEIR STATE FIELDS ONLY (closures are excluded —
// they can't be compared). This is load-bearing for the Equatable
// `focusedSceneValue(_:_:)` overload, which uses `==` to decide whether a
// republish is needed: the identity fields must therefore cover every fact the
// menu renders or gates on (enablement booleans, toggle state, the document/
// collection identity), and the closures must only capture values that are
// constant while those fields are unchanged. Publishers keep that contract —
// e.g. MacDocumentView's prev/next entries are loaded once per document, so a
// closure can only go stale if `canGoPrevious`/`canGoNext`/`documentKey` flipped,
// which forces a republish. The types are deliberately NOT platform-guarded (the
// menus are macOS-only, but the plain value types compile everywhere) so the
// equality contract is exercised by the iOS-simulator unit-test runs.

/// Actions the frontmost macOS document surface publishes for the "Document"
/// menu (UI audit gap 6), via `.focusedSceneValue(\.documentCommands, ...)`.
///
/// Published by `MacDocumentView` — which exists in both the main window's
/// navigation stack and standalone `DocumentWindowID` windows — so the menu
/// always drives the key window's own document, and is disabled when no
/// document surface is key (e.g. while the Search or Collections window is
/// frontmost, or the main window is still on its placeholder).
struct DocumentCommandActions: Equatable {

    /// Stable identity of the published document (`volumeId/documentId`).
    /// Part of the equality contract so a navigation to a different document
    /// republishes even when every capability flag happens to match.
    let documentKey: String

    /// Whether a previous document exists in the volume's reading sequence
    /// (mirrors the in-document "Previous" button's presence).
    let canGoPrevious: Bool

    /// Whether a next document exists in the volume's reading sequence
    /// (mirrors the in-document "Next" button's presence).
    let canGoNext: Bool

    /// Whether an in-document text selection is active (mirrors the research
    /// strip's Highlight button enablement).
    let canHighlight: Bool

    /// Whether the Notes/Tags/Summary research panel is currently shown —
    /// renders the menu toggle's checkmark.
    let isResearchPanelVisible: Bool

    /// Navigates to the previous document in the volume (the "Previous" button).
    let goPrevious: @MainActor () -> Void

    /// Navigates to the next document in the volume (the "Next" button).
    let goNext: @MainActor () -> Void

    /// Opens the research-note composer window for this document (the research
    /// strip's "Add note" button).
    let addNote: @MainActor () -> Void

    /// Saves the current selection as a highlight of the given color (the floating
    /// selection bar's colour dots).
    let highlightSelection: @MainActor (DocumentHighlight.Color) -> Void

    /// Toggles the Research rail (⌘⇧R / the titlebar + document-window rail toggles).
    let toggleResearchPanel: @MainActor () -> Void

    /// Opens the current document in its own `DocumentWindowID` window — the File menu's
    /// "Open Document in New Window" (replaces the retired research strip's New Window verb, C2.2).
    let openInNewWindow: @MainActor () -> Void

    /// Whether find-in-document is available (a document is loaded in this window). Always
    /// true when a `DocumentCommandActions` is published; part of the equality contract only
    /// for symmetry (#363 #5).
    let canFindInDocument: Bool

    /// Shows this document's find bar and focuses it — the Find menu's "Find in Document" (⌘F).
    let startFindInDocument: @MainActor () -> Void

    /// Advances to the next match in this document — the Find menu's "Find Next" (⌘G).
    let findNext: @MainActor () -> Void

    /// Moves to the previous match in this document — the Find menu's "Find Previous" (⌘⇧G).
    let findPrevious: @MainActor () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.documentKey == rhs.documentKey
            && lhs.canGoPrevious == rhs.canGoPrevious
            && lhs.canGoNext == rhs.canGoNext
            && lhs.canHighlight == rhs.canHighlight
            && lhs.isResearchPanelVisible == rhs.isResearchPanelVisible
            && lhs.canFindInDocument == rhs.canFindInDocument
    }
}

/// Actions the Collections window's root view publishes for the "Collection"
/// menu (UI audit gap 5), via `.focusedSceneValue(\.collectionManagerCommands, ...)`.
///
/// Separate from `CollectionDetailCommandActions` because "New Collection" must
/// work while no collection is selected — the root view always exists while the
/// window is key, whereas the detail pane exists only with a selection.
struct CollectionManagerCommandActions: Equatable {

    /// Opens the New Collection sheet (the sidebar toolbar's "+" button).
    let newCollection: @MainActor () -> Void

    /// Stateless by design — the struct carries no menu-rendered state, so any
    /// two published instances are interchangeable (the closure captures only
    /// the window's stable `@State` storage).
    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

/// Actions the Collections window's detail pane publishes for the "Collection"
/// menu (UI audit gap 5), via `.focusedSceneValue(\.collectionDetailCommands, ...)`.
///
/// Nil (menu items disabled) whenever no collection is selected or the
/// Collections window is not key. Every action mirrors an existing detail-pane
/// control: the Add Documents / Export toolbar buttons, the structural-add
/// menu's heading/prose items, and the Preview toolbar toggle.
struct CollectionDetailCommandActions: Equatable {

    /// The selected collection's identity — forces a republish when the
    /// selection changes even if the capability flags happen to match.
    let collectionId: UUID

    /// Whether the live preview pane is currently shown — renders the menu
    /// toggle's checkmark.
    let isPreviewShown: Bool

    /// Whether Export is available (entries exist, or the collection is smart —
    /// mirrors the Export toolbar button's `disabled` condition).
    let canExport: Bool

    /// Whether the collection has any entries — gates Sort by Date (M1).
    let hasEntries: Bool

    /// Whether the collection has any document entries — gates Add Passages (M1).
    let hasDocuments: Bool

    /// Opens the Add Documents sheet (⌘⇧A — the shortcut the toolbar button
    /// used to own; the menu item owns it now).
    let addDocuments: @MainActor () -> Void

    /// Appends a section heading to the outline (the structural-add menu item).
    let addHeading: @MainActor () -> Void

    /// Appends a prose note block to the outline (the structural-add menu item).
    let addProse: @MainActor () -> Void

    /// Opens the bulk Add Highlighted Passages sheet (M1 — the ribbon's
    /// Add Passages button).
    let addHighlights: @MainActor () -> Void

    /// Inserts a generated apparatus block of the given type (M1 — the ribbon's
    /// Apparatus menu).
    let addApparatus: @MainActor (CollectionGeneratedBlockType) -> Void

    /// Re-orders the collection's entries chronologically (M1 — the ribbon's
    /// Sort by Date button).
    let sortByDate: @MainActor () -> Void

    /// Toggles the live preview pane (the Preview toolbar button).
    let togglePreview: @MainActor () -> Void

    /// Opens the ⚙ Collection settings popover (Composer v2 §B — replaces the old inline
    /// Composition / Front-Matter disclosure toggles, which are gone).
    let toggleSettings: @MainActor () -> Void

    /// Opens the Export sheet (the Export… toolbar button).
    let exportCollection: @MainActor () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.collectionId == rhs.collectionId
            && lhs.isPreviewShown == rhs.isPreviewShown
            && lhs.canExport == rhs.canExport
            && lhs.hasEntries == rhs.hasEntries
            && lhs.hasDocuments == rhs.hasDocuments
    }
}

/// Focused-value key for `DocumentCommandActions` (see `FocusedValues.documentCommands`).
private struct DocumentCommandsKey: FocusedValueKey {
    /// The published value type.
    typealias Value = DocumentCommandActions
}

/// Focused-value key for `CollectionManagerCommandActions`
/// (see `FocusedValues.collectionManagerCommands`).
private struct CollectionManagerCommandsKey: FocusedValueKey {
    /// The published value type.
    typealias Value = CollectionManagerCommandActions
}

/// Focused-value key for `CollectionDetailCommandActions`
/// (see `FocusedValues.collectionDetailCommands`).
private struct CollectionDetailCommandsKey: FocusedValueKey {
    /// The published value type.
    typealias Value = CollectionDetailCommandActions
}

extension FocusedValues {

    /// The key document window's reading actions (UI audit gap 6), published by
    /// `MacDocumentView` and consumed by `DocumentMenuContent`.
    var documentCommands: DocumentCommandActions? {
        get { self[DocumentCommandsKey.self] }
        set { self[DocumentCommandsKey.self] = newValue }
    }

    /// The Collections window's selection-independent actions (UI audit gap 5),
    /// published by `MacCollectionManagerView` and consumed by `CollectionMenuContent`.
    var collectionManagerCommands: CollectionManagerCommandActions? {
        get { self[CollectionManagerCommandsKey.self] }
        set { self[CollectionManagerCommandsKey.self] = newValue }
    }

    /// The Collections window's selected-collection actions (UI audit gap 5),
    /// published by its detail pane and consumed by `CollectionMenuContent`.
    var collectionDetailCommands: CollectionDetailCommandActions? {
        get { self[CollectionDetailCommandsKey.self] }
        set { self[CollectionDetailCommandsKey.self] = newValue }
    }
}

#if os(macOS)

// MARK: - Open Document in New Window (File menu, Research-rail C2.2)

/// File ▸ "Open Document in New Window". Enabled only when a document surface is key with a loaded
/// document; opens that document in its own standalone `DocumentWindowID` window via
/// `\.documentCommands`. `@FocusedValue` must be read inside a `View`, hence this tiny wrapper
/// (mirrors `DocumentMenuContent`). Replaces the retired research strip's New Window verb.
struct OpenDocumentInNewWindowMenuItem: View {
    @FocusedValue(\.documentCommands) private var commands
    var body: some View {
        Button(String(localized: "menu.file.openInNewWindow",
                      defaultValue: "Open Document in New Window")) {
            commands?.openInNewWindow()
        }
        .disabled(commands == nil)
    }
}

// MARK: - Document Menu Content

/// Body of the "Document" CommandMenu (UI audit gap 6).
///
/// Reads `\.documentCommands` — nil (every item disabled) unless a document
/// surface is key with a loaded document. Shortcut choices, checked against the
/// app and system for collisions:
///   - ⌥⌘↑ / ⌥⌘↓ prev/next document: ⌘←/⌘→ were rejected because menu key
///     equivalents pre-empt the field editor's line-start/line-end navigation in
///     every text field app-wide; ⌥⌘↑/↓ has no NSTextView binding and no other
///     claimant in this app.
///   - ⌘⇧N add note: free (⌘N is the system "New Window" on the main WindowGroup).
///   - ⌘⇧H highlight selection (on the Yellow item — the picker's first color;
///     the submenu carries all four): free app-wide.
///   - ⌘⇧R research panel: free (Research *window* is ⌥⌘R).
struct DocumentMenuContent: View {

    /// The key document window's published actions; nil disables every item.
    @FocusedValue(\.documentCommands) private var commands

    var body: some View {
        Button(String(localized: "menu.document.previous",
                      defaultValue: "Previous Document")) {
            commands?.goPrevious()
        }
        .keyboardShortcut(.upArrow, modifiers: [.command, .option])
        .disabled(commands?.canGoPrevious != true)

        Button(String(localized: "menu.document.next",
                      defaultValue: "Next Document")) {
            commands?.goNext()
        }
        .keyboardShortcut(.downArrow, modifiers: [.command, .option])
        .disabled(commands?.canGoNext != true)

        Divider()

        Button(String(localized: "menu.document.addNote",
                      defaultValue: "Add Note…")) {
            commands?.addNote()
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        .disabled(commands == nil)

        // Highlight Selection — a submenu of the same four colors the research
        // strip's picker offers (no new behavior: the strip button opens a
        // color-picker popover, so a single unqualified item would have had to
        // invent a default). The first color (yellow) carries the key equivalent.
        Menu(String(localized: "menu.document.highlight",
                    defaultValue: "Highlight Selection")) {
            ForEach(DocumentHighlight.Color.allCases, id: \.rawValue) { color in
                if color == .yellow {
                    Button(color.displayName) { commands?.highlightSelection(color) }
                        .keyboardShortcut("h", modifiers: [.command, .shift])
                } else {
                    Button(color.displayName) { commands?.highlightSelection(color) }
                }
            }
        }
        .disabled(commands?.canHighlight != true)

        Divider()

        Toggle(isOn: Binding(
            get: { commands?.isResearchPanelVisible ?? false },
            set: { _ in commands?.toggleResearchPanel() }
        )) {
            Text(String(localized: "menu.document.researchPanel",
                        defaultValue: "Show Research Panel"))
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .disabled(commands == nil)
    }
}

// MARK: - Find Menu Content (#363 #5)

/// Content of the menu-bar **Find** menu (#363 #5).
///
/// Groups the three "finding" flows: **Find in Document** (⌘F — the focused
/// document's in-page find bar, driven through `\.documentCommands`, so it targets
/// the key document window and is disabled when no document surface is key), plus
/// **Find Next** (⌘G) / **Find Previous** (⌘⇧G); full-text **Search** (⌘S — moved
/// off ⌘F, which Find in Document now owns; the app has no Save command, so ⌘S was
/// free); and **Citation Lookup** (⌘⇧F). Search / Citation Lookup are the sole
/// owners of their key equivalents (removed from the window scenes, mirroring #2).
struct FindMenuContent: View {

    /// The key document window's commands (nil ⇒ the find-in-document items are disabled).
    @FocusedValue(\.documentCommands) private var document

    /// The scene's window opener (for Search / Citation Lookup).
    let openWindow: OpenWindowAction

    /// Shared app state — used only to ask the Search window to focus its query field (#749).
    let appState: AppState

    var body: some View {
        Button(String(localized: "menu.find.inDocument", defaultValue: "Find in Document…")) {
            document?.startFindInDocument()
        }
        .keyboardShortcut("f", modifiers: .command)
        .disabled(document == nil)

        Button(String(localized: "menu.find.next", defaultValue: "Find Next")) {
            document?.findNext()
        }
        .keyboardShortcut("g", modifiers: .command)
        .disabled(document == nil)

        Button(String(localized: "menu.find.previous", defaultValue: "Find Previous")) {
            document?.findPrevious()
        }
        .keyboardShortcut("g", modifiers: [.command, .shift])
        .disabled(document == nil)

        Divider()

        Button(String(localized: "menu.find.search", defaultValue: "Search…")) {
            // The user pressed ⌘S to type a query, so put the caret where they expect it (#749).
            appState.searchQueryFocusToken &+= 1
            openWindow.fronting(id: "frus.search")
        }
        .keyboardShortcut("s", modifiers: .command)

        // Corpus Browser sits with Search and Citation Lookup because all three answer "find me
        // something in the corpus" — by term, by citation, by where it sits in the series.
        //
        // It is deliberately NOT in the Window menu. macOS already generates an entry there for
        // every `Window` scene, this one included, so an item of ours beside it was a visible
        // duplicate (#822). The auto-entry raises the window; this one additionally carries ⌘⇧B
        // and clears stale provenance, which is why both can exist without being redundant —
        // provided they are in different menus.
        //
        // ⌘⇧B lives here rather than on the `Window` scene: a scene-level shortcut runs no app
        // code, so it cannot front an open-but-buried browser and appears on no menu at all
        // (#749 / audit L-37).
        Button(String(localized: "menu.find.corpusBrowser", defaultValue: "Corpus Browser…")) {
            appState.bindTool(.corpusBrowser, to: nil)   // clear stale provenance → recency fallback
            openWindow.fronting(id: "frus.corpusBrowser")
        }
        .keyboardShortcut("b", modifiers: [.command, .shift])

        Button(String(localized: "menu.find.citationLookup", defaultValue: "Citation Lookup…")) {
            openWindow.fronting(id: "frus.citationLookup")
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])
    }
}

// MARK: - Collection Menu Content

/// Body of the "Collection" CommandMenu (UI audit gap 5).
///
/// Reads two focused values published by the Collections window:
/// `\.collectionManagerCommands` (root view — New Collection works with nothing
/// selected) and `\.collectionDetailCommands` (detail pane — everything else
/// requires a selected collection). Both are nil while any other window is key,
/// disabling the whole menu. Shortcut choices, checked for collisions:
///   - ⌥⌘N new collection: ⌘N is the system "New Window" item the main
///     WindowGroup contributes, so the audit's suggested ⌘N was taken.
///   - ⌘⇧A add documents: moved from the detail pane's toolbar button (which
///     used to declare it) so the equivalent has exactly one menu-bar owner.
///   - ⌥⌘P preview: ⌘P is conventionally Print; ⌥⌘P is unclaimed here.
///   - ⌘⇧E export (#363 #6a): moved off plain ⌘E, which is macOS-conventionally
///     "Use Selection for Find"; ⌘⇧E is the idiomatic Export binding.
struct CollectionMenuContent: View {

    /// The Collections window's selection-independent actions; nil disables
    /// New Collection.
    @FocusedValue(\.collectionManagerCommands) private var manager

    /// The Collections window's selected-collection actions; nil disables the
    /// authoring and export items.
    @FocusedValue(\.collectionDetailCommands) private var detail

    var body: some View {
        Button(String(localized: "menu.collection.new",
                      defaultValue: "New Collection…")) {
            manager?.newCollection()
        }
        .keyboardShortcut("n", modifiers: [.command, .option])
        .disabled(manager == nil)

        Divider()

        Button(String(localized: "menu.collection.addDocuments",
                      defaultValue: "Add Documents…")) {
            detail?.addDocuments()
        }
        .keyboardShortcut("a", modifiers: [.command, .shift])
        .disabled(detail == nil)

        Button(String(localized: "menu.collection.addHeading",
                      defaultValue: "Add Section Heading")) {
            detail?.addHeading()
        }
        .disabled(detail == nil)

        Button(String(localized: "menu.collection.addProse",
                      defaultValue: "Add Note Block")) {
            detail?.addProse()
        }
        .disabled(detail == nil)

        Button(String(localized: "menu.collection.addHighlights",
                      defaultValue: "Add Highlighted Passages…")) {
            detail?.addHighlights()
        }
        .disabled(detail?.hasDocuments != true)

        // Apparatus (M1): the five generated-block types, mirroring the ribbon's
        // Apparatus menu so the Collection menu and ribbon drive one action set.
        Menu(String(localized: "menu.collection.apparatus", defaultValue: "Insert Apparatus")) {
            ForEach(CollectionGeneratedBlockType.allCases) { blockType in
                Button {
                    detail?.addApparatus(blockType)
                } label: {
                    Label(blockType.displayName, systemImage: blockType.systemImage)
                }
            }
        }
        .disabled(detail == nil)

        Divider()

        Button(String(localized: "menu.collection.sortByDate",
                      defaultValue: "Sort by Date")) {
            detail?.sortByDate()
        }
        .disabled(detail?.hasEntries != true)

        Divider()

        Toggle(isOn: Binding(
            get: { detail?.isPreviewShown ?? false },
            set: { _ in detail?.togglePreview() }
        )) {
            Text(String(localized: "menu.collection.preview",
                        defaultValue: "Show Preview"))
        }
        .keyboardShortcut("p", modifiers: [.command, .option])
        .disabled(detail == nil)

        Button(String(localized: "menu.collection.settings",
                      defaultValue: "Collection Settings…")) {
            detail?.toggleSettings()
        }
        .disabled(detail == nil)

        Button(String(localized: "menu.collection.export",
                      defaultValue: "Export Collection…")) {
            detail?.exportCollection()
        }
        // #363 #6a: ⌘⇧E, not plain ⌘E — ⌘E is macOS-conventionally "Use Selection for Find",
        // and ⌘⇧E is the idiomatic Export binding. Frees ⌘E for text contexts.
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(detail?.canExport != true)
    }
}

/// Content of the menu-bar **Analytics** menu (#363 #4).
///
/// Surfaces the five analytics windows — Corpus / Person / Cross-Reference
/// analytics, Chronology, and Word Cloud — in a proper top-level menu, so they are
/// reachable and discoverable from the menu bar rather than only via the main
/// window's toolbar dropdown (which vanishes when the toolbar is hidden) and the
/// cluttered auto Window menu. Mirrors the toolbar Analytics dropdown's actions.
///
/// Provenance: unlike the toolbar buttons (which bind the tool to their host
/// window), a menu-bar command has no originating host, so each item **clears** the
/// tool's binding (`bindTool(_, to: nil)`) rather than leaving a stale one in place.
/// A cleared binding makes a later document-open resolve through the
/// most-recently-key-host fallback (the same path an originless launch uses) — so
/// the open lands in whatever window the researcher is actually looking at, not a
/// window this analytics tool happened to be launched from earlier. Word Cloud
/// opens on the whole corpus, matching the toolbar affordance.
///
/// Version history:
///   1.0 — #363 #4: initial implementation
struct AnalyticsMenuContent: View {

    /// Shared app state — clears tool provenance and seeds the Word Cloud's corpus scope.
    let appState: AppState
    /// The scene's window opener.
    let openWindow: OpenWindowAction

    var body: some View {
        Button(String(localized: "menu.analytics.corpus", defaultValue: "Corpus Analytics")) {
            appState.bindTool(.analytics, to: nil)   // clear stale provenance → recency fallback
            openWindow.fronting(id: "frus.analytics")
        }
        Button(String(localized: "menu.analytics.person", defaultValue: "Person Analytics")) {
            appState.bindTool(.personAnalytics, to: nil)
            openWindow.fronting(id: "frus.personAnalytics")
        }
        Button(String(localized: "menu.analytics.crossRef", defaultValue: "Cross-Reference Analytics")) {
            appState.bindTool(.crossRefAnalytics, to: nil)
            openWindow.fronting(id: "frus.crossRefAnalytics")
        }
        Button(String(localized: "menu.analytics.archival", defaultValue: "Archival Analytics")) {
            appState.bindTool(.archivalAnalytics, to: nil)
            openWindow.fronting(id: "frus.archivalAnalytics")
        }

        Divider()

        Button(String(localized: "menu.analytics.chronology", defaultValue: "Chronology")) {
            appState.bindTool(.chronology, to: nil)
            openWindow.fronting(id: "frus.chronology")
        }
        Button(String(localized: "menu.analytics.wordcloud", defaultValue: "Word Cloud")) {
            appState.bindTool(.wordCloud, to: nil)
            appState.openWordCloud(.corpus, from: nil)   // corpus scope, matching the toolbar affordance
            openWindow.fronting(id: "frus.wordcloud")
        }
    }
}

/// Content of the menu-bar **Research** menu (#363 #4).
///
/// Groups the researcher's own-work windows — the Research window (notes, tags,
/// collections, highlights; ⌘⌥R) and the Collections manager (⌘⇧K) — and folds the
/// former standalone History menu in as a submenu, so the menu bar carries one
/// "Research" menu instead of scattering these across the auto Window menu, the
/// toolbar dropdown, and a separate History menu.
///
/// This menu is now the **single owner** of ⌘⌥R / ⌘⇧K (#363 #2): the duplicate
/// declarations on the window scenes and the main-window toolbar buttons were
/// removed, so the key equivalents resolve unambiguously here. As with
/// `AnalyticsMenuContent`, the Research item **clears** its tool provenance
/// (`bindTool(.research, to: nil)`) so a note/highlight's document opens in the
/// most-recently-key window; Collections never routes document opens, so it needs
/// no binding at all.
///
/// Version history:
///   1.0 — #363 #4: initial implementation (also folds in History, #2 shortcut owner)
struct ResearchMenuContent: View {

    /// Shared app state — clears Research provenance and feeds the embedded History menu.
    let appState: AppState
    /// The scene's window opener.
    let openWindow: OpenWindowAction
    /// Opens the Settings scene for the "Manage Projects…" item (macOS 14+). Threaded explicitly
    /// like `openWindow` rather than via `@Environment`, which doesn't fully propagate into `.commands`.
    let openSettings: OpenSettingsAction

    var body: some View {
        // #377 Phase 1: Project Home for the ACTIVE project (⌘P — printing isn't implemented, so it's
        // free). Disabled in Global Context (no active project). Value-based, so a distinct project
        // opens its own window and the same project focuses the one already open.
        Button(String(localized: "menu.research.projectHome", defaultValue: "Project Home")) {
            if let pid = appState.activeProjectId {
                openWindow(value: ProjectHomeRequest(projectId: pid))
            }
        }
        .keyboardShortcut("p", modifiers: .command)
        .disabled(appState.activeProjectId == nil)

        // #377 Phase 5: create a project from the menu bar (works from any window). Opens the small
        // New Project window (a menu command can't present a sheet).
        Button(String(localized: "menu.research.newProject", defaultValue: "New Project…")) {
            openWindow.fronting(id: "frus.newProject")
        }

        // #377 Phase 5: switch the app-wide active project from anywhere — a live, checkmarked list.
        // Pure re-scope (no window opened); "Manage Projects…" opens the Settings Projects pane.
        Menu(String(localized: "menu.research.switchProject", defaultValue: "Switch Project")) {
            ProjectSwitcherMenuContent(appState: appState, openSettings: openSettings)
        }

        Divider()

        Button(String(localized: "menu.research.research", defaultValue: "Research")) {
            appState.bindTool(.research, to: nil)   // clear stale provenance → recency fallback
            openWindow.fronting(id: "frus.research")
        }
        .keyboardShortcut("r", modifiers: [.command, .option])

        // Collections never routes document opens — no provenance bind (mirrors the toolbar button).
        Button(String(localized: "menu.research.collections", defaultValue: "Collections")) {
            openWindow.fronting(id: "frus.collections")
        }
        .keyboardShortcut("k", modifiers: [.command, .shift])

        Divider()

        Menu(String(localized: "menu.research.history", defaultValue: "History")) {
            HistoryMenuContent(appState: appState, openWindow: openWindow)
        }
    }
}

/// The live, checkmarked project list for the Research ▸ Switch Project submenu (#377 Phase 5).
///
/// Picking an entry is a PURE re-scope — it sets `appState.activeProjectId` and opens no window
/// (Working-on chrome, search scope, and leads elsewhere follow the active project). The `@Query`
/// resolves via the `.modelContainer(modelContainer)` attached to `ResearchMenuContent` at the
/// CommandMenu site, exactly as the sibling History submenu's `@Query` does, so the list stays live
/// (re-renders on create/rename/delete) with no `AppState` project cache. The checkmark idiom mirrors
/// `ProjectPickerMenu`; "Manage Projects…" hands off to the Settings Projects pane.
struct ProjectSwitcherMenuContent: View {

    /// Shared app state — the active-project lens this submenu reads and writes.
    let appState: AppState
    /// Opens the Settings scene for "Manage Projects…".
    let openSettings: OpenSettingsAction

    @Query(sort: \Project.name) private var projects: [Project]

    /// While the first CloudKit import is still populating projects — AND we have none to show yet —
    /// show a "Syncing…" placeholder instead of a list that would churn as records arrive one batch at
    /// a time (a native menu re-lays-out on every change, which made it hard to land a selection on a
    /// fresh launch). Gated on `projects.isEmpty` so an already-populated local store (a second launch,
    /// or a steady-state export) always shows its list immediately and never flashes the placeholder;
    /// the one-shot `AppState.hasInitialProjectSyncSettled` then stops even a still-empty account from
    /// re-showing it on later syncs.
    private var showSyncingPlaceholder: Bool {
        guard projects.isEmpty, !appState.hasInitialProjectSyncSettled else { return false }
        if case .syncing = appState.cloudKitSyncState { return true }
        return false
    }

    var body: some View {
        #if DEBUG
        // Confirms the initial-sync flicker hypothesis: on a fresh launch this prints projects=0,1,2…
        // climbing as CloudKit imports; on an already-synced launch it prints the full count at once.
        let _ = print("[ProjectSwitcher] projects=\(projects.count) settled=\(appState.hasInitialProjectSyncSettled) placeholder=\(showSyncingPlaceholder)")
        #endif
        Button {
            appState.activeProjectId = nil
        } label: {
            if appState.activeProjectId == nil {
                Label(String(localized: "menu.research.switchProject.global", defaultValue: "Global Context"),
                      systemImage: "checkmark")
            } else {
                Label(String(localized: "menu.research.switchProject.global", defaultValue: "Global Context"),
                      systemImage: "globe")
            }
        }

        if showSyncingPlaceholder {
            Divider()
            Button {} label: {
                Label(String(localized: "menu.research.switchProject.syncing", defaultValue: "Syncing projects…"),
                      systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(true)
        } else if !projects.isEmpty {
            Divider()
            ForEach(projects) { project in
                Button {
                    appState.activeProjectId = project.id
                } label: {
                    if appState.activeProjectId == project.id {
                        Label(project.name, systemImage: "checkmark")
                    } else {
                        Text(project.name)
                    }
                }
            }
        }

        Divider()
        Button(String(localized: "menu.research.switchProject.manage", defaultValue: "Manage Projects…")) {
            // Set the pending pane BEFORE opening Settings so FRUSSettingsView lands on Projects.
            appState.pendingSettingsPaneRaw = SettingsPane.projects.rawValue
            openSettings()
        }
    }
}

#endif // os(macOS)

#if os(iOS)

// MARK: - ContinuationHost

/// Publishes a scene identity **above** the tab view, so a Spotlight / Handoff / open-with
/// continuation can be addressed to the window that received it (#752 / M-25).
///
/// ## The problem this exists for
/// `.onContinueUserActivity` and `.onOpenURL` are attached inside the main `WindowGroup`'s content,
/// so they run once per window — but their closures live on the `App` struct, and the scene
/// identity was minted two levels below them in `MainTabView`. A handler therefore had no window to
/// name and addressed the `.anyWindow` wildcard, which is first-observer-wins. With two iPad windows
/// open, the OS brings one forward and the navigation could land in the other.
///
/// Worse than one wrong window: the tab channel and the content channel are consumed by **different
/// views with different eligibility**. `MainTabView` exists in every window; `BrowserView` only wins
/// once its view model has bootstrapped. A window that has never visited Browse can take the tab
/// switch while another takes the document — so the two halves split.
///
/// ## What this does
/// Mints the token here and publishes it through `\.sceneID`. `MainTabView` adopts the published
/// value when there is one and keeps its own mint as a fallback, so nothing changes for a host that
/// is not wrapped in this. The three handlers then address the window they fired in.
///
/// ## The claim, and why it is not optional
/// UIKit delivers an activity or a URL to one `UIScene`, and SwiftUI bridges that per scene — so on
/// the expected behaviour one handler runs and `AppState.claimContinuation` never refuses anything.
/// **That expectation is not verified on a device.** If SwiftUI did instead fan the modifier out to
/// every window, addressing each to its own scene would open the document in *all* of them — worse
/// than the wildcard it replaces. The claim bounds that: the first window to fire acts, the rest
/// return, and the outcome degrades to exactly today's "one arbitrary window" rather than N.
///
/// Version history:
///   1.0 — Session 2026-08-10: #752 (audit M-25)
private struct ContinuationHost: ViewModifier {

    /// This window's scene identity, minted once for its live lifetime — the same contract
    /// `MainTabView` had, moved up so the continuation handlers are inside it.
    @State private var sceneIDToken = UUID().uuidString

    /// Handoff from another device: a FRUS document.
    let onDocumentActivity: (NSUserActivity, SceneID) -> Void
    /// Spotlight result tapped.
    let onSpotlight: (NSUserActivity, SceneID) -> Void
    /// A `.fruscollection` opened from Files / AirDrop. There is no custom URL scheme in this app;
    /// the `frusexplorer://` links in rendered documents are intercepted inside the web view and
    /// never reach the OS.
    let onOpenURL: (URL, SceneID) -> Void

    func body(content: Content) -> some View {
        let sceneID = SceneID(sceneIDToken)
        content
            .environment(\.sceneID, sceneID)
            .onContinueUserActivity(AppActivityTypes.document) { onDocumentActivity($0, sceneID) }
            .onContinueUserActivity(CSSearchableItemActionType) { onSpotlight($0, sceneID) }
            .onOpenURL { onOpenURL($0, sceneID) }
    }
}

// MARK: - SourceExplorerWindowContent

/// The content of the standalone iPad Source Explorer window (#752 / L-40).
///
/// ## Why this is a View and not the inline closure it replaced
/// The window's related-documents rows hand a document to the app to open. That producer used to
/// live inline in the scene builder as a plain closure, which **cannot read `\.sceneID`** — the
/// comment it replaced said exactly that — so it addressed the `.anyWindow` wildcard and, alone
/// among the app's thirteen `openBrowseDocument` producers, wrote **no paired `openTab`**.
///
/// Two consequences, both real on a Stage Manager iPad with more than one window:
/// 1. **Wrong window.** `.anyWindow` is first-observer-wins, and the eligible observer is any
///    window whose Browse tab has already bootstrapped a view model — not the window this Source
///    Explorer was opened from.
/// 2. **Delayed surprise.** With no `openTab`, the winning window did not switch to Browse. The
///    document was appended to a Browse stack the user was not looking at, and surfaced whenever
///    they next visited that tab.
///
/// As a View it reads the scene `.auxWindowOrigin` publishes on the scene above — the launching
/// window, or `.anyWindow` once that window has closed, which is the correct degradation.
///
/// ## What this does not fix
/// Nothing in the app calls `requestSceneSessionActivation` (`WindowTargetingTests` pins that),
/// so if the origin window is off-stage the tap still will not be *seen*. This narrows the target
/// from a lottery to the one window that asked; it does not bring that window forward.
///
/// Version history:
///   1.0 — Session 2026-08-10: #752 (audit L-40)
private struct SourceExplorerWindowContent: View {

    /// The restorable request describing this window's content.
    let request: SourceExplorerRequest

    /// Passed as a plain `let`, never `@Environment(AppState.self)`: a non-optional Observable
    /// environment read is resolved eagerly *before* `body` runs, so declaring one in a view the
    /// scene has not injected traps at launch rather than at use.
    let appState: AppState

    /// Published by `.auxWindowOrigin(appState)` on the scene above.
    @Environment(\.sceneID) private var sceneID

    var body: some View {
        NavigationStack {
            SourceExplorerView(
                rawSourceNote: request.rawSourceNote,
                documentYear: request.documentYear,
                indexingPipeline: appState.indexingPipeline,
                onRelatedDocumentTapped: { vid, did in
                    let entry = DocumentBrowserEntry(
                        documentId: did, volumeId: vid,
                        documentNumber: nil, header: did, dateline: nil, sourceNote: nil
                    )
                    // Tab first, then content — the order every other producer uses, so a window
                    // that consumes both lands on Browse before the document arrives.
                    appState.openTab(.browse, from: sceneID)
                    appState.openBrowseDocument(entry, from: sceneID)
                },
                documentHeader: request.documentHeader,
                documentDateline: request.documentDateline,
                documentVolumeId: request.documentVolumeId,
                documentId: request.documentId
            )
        }
    }
}

// MARK: - StandaloneDocumentWindowContent

/// The content of a standalone iPad document window — a reader that **navigates in place** (#752).
///
/// ## What this replaces
/// The window used to host a bare `NavigationStack { DocumentView(entry:) }` with no path of its
/// own. Combined with `.auxWindowOrigin` — which republishes the *launching* window's scene as this
/// window's `\.sceneID` so rail producers have somewhere to present — every document-to-document
/// jump was addressed to a **different window**:
///
/// - a cross-reference tap, or an edge-tap page-turn, delivered the target to the launching
///   window's Browse tab (audit H-7, M-30). Nothing calls `requestSceneSessionActivation`
///   anywhere in the app, so that window was never brought forward: on a Stage Manager iPad the
///   tap looked like a no-op while another stage silently changed;
/// - and when the launching window had been closed — or the app had restored this window, which
///   captures no origin at all — the target degraded to `.anyWindow`, i.e. some third window.
///
/// macOS never had this: `MacDocumentWindowView` pushes onto its own stack. This gives the iPad
/// window the same property, using the host router #751 added to `DocumentView`.
///
/// ## What is deliberately unchanged
/// `.auxWindowOrigin` still publishes the launcher's scene, because the *other* rail producers
/// (word cloud, analytics, chronology) present sheets this window does not host. Document
/// navigation no longer relies on it, which is the part that was silently going elsewhere.
///
/// Version history:
///   1.0 — Session 2026-08-08: #752 (audit H-7, M-30)
private struct StandaloneDocumentWindowContent: View {

    /// The document this window was opened for.
    let id: DocumentWindowID

    /// This window's own reading stack — cross-references and page-turns push and replace here
    /// rather than being handed to another window.
    @State private var navigationPath: [DocumentBrowserEntry] = []

    private var rootEntry: DocumentBrowserEntry {
        DocumentBrowserEntry(documentId: id.documentId, volumeId: id.volumeId, header: id.header)
    }

    var body: some View {
        // NavigationStack is required so DocumentView's .navigationTitle and toolbar items render
        // in a proper nav bar for the scene window.
        NavigationStack(path: $navigationPath) {
            DocumentView(entry: rootEntry, onNavigateToDocument: navigate)
                .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                    DocumentView(entry: entry, onNavigateToDocument: navigate)
                }
        }
    }

    /// Follows a jump inside this window (#752), honouring #751's push/replace distinction.
    private func navigate(_ entry: DocumentBrowserEntry, _ jump: DocumentJump) {
        if jump == .replace, !navigationPath.isEmpty {
            navigationPath.removeLast()   // a page-turn moves, not descends
        }
        navigationPath.append(entry)
    }
}

#endif
