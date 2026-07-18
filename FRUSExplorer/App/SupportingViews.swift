// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import AppKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - HighlightCoordinator

/// Shared observable state for the document highlight workflow on macOS.
///
/// Owned by `MainWindowView` and passed by reference to both `ResearchStripView`
/// (which hosts the toolbar buttons) and `MacDocumentView` (which performs text
/// selection and SwiftData insertion). Resetting on document navigation is handled
/// by `MainWindowView.onChange(of: currentEntry)`.
@Observable
/// Shared observable state for the document highlight workflow on macOS.
///
/// Owned by `MainWindowView` and passed by reference to both `ResearchStripView`
/// (which hosts the toolbar buttons) and `MacDocumentView` (which performs text
/// selection and SwiftData insertion). Resetting on document navigation is handled
/// by `MainWindowView.onChange(of: currentEntry)`.
///
/// Session 147: removed `showHighlightMode`, `highlightTextSelection`, and
/// `createHighlightAction` — the WebKit renderer uses `webKitSelectionRange` instead.
///
/// Authoring Phase 5 review fixes: `currentRenderingVersion` removed in favour of
/// `makeExcerptCaptureAction` — MacDocumentView builds the whole excerpt capture,
/// re-extracting the frozen passage from the flat text next to its anchors.
final class HighlightCoordinator {

    /// WebKit selection range — `(start, end)` Unicode-scalar offsets.
    /// Non-nil when the user has an active selection in `FRUSDocumentWebView`.
    /// Cleared after a highlight is created or the selection is collapsed.
    var webKitSelectionRange: (Int, Int)? = nil

    /// The raw text of the current WebKit selection, as reported by
    /// `window.getSelection().toString()`. Pre-populates the NARA Catalog lookup field.
    var webKitSelectedText: String? = nil

    /// The enclosing footnote body for a footnote selection (the JS `blockText`, #269), or
    /// `nil` for an in-document selection. Feeds the NARA lookup's candidate-citation scan,
    /// which needs the whole note — a footnote selection has no offset range for Swift's
    /// own block-aware look-around.
    var webKitSelectedBlockText: String? = nil

    /// Called by `MacDocumentView` to create a `DocumentHighlight` from the
    /// WebKit selection range and colour chosen in `highlightColorPicker`.
    var createWebKitHighlightAction: ((DocumentHighlight.Color) -> Void)? = nil

    /// Builds an excerpt capture from the current selection (Authoring Phase 5).
    /// Registered by `MacDocumentView` — which owns the render model — so the frozen
    /// passage is re-extracted block-aware from the flat text alongside its offsets
    /// and rendering version (decision A9), never frozen from the raw
    /// `sel.toString()` string (which includes `data-skip` footnote-marker digits
    /// the offsets exclude). Returns `nil` when no selection text is available.
    var makeExcerptCaptureAction: (() -> CollectionExcerptCapture?)? = nil

    /// The `DocumentHighlight.id` of the most recently created highlight.
    /// Non-nil while the "Add Note to Highlight" button should be enabled.
    var pendingHighlightLink: UUID? = nil

    func reset() {
        webKitSelectionRange = nil
        webKitSelectedText   = nil
        webKitSelectedBlockText = nil
        pendingHighlightLink = nil
        createWebKitHighlightAction = nil
        makeExcerptCaptureAction = nil
    }
}

// MARK: - SummaryBlockView

/// Inline AI summary block rendered within the document body.
///
/// Shows the most recent summary with prompt label and history cycling controls.
/// Collapses to a "Summarize" prompt when no summary exists.
/// Hidden entirely when `SummarizationService` is unavailable.
///
/// Version history:
///   1.0 — New UI scaffolding
struct SummaryBlockView: View {
    @Bindable var vm: DocumentViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showPromptPicker: Bool = false

    /// Whether the on-device model can generate new summaries right now.
    /// Existing summaries (possibly synced from other devices) are always shown;
    /// only the generate/regenerate affordances are gated.
    private var aiAvailable: Bool { AppleIntelligenceProvider.shared.isAvailable }

    /// Compact older/newer navigation across a document's summary history (shown only when more
    /// than one summary exists) — kept on the header's first row so it stays beside the identity
    /// label in the narrow rail.
    private var summaryHistoryNav: some View {
        HStack(spacing: 2) {
            Button {
                if vm.activeSummaryIndex < vm.summaries.count - 1 {
                    vm.activeSummaryIndex += 1
                }
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .disabled(vm.activeSummaryIndex >= vm.summaries.count - 1)
            .help(String(localized: "summary.history.older.help", defaultValue: "Show older summary"))
            .accessibilityLabel(String(localized: "summary.history.older.a11y", defaultValue: "Older summary"))

            Text("\(vm.activeSummaryIndex + 1)/\(vm.summaries.count)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Button {
                if vm.activeSummaryIndex > 0 { vm.activeSummaryIndex -= 1 }
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .disabled(vm.activeSummaryIndex <= 0)
            .help(String(localized: "summary.history.newer.help", defaultValue: "Show newer summary"))
            .accessibilityLabel(String(localized: "summary.history.newer.a11y", defaultValue: "Newer summary"))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header — two rows so the identity label and the Change-prompt / Regenerate controls
            // don't collide and clip in the ~270 pt Research rail (C1 follow-up; this view now lives
            // only in the rail, so it can optimize for that width unconditionally).
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Label("AI summary", systemImage: "sparkles")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.7)

                    if vm.activeSummary != nil {
                        Text("· custom prompt")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)

                    if vm.summaries.count > 1 {
                        summaryHistoryNav
                    }
                }

                if aiAvailable {
                    HStack(spacing: 12) {
                        Button("Change prompt") { showPromptPicker = true }
                            .font(.system(size: 10))
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .popover(isPresented: $showPromptPicker) {
                                SummaryPromptPickerView(vm: vm)
                            }

                        Button("Regenerate") { Task { await regenerateSummary() } }
                            .font(.system(size: 10))
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .disabled(vm.isSummarizing)

                        Spacer(minLength: 0)
                    }
                }
            }

            // Error from the most recent generation attempt — visible regardless
            // of whether a previous summary exists below it.
            if let error = vm.summarizationError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .accessibilityLabel(String(
                        localized: "summary.error.a11y",
                        defaultValue: "Summarization failed: \(error)"
                    ))
            }

            // Body
            if vm.isSummarizing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Summarizing…").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            } else if let summary = vm.activeSummary {
                Text(summary.responseText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            } else if aiAvailable {
                Button("Summarize this document") { Task { await regenerateSummary() } }
                    .font(.system(size: 13))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            } else {
                // No summary and no way to make one on this hardware — explain
                // instead of offering a button that fails silently.
                Text(String(
                    localized: "summary.unavailable.explanation",
                    defaultValue: "Apple Intelligence is not available on this device, so new summaries cannot be generated. Summaries created on your other devices still appear here via iCloud."
                ))
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color.green.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.green.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func regenerateSummary() async {
        guard let service = appState.summarizationService else { return }
        let provider = AppleIntelligenceProvider.shared
        // Default prompt nil — picked in prompt picker popover.
        // If no prompt is selected, SummarizationService uses the standard prompt.
        if let prompts = try? modelContext.fetch(
            FetchDescriptor<SummarizationPrompt>(sortBy: [SortDescriptor(\.createdAt)])
        ), let prompt = prompts.first {
            await vm.generateSummary(
                prompt: prompt,
                provider: provider,
                service: service,
                activeProjectId: appState.activeProjectId,
                context: modelContext
            )
        }
    }
}

// FootnoteSectionView removed in Session 147.
// Footnotes are now rendered inline via the HTML Popover API in FRUSDocumentWebView.

// MARK: - StatusBarView

/// Persistent status bar at the bottom of the main macOS window.
///
/// Three zones:
/// - Left: indexed volume count (stable, low-noise)
/// - Centre: active background task with progress bar and ETA
/// - Right: CloudKit sync state
///
/// Progress is driven by `AppState.currentIndexingProgress` (now cross-platform)
/// and `AppState.downloadQueue`.
///
/// When a multi-volume batch is in progress (`AppState.indexingQueuePosition` is
/// non-nil) a `↑` chevron appears next to the centre zone label. Clicking the
/// centre zone opens `MacIndexingQueuePopover` with the full queue detail.
///
/// Version history:
///   1.0 — New UI scaffolding
///   1.1 — Session 118: centre zone tappable during multi-volume batches; opens
///          `MacIndexingQueuePopover` with position, progress, ETA, and pending list;
///          auto-closes when indexing completes
///   1.2 — Session 2026-07-04 (macOS UI audit B7): the WhileIndexing sheet is gone —
///          it auto-presented 0.6 s after indexing started, interrupting whatever the
///          user was doing. The "Learn" button (and the queue panel's) now opens the
///          existing frus.researchGuide window instead; nothing auto-presents. iOS
///          keeps its banner-driven education sheet (`IndexingQueueBannerView`).
struct StatusBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var showQueuePopover = false

    var body: some View {
        HStack(spacing: 16) {

            // Left: index count
            HStack(spacing: 5) {
                Circle()
                    .fill(indexedCount > 0 ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text("\(indexedCount) volume\(indexedCount == 1 ? "" : "s") indexed")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Centre: active task.
            // Tappable when a multi-volume batch is in progress — opens
            // MacIndexingQueuePanel with full queue detail.
            if let task = activeTask {
                activeTaskView(task)
            }

            // "Learn" button — always visible while any indexing is active,
            // giving persistent access to the research guide even when the
            // queue panel (which also has the button) isn't open. Opens the
            // frus.researchGuide window (UI audit B7) — a click-through, never
            // an auto-presented modal.
            if appState.currentIndexingProgress != nil {
                Button {
                    openResearchGuide()
                } label: {
                    Label(String(localized: "statusbar.learn.label", defaultValue: "Learn"),
                          systemImage: "book.pages")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help(String(localized: "statusbar.learn.help",
                             defaultValue: "Learn about FRUS and set up your research context"))
            }

            Spacer()

            // Right: iCloud sync state.
            // Layer 1 — container init: shows "Local Only" if CloudKit init failed.
            // Layer 2 — live events: reflects the most recent import/export event.
            cloudKitStatusChip
        }
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        // Auto-clear the completion summary after 6 seconds.
        .task(id: appState.completedIndexingMetadata?.volumeId) {
            guard appState.completedIndexingMetadata != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            appState.completedIndexingMetadata = nil
        }
        // Close the queue popover when indexing finishes.
        .onChange(of: appState.currentIndexingProgress) { _, progress in
            if progress == nil { showQueuePopover = false }
        }
        // No auto-presented education modal on macOS (UI audit B7): the sheet that
        // popped 0.6 s after indexing started interrupted first-run exploration.
        // The "Learn" button above is the click-through to the research guide window.
    }

    /// Opens (and foregrounds) the standalone Research Guide window — the same
    /// educational pages the removed WhileIndexing sheet showed (UI audit B7).
    private func openResearchGuide() {
        openWindow(id: "frus.researchGuide")
        bringMacWindowToFront(id: "frus.researchGuide")
    }

    // MARK: - Computed

    /// Volumes that are both downloaded and present in the FTS5 index.
    ///
    /// Uses `appState.indexedVolumeIds` (Set, seeded at boot) for O(1) lookups instead
    /// of per-volume SQLite queries. The previous implementation ran `isVolumeIndexed()`
    /// (prepare/step/finalize) for every downloaded volume on every body re-evaluation.
    /// Because StatusBarView observes `currentIndexingProgress` (updated ~10×/s), this
    /// caused hundreds of SQLite calls per second on the main thread, making the education
    /// sheet laggy when scrolling or advancing pages.
    private var indexedCount: Int {
        guard let dm = appState.downloadManager else { return 0 }
        return appState.indexedVolumeIds.filter { dm.isVolumeDownloaded($0) }.count
    }

    private struct ActiveTask {
        let label: String
        let systemImage: String
        let progress: Double?
        let eta: String?
        var isSuccess: Bool = false
    }

    private var activeTask: ActiveTask? {
        // Post-index summary (highest priority — replaces the in-progress task).
        if let meta = appState.completedIndexingMetadata {
            let title = appState.manifestStore.entry(forVolumeId: meta.volumeId)?.title
                ?? meta.volumeId
            var summary = "Indexed \(title)"
            let statsParts = [
                meta.totalDocuments > 0 ? "\(meta.totalDocuments) docs" : nil,
                meta.uniquePersonCount > 0 ? "\(meta.uniquePersonCount) persons" : nil,
                meta.crossReferenceCount > 0 ? "\(meta.crossReferenceCount) links" : nil
            ].compactMap { $0 }
            if !statsParts.isEmpty { summary += " · " + statsParts.joined(separator: " · ") }
            return ActiveTask(
                label: summary,
                systemImage: "checkmark.circle.fill",
                progress: nil,
                eta: nil,
                isSuccess: true
            )
        }

        if let update = appState.currentIndexingProgress {
            // Special case: during the post-batch FTS5 optimise phase the update
            // carries an empty volumeId and stage == .optimizing. Render a clear
            // "Finalizing index…" label so the status bar doesn't show
            // "Indexing … (5/5)" with a blank volume name and a frozen-looking bar.
            if update.stage == .optimizing {
                return ActiveTask(
                    label: String(
                        localized: "indexing.queue.statusbar.finalizing",
                        defaultValue: "Finalizing index…"
                    ),
                    systemImage: "wand.and.stars",
                    progress: nil,  // indeterminate; optimise() has no sub-progress
                    eta: nil
                )
            }
            let progress: Double? = update.totalDocuments > 0
                ? Double(update.completedDocuments) / Double(update.totalDocuments)
                : nil
            let eta: String? = {
                guard update.docsPerSecond > 0,
                      update.totalDocuments > update.completedDocuments else { return nil }
                let remaining = update.totalDocuments - update.completedDocuments
                let seconds = Double(remaining) / update.docsPerSecond
                var base = "~\(Int(seconds.rounded()))s"
                if let meta = appState.lastDiscoveredMetadata,
                   meta.volumeId == update.volumeId {
                    let summary = statusBarMetaSummary(meta)
                    if !summary.isEmpty { base += " · " + summary }
                }
                return base
            }()
            let label: String = {
                if let qp = appState.indexingQueuePosition {
                    return "Indexing \(update.volumeId)… (\(qp.current)/\(qp.total))"
                }
                return "Indexing \(update.volumeId)…"
            }()
            return ActiveTask(
                label: label,
                systemImage: appState.indexingQueuePosition != nil
                    ? "square.and.arrow.down.on.square"
                    : "square.and.arrow.down",
                progress: progress,
                eta: eta
            )
        }

        if case .running(let processed, let total, let docId) =
            appState.backgroundSummarizationProgress.state {
            let progress: Double? = total > 0
                ? Double(processed) / Double(total)
                : nil
            let label: String = {
                if total == 0 {
                    return "Summarizing…"
                }
                let base = "Summarizing \(processed)/\(total)"
                if let id = docId { return "\(base) — \(id)" }
                return base
            }()
            return ActiveTask(
                label: label,
                systemImage: "sparkles",
                progress: progress,
                eta: nil
            )
        }

        if !appState.downloadQueue.isEmpty {
            return ActiveTask(
                label: "\(appState.downloadQueue.count) download\(appState.downloadQueue.count == 1 ? "" : "s") queued",
                systemImage: "arrow.down.circle",
                progress: nil,
                eta: nil
            )
        }

        return nil
    }

    private func statusBarMetaSummary(_ meta: VolumeMetadataDiscovered) -> String {
        var segments: [String] = []
        if meta.uniquePersonCount > 0 { segments.append("\(meta.uniquePersonCount) persons") }
        if meta.crossReferenceCount > 0 { segments.append("\(meta.crossReferenceCount) links") }
        if meta.datedDocumentCount > 0 {
            segments.append("\(meta.datedDocumentCount)/\(meta.totalDocuments) dated")
        }
        return segments.joined(separator: " · ")
    }

    // MARK: - CloudKit Status Chip

    /// Renders a compact sync-state label for the right side of the status bar.
    ///
    /// Shows "Local Only" when CloudKit init failed, a spinning indicator while a
    /// sync event is in flight, and the error message (with tooltip) when the most
    /// recent event failed.  Falls back to the plain "iCloud Sync" label when no
    /// events have fired yet (i.e. all is well and quiet).
    @ViewBuilder
    private var cloudKitStatusChip: some View {
        if !appState.cloudKitSyncEnabled {
            // Container fell back to local SQLite — CloudKit init failed at launch.
            // Append the actual diagnostic (CloudKit error domain + code name +
            // description) to the tooltip when AppState has one, so the failure's
            // error code is visible directly in the app — not just in Console.app.
            // See AppState.cloudKitInitError / FRUSExplorerApp.cloudKitDiagnostic(_:).
            let guidance = String(
                localized: "statusBar.sync.disabled.help",
                defaultValue: "iCloud sync is unavailable — notes, collections, and tags won't sync across devices. Check that you are signed in to iCloud and that the app has iCloud permissions in System Settings."
            )
            // Computed via an immediately-invoked closure (not an `if`/`else` directly
            // in this @ViewBuilder body) — a plain `if let … else …` whose branches
            // only assign to `help` makes the result-builder transform try to coerce
            // each branch's `()` result to `View`, producing "Type '()' cannot conform
            // to 'View'". Wrapping the assignment in a closure keeps it a normal
            // expression the builder evaluates once, outside the View-producing chain.
            let help: String = {
                guard let initError = appState.cloudKitInitError else { return guidance }
                return "\(guidance)\n\n\(String(localized: "statusBar.sync.disabled.diagnostic.label", defaultValue: "Diagnostic")): \(initError)"
            }()
            Label(
                String(localized: "statusBar.sync.disabled", defaultValue: "Local Only"),
                systemImage: "icloud.slash"
            )
            .font(.system(size: 11))
            .foregroundStyle(.orange)
            .help(help)
        } else {
            switch appState.cloudKitSyncState {
            case .unknown:
                // Waiting for the first event; assume OK until proven otherwise.
                Label(
                    String(localized: "statusBar.sync.enabled", defaultValue: "iCloud Sync"),
                    systemImage: "checkmark.icloud"
                )
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .help(String(localized: "statusBar.sync.enabled.help",
                             defaultValue: "User data syncs via iCloud across your devices"))

            case .syncing:
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.55, anchor: .center).frame(width: 11, height: 11)
                    Text(String(localized: "statusBar.sync.syncing", defaultValue: "Syncing…"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .help(String(localized: "statusBar.sync.syncing.help",
                             defaultValue: "iCloud is syncing your notes, collections, and tags"))

            case .succeeded:
                Label(
                    String(localized: "statusBar.sync.synced", defaultValue: "Synced"),
                    systemImage: "checkmark.icloud"
                )
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .help(String(localized: "statusBar.sync.synced.help",
                             defaultValue: "iCloud sync completed successfully"))

            case .failed(let message):
                Label(
                    String(localized: "statusBar.sync.error", defaultValue: "Sync Error"),
                    systemImage: "exclamationmark.icloud"
                )
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .help(message)
            }

            // Zone-missing warning — overlaid when zone verification has completed
            // and the private zone is absent. This is separate from sync-event failures
            // because zone deletion is a silent failure the event system never reports.
            if appState.cloudKitZoneVerified == false {
                Label(
                    String(localized: "statusBar.sync.zoneMissing", defaultValue: "Zone Missing"),
                    systemImage: "exclamationmark.icloud.fill"
                )
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .help(String(localized: "statusBar.sync.zoneMissing.help",
                             defaultValue: "The iCloud sync zone is missing — data cannot upload or download. Force-quit the app and relaunch to trigger zone recreation, or reset iCloud sync in Settings → Danger Zone."))
            }

            // Account warning — shown when health check detected a non-available status
            if let status = appState.cloudKitAccountStatus, status != .available {
                Label(
                    String(localized: "statusBar.sync.accountIssue", defaultValue: "Not Signed In"),
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .help(AppState.accountStatusDescription(status))
            }
        }
    }

    @ViewBuilder
    private func activeTaskView(_ task: ActiveTask) -> some View {
        if appState.indexingQueuePosition != nil,
           let update = appState.currentIndexingProgress {
            Button {
                showQueuePopover.toggle()
            } label: {
                taskLabel(task, showDisclosure: true)
            }
            .buttonStyle(.plain)
            .help(String(
                localized: "statusbar.indexingQueue.help",
                defaultValue: "Show indexing-queue progress and ETA"
            ))
            .popover(isPresented: $showQueuePopover, arrowEdge: .top) {
                MacIndexingQueuePanel(
                    update: update,
                    queuePosition: appState.indexingQueuePosition!,
                    volumeTitles: appState.indexingQueueVolumeTitles,
                    averageDocsPerSecond: appState.indexingQueueAverageDocsPerSecond,
                    averageDocumentCount: appState.indexingQueueAverageDocumentCount,
                    onLearnTapped: {
                        // B7: a window, not a sheet — no presentation conflict with
                        // the closing popover, so no async-after dance is needed.
                        showQueuePopover = false
                        openResearchGuide()
                    }
                )
            }
        } else {
            taskLabel(task, showDisclosure: false)
        }
    }

    @ViewBuilder
    private func taskLabel(_ task: ActiveTask, showDisclosure: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: task.systemImage)
                .font(.system(size: 11))
                .foregroundStyle(task.isSuccess ? Color.green : .secondary)
            Text(task.label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if let progress = task.progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)
                    .tint(.green)
                if let eta = task.eta {
                    Text(eta)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            if showDisclosure {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - MacIndexingQueuePanel

/// Popover panel showing multi-volume batch indexing progress on macOS.
///
/// Triggered by clicking the active-task zone in `StatusBarView` when
/// `AppState.indexingQueuePosition` is non-nil. Mirrors the information density
/// of `IndexingQueueBannerView` (the iOS equivalent) in a macOS-native popover.
///
/// ## Layout
/// ```
/// [icon] Indexing Queue          Volume 3 of 12
/// ─────────────────────────────────────────────
/// frus1969-76v03
/// ████████████░░░░░░░░  142 / 380 docs    ~4m
/// ─────────────────────────────────────────────
/// [clock] 9 volumes remaining         [chevron]
///   [clock] Volume 4 title…
///   [clock] Volume 5 title…
/// ```
///
/// Version history:
///   1.0 — initial implementation
private struct MacIndexingQueuePanel: View {

    /// Current volume's indexing progress.
    let update: IndexingProgressUpdate
    /// Position in the multi-volume batch (1-based current and fixed total).
    let queuePosition: (current: Int, total: Int)
    /// Titles of volumes still waiting in the queue (not including current).
    let volumeTitles: [String]
    /// Rolling average docs/s from completed volumes in this batch.
    var averageDocsPerSecond: Double = 0
    /// Rolling average document count from completed volumes; falls back to 600.
    var averageDocumentCount: Int = 600
    /// Called when the user taps "Learn about FRUS while you wait" — the presenting
    /// status bar closes this popover and opens the frus.researchGuide window
    /// (UI audit B7; formerly the auto-presenting WhileIndexing sheet).
    var onLearnTapped: (() -> Void)? = nil

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header row
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(String(
                    localized: "indexing.queue.mac.header",
                    defaultValue: "Indexing Queue"
                ))
                .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(String(
                    localized: "indexing.queue.mac.position",
                    defaultValue: "Volume \(queuePosition.current) of \(queuePosition.total)"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            Divider()

            // Current volume progress (or batch-wide "Finalizing" state during
            // the post-storage FTS5 optimise phase, when stage == .optimizing).
            VStack(alignment: .leading, spacing: 5) {
                if update.stage == .optimizing {
                    Label {
                        Text(String(
                            localized: "indexing.queue.mac.finalizing",
                            defaultValue: "Finalizing index — applying optimisations…"
                        ))
                        .font(.system(size: 11, weight: .medium))
                    } icon: {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.mini)
                    }
                    Text(String(
                        localized: "indexing.queue.mac.finalizing.detail",
                        defaultValue: "Merging FTS5 segments for \(update.totalDocuments.formatted()) indexed documents. This may take 30–60 seconds."
                    ))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(update.volumeId)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if update.totalDocuments > 0 {
                        ProgressView(
                            value: Double(update.completedDocuments),
                            total: Double(update.totalDocuments)
                        )
                        .progressViewStyle(.linear)
                        .tint(.accentColor)

                        HStack {
                            Text(String(
                                localized: "indexing.queue.mac.docs",
                                defaultValue: "\(update.completedDocuments) / \(update.totalDocuments) docs"
                            ))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            Spacer()
                            if let eta = totalETAString {
                                Text(eta)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .controlSize(.small)
                    }
                }
            }

            // Pending volumes
            if !volumeTitles.isEmpty {
                Divider()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text(String(
                            localized: "indexing.queue.mac.remaining",
                            defaultValue: "\(volumeTitles.count) volume\(volumeTitles.count == 1 ? "" : "s") remaining"
                        ))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(
                    localized: "indexing.queue.mac.expand.a11y",
                    defaultValue: isExpanded ? "Collapse queue list" : "Expand queue list"
                ))
                .help(isExpanded
                      ? String(localized: "indexing.queue.mac.expand.collapse.help",
                               defaultValue: "Collapse the pending-volumes list")
                      : String(localized: "indexing.queue.mac.expand.expand.help",
                               defaultValue: "Expand to see the next volumes waiting to be indexed"))

                if isExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(volumeTitles.prefix(6), id: \.self) { title in
                            HStack(spacing: 5) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Text(title)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.leading, 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // "Learn while you wait" — opens the educational flow from StatusBarView.
            if let onLearn = onLearnTapped {
                Divider()
                Button {
                    onLearn()
                } label: {
                    Label(
                        String(localized: "indexing.learnWhileWaiting",
                               defaultValue: "Learn about FRUS while you wait →"),
                        systemImage: "book.pages"
                    )
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 300)
    }

    // MARK: - ETA

    /// Combined ETA: remaining docs in current volume + remaining queued volumes.
    private var totalETAString: String? {
        var totalSeconds = 0.0

        if update.docsPerSecond > 0, update.totalDocuments > update.completedDocuments {
            let remaining = update.totalDocuments - update.completedDocuments
            totalSeconds += Double(remaining) / update.docsPerSecond
        }

        let remainingVolumes = queuePosition.total - queuePosition.current
        if remainingVolumes > 0 {
            let dps = averageDocsPerSecond > 0 ? averageDocsPerSecond : update.docsPerSecond
            if dps > 0 {
                let estimatedDocs = averageDocumentCount > 0 ? averageDocumentCount : 600
                totalSeconds += Double(remainingVolumes) * Double(estimatedDocs) / dps
            }
        }

        guard totalSeconds > 0 else { return nil }

        if totalSeconds < 60 {
            return "~\(Int(totalSeconds.rounded()))s"
        } else {
            let minutes = Int((totalSeconds / 60).rounded())
            return "~\(minutes)m"
        }
    }
}

// MARK: - CitationPopoverView

/// Pure builders for a document's citation/export artifacts, shared by the citation
/// popover (which owns its style + resolved-metadata state) and the document Share
/// popover (which owns its own). Keeping these stateless avoids the two views drifting.
///
/// Version history:
///   1.0 — Document Share/Export control split out from the citation popover
@MainActor
enum DocumentExportSupport {

    /// Canonical history.state.gov URL for a document.
    static func canonicalURL(entry: DocumentBrowserEntry) -> String {
        "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
    }

    /// Citation metadata carrying the effective (entry-or-index) document number.
    static func docMeta(entry: DocumentBrowserEntry, documentNumber: String?) -> FRUSDocumentMetadata {
        FRUSDocumentMetadata(
            documentId: entry.documentId,
            documentNumber: documentNumber ?? entry.documentNumber,
            header: entry.header,
            dateline: entry.dateline
        )
    }

    /// Best available publication year: live-parsed first, then a plausible 4-digit
    /// year from the manifest's `publicationDate`, then "n.d.".
    static func effectiveYear(parsed: String?, volume: VolumeManifestEntry) -> String {
        if let live = parsed, !live.isEmpty { return live }
        guard let pd = volume.publicationDate else { return "n.d." }
        let segments = pd.components(separatedBy: .init(charactersIn: "0123456789").inverted)
        if let yr = segments.first(where: { $0.count == 4 }), let y = Int(yr), y > 1750 { return yr }
        return "n.d."
    }

    /// Reads the volume XML header and extracts the publication year.
    static func extractPublicationYear(volumeURL url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            guard let stream = InputStream(url: url) else { return nil }
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 8_192)
            let n = stream.read(&buffer, maxLength: buffer.count)
            guard n > 0, let text = String(bytes: Array(buffer[0..<n]), encoding: .utf8) else { return nil }
            guard let blockStart = text.range(of: "<publicationStmt"),
                  let blockEnd = text.range(of: "</publicationStmt>"),
                  blockStart.lowerBound < blockEnd.lowerBound else { return nil }
            let block = String(text[blockStart.lowerBound..<blockEnd.upperBound])
            if let yr = regexFirstCapture(#"when="(\d{4})""#, in: block),
               let y = Int(yr), y > 1750, y < 2100 { return yr }
            if let yr = regexFirstCapture(#">(\d{4})\s*<"#, in: block),
               let y = Int(yr), y > 1750, y < 2100 { return yr }
            return nil
        }.value
    }

    private nonisolated static func regexFirstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    /// BibTeX record for the document.
    static func bibtex(entry: DocumentBrowserEntry, volume: VolumeManifestEntry,
                       documentNumber: String?, year: String) -> String {
        BibtexExporter().export(
            volumeId: entry.volumeId,
            document: docMeta(entry: entry, documentNumber: documentNumber),
            volume: FRUSVolumeMetadata(volume),
            year: year,
            url: canonicalURL(entry: entry)
        )
    }

    /// RIS record for the document (citation only, no annotations).
    static func ris(entry: DocumentBrowserEntry, volume: VolumeManifestEntry,
                    documentNumber: String?, year: String) -> String {
        RISExporter().export(
            document: docMeta(entry: entry, documentNumber: documentNumber),
            volume: FRUSVolumeMetadata(volume),
            year: year,
            url: canonicalURL(entry: entry)
        )
    }

    /// Zotero item carrying the document's FRUS Explorer tags and research notes.
    static func zoteroItem(entry: DocumentBrowserEntry, volume: VolumeManifestEntry,
                           documentNumber: String?, year: String,
                           context: ModelContext) -> ZoteroJSONExporter.Item {
        let resolved = ZoteroJSONExporter.fetchTagsAndNotes(
            documentId: entry.documentId, volumeId: entry.volumeId, context: context)
        return ZoteroJSONExporter.makeItem(
            document: docMeta(entry: entry, documentNumber: documentNumber),
            volume: FRUSVolumeMetadata(volume),
            year: year,
            url: canonicalURL(entry: entry),
            isEditorialNote: entry.isEditorialNote,
            tags: resolved.tags,
            notes: resolved.notes
        )
    }

    /// Formatted citation (with Markdown italics) for a style and live year.
    static func formatted(entry: DocumentBrowserEntry, volume: VolumeManifestEntry,
                          documentNumber: String?, parsedYear: String?,
                          style: CitationStyle) -> String {
        var volMeta = FRUSVolumeMetadata(volume)
        if let parsedYear { volMeta = volMeta.overridingPublicationYear(parsedYear) }
        return style.makeFormatter().format(
            document: docMeta(entry: entry, documentNumber: documentNumber), volume: volMeta)
    }

    /// Plain-text citation with Markdown italic markers removed.
    static func plainText(_ formatted: String) -> String {
        if let attr = try? AttributedString(
            markdown: formatted, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return String(attr.characters)
        }
        return formatted
            .replacingOccurrences(of: #"_([^_]+)_"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
    }
}

/// Popover displaying a formatted FRUS citation for the current document.
///
/// Three styles: history.state.gov (default), Chicago, Turabian.
/// Volume editors are sourced from `VolumeManifestEntry.editors`.
/// The general editor is intentionally excluded per history.state.gov guidance.
///
/// Version history:
///   1.0 — New UI scaffolding
///   1.1 — Session 86: Export menu (Copy BibTeX, Copy RIS, Save as .bib)
///   1.2 — Session 2026-06-07: Export menu gained "Share Citation…" — a
///         `ShareLink` presenting the system share sheet with a message
///         combining the formatted citation and its canonical
///         history.state.gov URL (`shareableCitationMessage`), mirroring
///         the new "Share Citation" toolbar item on iOS.
///   1.3 — Session 155: Export menu gained "Send to Zotero (BibTeX)…" and
///         "Send to Zotero (JSON)…" — saves a file via `NSSavePanel`, then
///         opens it in Zotero (if installed) or reveals it in Finder.
struct CitationPopoverView: View {
    let entry: DocumentBrowserEntry

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    /// Initial selection mirrors the user's persisted preference
    /// (Settings → Display → Citations); the segmented control below lets the
    /// user switch styles per-presentation for comparison without changing
    /// that preference.
    @State private var selectedStyle: CitationStyle = CitationStyle.current
    /// Publication year extracted live from the volume's TEI `<publicationStmt><date>`.
    /// Preferred over the manifest value, which may contain a coverage range rather
    /// than the actual print year.
    @State private var parsedPublicationYear: String? = nil
    /// Authoritative document number resolved from the index (`document_cache.document_number`),
    /// used when `entry.documentNumber` is `nil` (e.g. the document was opened via a
    /// cross-reference, which builds the entry without the number). Resolved in `.task`.
    @State private var resolvedDocumentNumber: String? = nil

    private var volumeEntry: VolumeManifestEntry? {
        appState.manifestStore.entry(forVolumeId: entry.volumeId)
    }

    /// The document number to cite — the entry's, or the index-resolved value as a fallback.
    private var effectiveDocumentNumber: String? {
        entry.documentNumber ?? resolvedDocumentNumber
    }

    /// Citation metadata for every formatter/exporter in this popover, carrying the
    /// effective (entry-or-index) document number so the number is never dropped.
    private var docMeta: FRUSDocumentMetadata {
        FRUSDocumentMetadata(
            documentId: entry.documentId,
            documentNumber: effectiveDocumentNumber,
            header: entry.header,
            dateline: entry.dateline
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                Label("Citation", systemImage: "quote.closing")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }

            // Document identity
            VStack(alignment: .leading, spacing: 2) {
                Text("Doc \(effectiveDocumentNumber ?? entry.documentId) · \(entry.volumeId)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(entry.header)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            }

            // Style picker
            Picker("Style", selection: $selectedStyle) {
                ForEach(CitationStyle.allCases) { style in
                    Text(style.shortDisplayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help(String(
                localized: "citation.popover.stylePicker.help",
                defaultValue: "Choose citation style (history.state.gov, Chicago, Turabian) for this view — change the default in Settings → Display"
            ))

            // Citation text — rendered as Markdown so _series title_ displays as italic.
            Group {
                if let attrStr = try? AttributedString(
                    markdown: formattedCitation,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    Text(attrStr)
                } else {
                    Text(formattedCitation)
                }
            }
            .font(.custom("Georgia", size: 12))
            .lineSpacing(4)
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
            )

            // Metadata
            if let vol = volumeEntry {
                VStack(alignment: .leading, spacing: 3) {
                    if !vol.editors.isEmpty {
                        metaRow("Volume editors", vol.editors.joined(separator: ", "))
                    }
                    let yr = effectiveYear(for: vol)
                    metaRow("Published", "\(effectivePublisher(year: yr)), \(yr)")
                    if let docNum = effectiveDocumentNumber {
                        metaRow("Document no.", docNum)
                    }
                }
                .font(.system(size: 11))
            }

            // Canonical URL
            if let url = canonicalURL {
                HStack(spacing: 4) {
                    Image(systemName: "link").font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(url)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            // Actions
            HStack(spacing: 6) {
                Button {
                    // Copy plain text — markdown italic markers (_..._ / *...*) are
                    // stripped so the clipboard receives clean text without raw syntax.
                    copyToClipboard(plainTextCitation)
                } label: {
                    Label("Copy citation", systemImage: "doc.on.doc").font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(String(
                    localized: "citation.popover.copyCitation.help",
                    defaultValue: "Copy the formatted citation to the clipboard"
                ))

                if let url = canonicalURL {
                    Button {
                        copyToClipboard(url)
                    } label: {
                        Label("Copy URL", systemImage: "link").font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(String(
                        localized: "citation.popover.copyURL.help",
                        defaultValue: "Copy the canonical history.state.gov URL for this document"
                    ))
                }

                Spacer()

                Menu {
                    Button {
                        if let vol = volumeEntry { copyToClipboard(bibtexString(vol: vol)) }
                    } label: {
                        Label("Copy BibTeX", systemImage: "doc.plaintext")
                    }
                    Button {
                        if let vol = volumeEntry { copyToClipboard(risString(vol: vol)) }
                    } label: {
                        Label("Copy RIS", systemImage: "doc.plaintext")
                    }
                    Divider()
                    Button {
                        if let vol = volumeEntry { saveBibFile(bibtexString(vol: vol)) }
                    } label: {
                        Label("Save as .bib\u{2026}", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Label("Copy as\u{2026}", systemImage: "doc.on.doc").font(.system(size: 11))
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(volumeEntry == nil)
                .help(String(
                    localized: "citation.popover.copyAs.help",
                    defaultValue: "Copy this citation as BibTeX or RIS, or save a .bib file. Sharing and Zotero are on the document’s Share button."
                ))
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 440)
        // Load the publication year from the volume's own TEI header when available.
        // The bundled manifest may have a coverage range in publicationDate rather than
        // the actual print year; the live XML is authoritative.
        .task(id: entry.id) {
            await loadPublicationYear()
            // Backfill the document number from the index when the entry lacks it.
            if entry.documentNumber == nil, let pipeline = appState.indexingPipeline {
                resolvedDocumentNumber = (try? await pipeline.documentNumber(
                    volumeId: entry.volumeId, documentId: entry.documentId)) ?? nil
            }
        }
    }

    // MARK: - Formatted Citation

    /// Builds the formatted citation string for `selectedStyle` via the shared
    /// `CitationFormatter` conformers in `Citation/CitationFormatter.swift`
    /// (relocated here from inline string-building in Session 153).
    ///
    /// The returned string contains Markdown italic markers (`_..._` or `*...*`).
    /// Use `plainTextCitation` when the destination is the clipboard or a share sheet.
    private var formattedCitation: String {
        guard let vol = volumeEntry else {
            return "Citation unavailable — volume metadata not loaded."
        }
        return DocumentExportSupport.formatted(
            entry: entry, volume: vol, documentNumber: effectiveDocumentNumber,
            parsedYear: parsedPublicationYear, style: selectedStyle)
    }

    /// Plain-text version of `formattedCitation` with Markdown italic markers stripped.
    private var plainTextCitation: String {
        DocumentExportSupport.plainText(formattedCitation)
    }

    // MARK: - Publication Year

    /// Best available publication year for `vol` (live-parsed, else manifest, else n.d.).
    private func effectiveYear(for vol: VolumeManifestEntry) -> String {
        DocumentExportSupport.effectiveYear(parsed: parsedPublicationYear, volume: vol)
    }

    private func effectivePublisher(year: String) -> String {
        let y = Int(year) ?? 0
        return y >= 2014
            ? "United States Government Publishing Office"
            : "Government Printing Office"
    }

    /// Reads the publication year live from the volume's TEI header.
    private func loadPublicationYear() async {
        guard let dm = appState.downloadManager,
              dm.isVolumeDownloaded(entry.volumeId) else { return }
        parsedPublicationYear = await DocumentExportSupport.extractPublicationYear(
            volumeURL: dm.volumeURL(for: entry.volumeId))
    }

    // MARK: - BibTeX / RIS Export

    private func bibtexString(vol: VolumeManifestEntry) -> String {
        DocumentExportSupport.bibtex(entry: entry, volume: vol,
                                     documentNumber: effectiveDocumentNumber,
                                     year: effectiveYear(for: vol))
    }

    private func risString(vol: VolumeManifestEntry) -> String {
        DocumentExportSupport.ris(entry: entry, volume: vol,
                                  documentNumber: effectiveDocumentNumber,
                                  year: effectiveYear(for: vol))
    }

    @MainActor
    private func saveBibFile(_ content: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "bib") ?? .data]
        panel.nameFieldStringValue = "\(entry.volumeId)-\(entry.documentId).bib"
        panel.title = "Save BibTeX Citation"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Helpers

    private var canonicalURL: String? {
        DocumentExportSupport.canonicalURL(entry: entry)
    }

    private var accessedDate: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label).foregroundStyle(.secondary).frame(width: 96, alignment: .leading)
            Text(value).foregroundStyle(.primary)
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - DocumentSharePopover

/// Document-level Share / Export popover, presented from the Research strip's
/// "Share" button — independent of the citation popover. Gathers the actions that
/// *send the document somewhere*: into the user's Zotero library via the Web API,
/// out as a Zotero-importable file, or via the system share sheet. Citation copying
/// stays on the Cite popover.
///
/// Version history:
///   1.0 — Document Share/Export control split out from the citation popover
struct DocumentSharePopover: View {
    let entry: DocumentBrowserEntry

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var parsedPublicationYear: String?
    @State private var resolvedDocumentNumber: String?
    @State private var zoteroResult: ZoteroSendResult?
    @State private var zoteroSending = false
    @State private var zoteroError: String?

    private var volumeEntry: VolumeManifestEntry? {
        appState.manifestStore.entry(forVolumeId: entry.volumeId)
    }
    private var effectiveDocumentNumber: String? {
        entry.documentNumber ?? resolvedDocumentNumber
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Share / Export", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            Text(entry.header)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Divider()

            if let vol = volumeEntry {
                if ZoteroAccountStore.shared.isConnected {
                    actionRow("Send to Zotero Library", systemImage: "books.vertical",
                              busy: zoteroSending) {
                        Task { await sendToZoteroLibrary(vol: vol) }
                    }
                    Text("Adds this document — with your tags and research notes — straight to your Zotero library.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                actionRow("Export Zotero file (RIS)\u{2026}", systemImage: "doc.badge.arrow.up") {
                    sendToZoteroFile(zoteroRIS(vol: vol), ext: "ris", type: .init(filenameExtension: "ris") ?? .text)
                }
                actionRow("Export Zotero file (BibTeX)\u{2026}", systemImage: "doc.badge.arrow.up") {
                    sendToZoteroFile(DocumentExportSupport.bibtex(entry: entry, volume: vol,
                                                                 documentNumber: effectiveDocumentNumber,
                                                                 year: year(vol)),
                                     ext: "bib", type: .init(filenameExtension: "bib") ?? .data)
                }
                ShareLink(item: shareMessage(vol: vol)) {
                    Label("Share Citation\u{2026}", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Document metadata isn’t loaded yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
        .task(id: entry.id) {
            if let dm = appState.downloadManager, dm.isVolumeDownloaded(entry.volumeId) {
                parsedPublicationYear = await DocumentExportSupport.extractPublicationYear(
                    volumeURL: dm.volumeURL(for: entry.volumeId))
            }
            if entry.documentNumber == nil, let pipeline = appState.indexingPipeline {
                resolvedDocumentNumber = (try? await pipeline.documentNumber(
                    volumeId: entry.volumeId, documentId: entry.documentId)) ?? nil
            }
        }
        .zoteroResultAlert(result: $zoteroResult, message: zoteroResultMessage, openURL: openURL)
        .alert(
            String(localized: "document.share.zotero.error.title", defaultValue: "Couldn't Send to Zotero"),
            isPresented: Binding(get: { zoteroError != nil }, set: { if !$0 { zoteroError = nil } }),
            presenting: zoteroError
        ) { _ in
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: { Text($0) }
    }

    // MARK: - Rows

    @ViewBuilder
    private func actionRow(_ title: String, systemImage: String,
                           busy: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage).font(.system(size: 11))
                Spacer()
                if busy { ProgressView().controlSize(.mini) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(busy)
    }

    // MARK: - Builders

    private func year(_ vol: VolumeManifestEntry) -> String {
        DocumentExportSupport.effectiveYear(parsed: parsedPublicationYear, volume: vol)
    }

    private func zoteroItem(vol: VolumeManifestEntry) -> ZoteroJSONExporter.Item {
        DocumentExportSupport.zoteroItem(entry: entry, volume: vol,
                                         documentNumber: effectiveDocumentNumber,
                                         year: year(vol), context: modelContext)
    }

    private func zoteroRIS(vol: VolumeManifestEntry) -> String {
        RISExporter().export(zoteroItem: zoteroItem(vol: vol))
    }

    private func shareMessage(vol: VolumeManifestEntry) -> String {
        let formatted = DocumentExportSupport.formatted(
            entry: entry, volume: vol, documentNumber: effectiveDocumentNumber,
            parsedYear: parsedPublicationYear, style: CitationStyle.current)
        return "\(DocumentExportSupport.plainText(formatted))\n\n\(DocumentExportSupport.canonicalURL(entry: entry))"
    }

    private func zoteroResultMessage(_ result: ZoteroSendResult) -> String {
        String(format: String(localized: "document.share.zotero.result %lld %lld",
                              defaultValue: "Added %lld document and %lld notes to Zotero."),
               Int64(result.addedItems), Int64(result.addedNotes))
    }

    // MARK: - Send

    /// Pushes the document into the user's Zotero library via the Web API (no collection).
    private func sendToZoteroLibrary(vol: VolumeManifestEntry) async {
        let store = ZoteroAccountStore.shared
        guard let apiKey = store.retrieveKey(), let userID = store.userID else {
            zoteroError = ZoteroAPIError.missingCredentials.errorDescription
            return
        }
        zoteroSending = true
        defer { zoteroSending = false }
        do {
            let result = try await ZoteroAPIClient().send(
                items: [zoteroItem(vol: vol)], collectionName: nil,
                apiKey: apiKey, userID: userID, username: store.username)
            zoteroResult = result
        } catch {
            zoteroError = (error as? ZoteroAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Saves a Zotero-importable file via `NSSavePanel`, then opens it in Zotero
    /// (if installed) or reveals it in Finder.
    private func sendToZoteroFile(_ content: String, ext: String, type: UTType) {
        guard let data = content.data(using: .utf8) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = "\(entry.volumeId)-\(entry.documentId).\(ext)"
        panel.title = "Export for Zotero"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Could Not Save File"
                alert.informativeText = error.localizedDescription
                alert.runModal()
                return
            }
            if let zoteroURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.zotero.zotero") {
                NSWorkspace.shared.open([url], withApplicationAt: zoteroURL,
                                        configuration: NSWorkspace.OpenConfiguration())
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }
}

// The document-level user-tag picker is now the shared `UserTagPickerSheet`
// (`DocumentView/UserTagPickerSheet.swift`), consolidated from the former
// macOS `MacTagPickerSheet` and iOS `TagPickerSheetView` (Session 1 / #242).


/// Popover that lists available summarization prompts for the document view.
///
/// Presented by `SummaryBlockView`'s "Change prompt" button. Tapping a prompt
/// dismisses the popover and immediately generates a new summary using that prompt.
/// A "New Prompt…" toolbar button opens `PromptEditorView` in a sheet so the user
/// can create a prompt without leaving the document context.
///
/// Version history:
///   1.0 — Session 75: initial implementation (replaces stub)
struct SummaryPromptPickerView: View {
    @Bindable var vm: DocumentViewModel

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]
    @State private var showNewPromptEditor = false

    var body: some View {
        // macOS popovers should not contain NavigationStack chrome. The native
        // pattern is a title row + action button at the top, list below.
        VStack(spacing: 0) {
            // Header row: title left, "New Prompt…" button right
            HStack {
                Text(String(localized: "document.summarize.picker.title",
                            defaultValue: "Choose a Prompt"))
                    .font(.headline)
                Spacer()
                Button {
                    showNewPromptEditor = true
                } label: {
                    Label(
                        String(localized: "document.summarize.picker.newPrompt",
                               defaultValue: "New Prompt…"),
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Prompt list
            List {
                ForEach(allPrompts) { prompt in
                    Button {
                        dismiss()
                        guard let service = appState.summarizationService else { return }
                        Task {
                            await vm.generateSummary(
                                prompt: prompt,
                                provider: AppleIntelligenceProvider.shared,
                                service: service,
                                activeProjectId: appState.activeProjectId,
                                context: modelContext
                            )
                        }
                    } label: {
                        PromptPickerRowMac(prompt: prompt)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .overlay {
                if allPrompts.isEmpty {
                    ContentUnavailableView(
                        String(localized: "document.summarize.picker.empty.title",
                               defaultValue: "No Prompts"),
                        systemImage: "sparkles",
                        description: Text(
                            String(localized: "document.summarize.picker.empty.detail",
                                   defaultValue: "Add a prompt in Settings → Summarization Prompts.")
                        )
                    )
                }
            }
        }
        .frame(minWidth: 340, minHeight: 280)
        .sheet(isPresented: $showNewPromptEditor) {
            PromptEditorView(promptToEdit: nil)
        }
    }
}

// MARK: - PromptPickerRowMac

/// Single row in `SummaryPromptPickerView`'s list.
///
/// Displays the prompt name, a "Standard" badge for seeded prompts, and a
/// secondary line describing the response format.
private struct PromptPickerRowMac: View {
    let prompt: SummarizationPrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(prompt.name).font(.body)
                if prompt.isStandard {
                    Text(String(localized: "prompt.picker.row.standard",
                                defaultValue: "Standard"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
            Text(formatLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var formatLabel: String {
        switch prompt.responseFormat {
        case .general:
            return String(localized: "prompt.picker.row.format.general",
                          defaultValue: "General prose")
        case .structured(let schema):
            let names = schema.fields.map(\.name).joined(separator: ", ")
            return String(localized: "prompt.picker.row.format.structured",
                          defaultValue: "Structured: \(names)")
        }
    }
}

// MARK: - PersonDetailSheet (macOS)
// The iOS PersonDetailSheet is private to DocumentView/DocumentView.swift.
// This macOS version is used by MacDocumentView.

struct PersonDetailSheet: View {
    let person: PersonEntry
    let mentionCount: Int
    let onFindAllMentions: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Native macOS sheet layout: content area + Divider + bottom button bar.
        // NavigationStack inside a sheet adds unwanted nav-bar chrome on macOS.
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(person.name)
                        .font(.headline)
                    if let desc = person.description {
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                        .padding(.vertical, 4)
                    Text("In Indexed Documents")
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    if mentionCount > 0 {
                        Label(
                            "Mentioned in \(mentionCount) indexed \(mentionCount == 1 ? "document" : "documents")",
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        Button {
                            dismiss()
                            onFindAllMentions()
                        } label: {
                            Label("Find all mentions", systemImage: "magnifyingglass")
                        }
                    } else {
                        Text("Not found in indexed documents")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 400, minHeight: 260)
    }
}

// MARK: - GlossDetailSheet (macOS)

struct GlossDetailSheet: View {
    let gloss: GlossEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Native macOS sheet layout: content area + Divider + bottom button bar.
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(gloss.term)
                        .font(.headline)
                    if let def = gloss.definition {
                        Text(def)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 360, minHeight: 200)
    }
}

/// Content for the macOS **Source Explorer window** (`frus.sourceExplorer`) — the
/// app's home for NARA integration, in three segments:
/// - **Source Note**: the current document's parsed source note
///   (`MacSourceExplorerView`), targeted by the `appState.currentSourceNote*`
///   pending-state hand-off.
/// - **Collections**: the corpus-wide browse-by-collection authority list
///   (Source Explorer Phase 4).
/// - **NARA Lookup**: the live catalog query form (`NARACatalogLookupView`),
///   targeted by the `appState.pendingNARALookup` hand-off — a window segment, not
///   a modal, so the researcher can read the document text they are checking the
///   citation against while querying (UI audit B3).
///
/// Version history:
///   1.0 — New UI scaffolding: source-note window content
///   1.1 — Session 2026-07-04 (Source Explorer Phase 4): Collections segment added
///   1.2 — Session 2026-07-04 (macOS UI audit B3): NARA Lookup segment added,
///          replacing the modal `NARACatalogLookupView` sheets in `MainWindowView`
///          and `MacDocumentWindowView`; consumes `pendingNARALookup` (`.task` +
///          `.onChange`, mirroring MacSearchWindowView's pendingSearch) and re-keys
///          the lookup view's identity per hand-off so `@State(initialValue:)`
///          repopulates the query field (the NARACatalogLookupItem rationale)
struct SourceExplorerWindowView: View {
    @Environment(AppState.self) private var appState
    /// Mint tail for `AppState.openDocument` — when no document host is live, a related-
    /// document tap lands in a fresh standalone document window instead of being dropped.
    @Environment(\.openWindow) private var openWindow

    /// The window's three views: the parsed document note, the corpus-wide
    /// browse-by-collection list (Source Explorer Phase 4), or the live NARA
    /// Catalog lookup form (UI audit B3).
    private enum Mode: Hashable { case note, collections, naraLookup }
    @State private var mode: Mode = .note

    /// The current NARA Lookup hand-off, wrapped for view identity: a fresh `UUID`
    /// per hand-off makes SwiftUI create a brand-new `NARACatalogLookupView`, so
    /// `@State(initialValue:)` is honoured and the query field shows the newly
    /// selected text (see `NARACatalogLookupItem`). `nil` when the user switched to
    /// the segment manually — the form opens empty.
    @State private var naraLookupItem: NARACatalogLookupItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "source.explorer.window.mode", defaultValue: "View"),
                   selection: $mode) {
                Text(String(localized: "source.explorer.window.mode.note",
                            defaultValue: "Source Note")).tag(Mode.note)
                Text(String(localized: "source.explorer.window.mode.collections",
                            defaultValue: "Collections")).tag(Mode.collections)
                Text(String(localized: "source.explorer.window.mode.naraLookup",
                            defaultValue: "NARA Lookup")).tag(Mode.naraLookup)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 400)
            .padding(.vertical, 8)
            Divider()
            switch mode {
            case .note:
                noteContent
            case .collections:
                // The searchable, repository-grouped authority list; rows open the
                // shared Collection detail.
                NavigationStack {
                    CollectionBrowserView()
                }
            case .naraLookup:
                // Live catalog query form. `.id` re-keys the view per hand-off so a
                // new selection replaces a stale query field (fresh @State identity).
                NARACatalogLookupView(initialText: naraLookupItem?.text ?? "",
                                      blockContext: naraLookupItem?.blockContext)
                    .id(naraLookupItem?.id)
            }
        }
        // Consume a NARA Lookup hand-off: `.task` covers a window freshly created by
        // the hand-off (`.onChange` misses a value that was already set), `.onChange`
        // covers one already open — mirroring MacSearchWindowView's pendingSearch.
        .task { consumePendingNARALookup() }
        .onChange(of: appState.pendingNARALookup) { _, request in
            guard request != nil else { return }
            consumePendingNARALookup()
        }
    }

    /// Applies (and clears) `AppState.pendingNARALookup`: switches to the NARA Lookup
    /// segment with a fresh lookup-view identity carrying the handed-off query text.
    private func consumePendingNARALookup() {
        guard let request = appState.pendingNARALookup else { return }
        appState.pendingNARALookup = nil
        naraLookupItem = NARACatalogLookupItem(text: request.text, blockContext: request.blockContext)
        mode = .naraLookup
    }

    /// The pre-Phase-4 window content: the current document's parsed source note.
    @ViewBuilder
    private var noteContent: some View {
        if let note = appState.currentSourceNote {
            MacSourceExplorerView(
                rawSourceNote: note,
                documentYear: appState.currentSourceNoteYear,
                indexingPipeline: appState.indexingPipeline,
                onRelatedDocumentTapped: { vid, did in
                    let entry = DocumentBrowserEntry(
                        documentId: did, volumeId: vid,
                        documentNumber: nil, header: did, dateline: nil, sourceNote: nil
                    )
                    appState.openDocument(entry, from: .tool(.sourceExplorer), using: openWindow)
                },
                documentHeader: appState.currentSourceNoteHeader,
                documentDateline: appState.currentSourceNoteDateline,
                documentVolumeId: appState.currentSourceNoteVolumeId,
                documentId: appState.currentSourceNoteDocumentId
            )
        } else {
            ContentUnavailableView(
                String(localized: "source.explorer.window.empty",
                       defaultValue: "No Document Selected"),
                systemImage: "archivebox",
                description: Text(String(localized: "source.explorer.window.empty.detail",
                    defaultValue: "Open a document with a source note, then tap Sources in the toolbar. Or switch to Collections to browse the archival collections FRUS cites."))
            )
        }
    }
}

#endif // os(macOS)
