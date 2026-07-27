// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(iOS)

import SwiftUI

// MARK: - IndexingQueueBannerView

/// Multi-volume progress banner shown above the iOS tab bar when more than one volume
/// is queued for download and indexing.
///
/// Replaces `IndexingBannerView` in `MainTabView.indexingBanner` when
/// `AppState.indexingQueuePosition` is non-nil. Falls back to `IndexingBannerView`
/// when the queue drains to a single volume.
///
/// ## Layout
/// ```
/// [↓↓] Volume 3 of 12          ████████░░░░  ~4m  [chevron]
///      frus1969-76v03
///      [expanded: ⏱ Volume 4 title…]
///      [expanded: ⏱ Volume 5 title…]
/// ```
///
/// The disclosure chevron toggles an expanded list of up to 6 pending volume titles,
/// each prefixed with a clock icon to indicate queued status.
///
/// ## ETA computation
/// Current-volume ETA: remaining docs ÷ `docsPerSecond`.
/// Queue ETA: remaining-volumes × `averageDocumentCount` ÷ `averageDocsPerSecond`.
/// Both are summed into a single "total remaining" estimate. Falls back to corpus-mean
/// doc count (600) until one volume has completed.
///
/// ## Placement
/// Injected via `.safeAreaInset(edge: .bottom, spacing: 0)` in `MainTabView`,
/// identical to `IndexingBannerView`.
///
/// Version history:
///   1.0 — Session 116: initial implementation
///   1.1 — Fix: `hasShownThisSession` moved from `@State` to `@AppStorage` so the
///          educational sheet is not re-triggered every time SwiftUI recreates the
///          banner view during active indexing (e.g. on each progress update).
///   1.2 — Dynamic Type pass 2026-07-04: fixed-point caption fonts replaced with
///          scalable `FRUSTheme.captionFont` / `captionSmallFont` (icons track too).
///   1.3 — SA-1b review fix: explicitly re-inject `AppState` into the
///          `WhileIndexingSheet` presentation so the mid-onboarding series-production
///          dashboard reads real manifest data via the project's explicit
///          environment-re-injection convention, not ambient inheritance.
struct IndexingQueueBannerView: View {

    /// Current volume's indexing progress.
    let update: IndexingProgressUpdate
    /// Position in the multi-volume batch (1-based current and fixed total).
    let queuePosition: (current: Int, total: Int)
    /// Titles of volumes still waiting in the download queue (not including current).
    let volumeTitles: [String]
    /// Discovery metadata for the current volume (arrives after XML parse).
    var metadata: VolumeMetadataDiscovered? = nil
    /// Rolling average docs/s from completed volumes in this batch.
    var averageDocsPerSecond: Double = 0
    /// Rolling average document count from completed volumes; falls back to 600.
    var averageDocumentCount: Int = 600

    /// Shared app state, re-injected into the onboarding sheet below so the
    /// mid-onboarding dashboard reads real manifest data rather than relying on
    /// ambient `@Observable` environment inheritance (matches the explicit
    /// re-injection convention used at `MainTabView`'s `pendingWordCloud` sheet).
    @Environment(AppState.self) private var appState

    @State private var isExpanded = false
    @State private var showWhileIndexing = false
    /// Persisted flag so the educational sheet auto-opens only once, even if SwiftUI
    /// recreates this view during long indexing runs. Use `@AppStorage` rather than
    /// `@State` — `@State` resets to `false` on every view re-creation, causing the
    /// sheet to re-trigger after each progress update.
    @AppStorage("frus.hasShownIndexingEducation") private var hasShownThisSession = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                mainRow
                // Per-volume subtitle is suppressed during the batch-wide
                // optimise phase because update.volumeId is empty then.
                if update.stage != .optimizing {
                    subtitleRow
                    if isExpanded { expandedList }
                }
            }
            .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
            .padding(.vertical, 5)
            .indexingCloudStrip(
                scope: CloudSurfaceArbiter.indexingScope(
                    queuedVolumeIds: appState.indexingBatch?.volumeIds ?? [update.volumeId],
                    manifest: appState.manifestStore
                ),
                isActive: CloudSurfaceArbiter.resolve(appState: appState) == .indexingBackdrop
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .sheet(isPresented: $showWhileIndexing) {
            WhileIndexingSheet()
                .environment(appState)
        }
        .onAppear {
            // Auto-open the educational sheet the first time this banner appears
            // in the current app session.
            guard !hasShownThisSession else { return }
            hasShownThisSession = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showWhileIndexing = true
            }
        }
    }

    // MARK: - Rows

    private var mainRow: some View {
        HStack(spacing: 8) {
            Image(systemName: update.stage == .optimizing
                  ? "wand.and.stars"
                  : "square.and.arrow.down.on.square")
                .font(FRUSTheme.captionFont)
                .foregroundStyle(.secondary)

            Text(update.stage == .optimizing
                 ? String(localized: "indexing.queue.finalizing",
                          defaultValue: "Finalizing index…")
                 : String(localized: "indexing.queue.position",
                          defaultValue: "Volume \(queuePosition.current) of \(queuePosition.total)"))
            .font(FRUSTheme.captionFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            Spacer()

            if update.stage == .optimizing {
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(width: 80)
                    .tint(.accentColor)
            } else if update.totalDocuments > 0 {
                ProgressView(
                    value: Double(update.completedDocuments),
                    total: Double(update.totalDocuments)
                )
                .progressViewStyle(.linear)
                .frame(width: 80)
                .tint(.accentColor)

                if let eta = totalETAString {
                    Text(eta)
                        .font(FRUSTheme.captionSmallFont)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(width: 80)
            }

            if !volumeTitles.isEmpty {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(FRUSTheme.captionSmallFont)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(
                    localized: "indexing.queue.expand.a11y",
                    defaultValue: isExpanded ? "Collapse queue list" : "Expand queue list"
                ))
            }
        }
    }

    private var subtitleRow: some View {
        Text(update.volumeId)
            .font(FRUSTheme.captionSmallFont)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    @ViewBuilder
    private var expandedList: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(volumeTitles.prefix(6), id: \.self) { title in
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(FRUSTheme.captionSmallFont)
                        .foregroundStyle(.tertiary)
                    Text(title)
                        .font(FRUSTheme.captionSmallFont)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            // "Learn while you wait" — opens the educational flow.
            // Re-openable even after the first auto-show.
            Button {
                showWhileIndexing = true
            } label: {
                Label(
                    String(localized: "indexing.learnWhileWaiting",
                           defaultValue: "Learn about FRUS while you wait →"),
                    systemImage: "book.pages"
                )
                .font(FRUSTheme.captionSmallFont)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .padding(.top, 3)
        }
        .padding(.top, 2)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - ETA

    /// Combined ETA: remaining docs in current volume + remaining queued volumes.
    private var totalETAString: String? {
        var totalSeconds = 0.0

        // Remaining documents in the current volume.
        if update.docsPerSecond > 0, update.totalDocuments > update.completedDocuments {
            let remaining = update.totalDocuments - update.completedDocuments
            totalSeconds += Double(remaining) / update.docsPerSecond
        }

        // Remaining queued volumes.
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

#endif // os(iOS)
