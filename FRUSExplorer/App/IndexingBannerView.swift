// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(iOS)

import SwiftUI

// MARK: - IndexingBannerView

/// Compact progress banner shown above the iOS tab bar while a volume is being indexed.
///
/// Mirrors the centre-zone of the macOS `StatusBarView`: a system image, a volume ID
/// label, a linear progress bar, and an ETA estimate derived from `docsPerSecond`.
///
/// When `metadata` is non-nil and its `volumeId` matches `update.volumeId`, a secondary
/// row is shown below the progress bar with aggregate discovery counts:
/// "312 persons · 1,247 links · 841/847 dated · 804 docs + 43 notes"
/// Segments with a zero count are omitted.
///
/// ## Placement
/// Injected via `.safeAreaInset(edge: .bottom, spacing: 0)` on each tab's root view
/// in `MainTabView`. This placement adds the banner height to the tab content's bottom
/// safe area so list content is never hidden behind the banner, and the banner floats
/// above the system tab bar without a hardcoded height offset.
///
/// ## ActivityKit
/// A Live Activity / Dynamic Island integration was implemented in `FRUSExplorerWidgets`
/// (previously deferred in Session 93). `AppState.syncIndexingLiveActivity(_:)` manages
/// the activity lifecycle; `IndexingLiveActivity` in the widget extension renders the
/// compact, expanded, and lock-screen presentations. The inline `IndexingCapsule`
/// continues to cover the Browse tab when the app is in the foreground.
///
/// Version history:
///   1.0 — Session 93: initial implementation
///   1.1 — Session 113: `metadata` parameter; secondary discovery-counts row
///   1.2 — Session 116: `IndexingContextCard` added for iPad (regular horizontal size class);
///          `onPersonSearch` callback for scoped person search from the card
///   1.3 — Dynamic Type pass 2026-07-04: fixed-point caption fonts replaced with
///          scalable `FRUSTheme.captionFont` / `captionSmallFont` (icons track too).
struct IndexingBannerView: View {

    let update: IndexingProgressUpdate
    var metadata: VolumeMetadataDiscovered? = nil
    /// The manifest entry for the volume being indexed; required for the context card.
    var volume: VolumeManifestEntry? = nil
    /// Called when the user taps a person chip in the context card.
    var onPersonSearch: ((String) -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppState.self) private var appState

    /// Presents the education flow. Added in O-3b — this banner previously had no route
    /// to it, so a single-volume index could not reach it.
    @State private var showWhileIndexing = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    // Swap the icon + label for the post-batch optimise phase so
                    // the banner doesn't pin on "Indexing …" with a blank volumeId
                    // for 30–60 s while FTS5 segments are merged.
                    if update.stage == .optimizing {
                        Image(systemName: "wand.and.stars")
                            .font(FRUSTheme.captionFont)
                            .foregroundStyle(.secondary)

                        Text(String(
                            localized: "indexing.banner.finalizing",
                            defaultValue: "Finalizing index…"
                        ))
                        .font(FRUSTheme.captionFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                        Spacer()

                        ProgressView()
                            .progressViewStyle(.linear)
                            .frame(width: 80)
                            .tint(.accentColor)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(FRUSTheme.captionFont)
                            .foregroundStyle(.secondary)

                        Text(String(
                            localized: "indexing.banner.label",
                            defaultValue: "Indexing \(update.volumeId)…"
                        ))
                        .font(FRUSTheme.captionFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                        Spacer()

                        if update.totalDocuments > 0 {
                            ProgressView(
                                value: Double(update.completedDocuments),
                                total: Double(update.totalDocuments)
                            )
                            .progressViewStyle(.linear)
                            .frame(width: 80)
                            .tint(.accentColor)

                            if let eta = etaString {
                                Text(eta)
                                    .font(FRUSTheme.captionSmallFont)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(.linear)
                                .frame(width: 80)
                                .tint(.accentColor)
                        }
                    }
                }

                if let meta = metadata, meta.volumeId == update.volumeId,
                   let summary = discoverySummary(meta) {
                    Text(summary)
                        .font(FRUSTheme.captionSmallFont)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
            .padding(.vertical, 5)

            // "Learn while you wait" — the education flow.
            //
            // This link previously existed ONLY in the multi-volume queue banner, so a
            // single-volume download could not reach `IndexingEducationView` at all. The
            // wait is the same length either way; the route should be too.
            Button { showWhileIndexing = true } label: {
                Label(
                    String(localized: "indexing.learnWhileWaiting",
                           defaultValue: "Learn about FRUS while you wait →"),
                    systemImage: "book.pages"
                )
                .font(FRUSTheme.captionSmallFont)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
            .padding(.bottom, 6)

            // Context card: shown only on iPad (regular width) where vertical space permits.
            if horizontalSizeClass == .regular, let vol = volume {
                IndexingContextCard(
                    volume: vol,
                    metadata: metadata.flatMap { $0.volumeId == update.volumeId ? $0 : nil },
                    onPersonSearch: onPersonSearch
                )
                .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                .padding(.bottom, 6)
            }
        }
        .indexingCloudStrip(
            scope: CloudSurfaceArbiter.indexingScope(
                queuedVolumeIds: appState.indexingBatch?.volumeIds ?? [update.volumeId],
                manifest: appState.manifestStore
            ),
            isActive: CloudSurfaceArbiter.resolve(appState: appState) == .indexingBackdrop
        )
        .sheet(isPresented: $showWhileIndexing) { WhileIndexingSheet() }
    }

    private var etaString: String? {
        guard update.docsPerSecond > 0,
              update.totalDocuments > update.completedDocuments else { return nil }
        let remaining = update.totalDocuments - update.completedDocuments
        let seconds = Double(remaining) / update.docsPerSecond
        return "~\(Int(seconds.rounded()))s"
    }

    private func discoverySummary(_ meta: VolumeMetadataDiscovered) -> String? {
        var segments: [String] = []
        if meta.uniquePersonCount > 0 {
            segments.append(String(
                localized: "indexing.banner.meta.persons",
                defaultValue: "\(meta.uniquePersonCount) persons"
            ))
        }
        if meta.crossReferenceCount > 0 {
            segments.append(String(
                localized: "indexing.banner.meta.links",
                defaultValue: "\(meta.crossReferenceCount) links"
            ))
        }
        if meta.datedDocumentCount > 0 {
            let fraction = "\(meta.datedDocumentCount)/\(meta.totalDocuments)"
            segments.append(String(
                localized: "indexing.banner.meta.dated",
                defaultValue: "\(fraction) dated"
            ))
        }
        if meta.totalDocuments > 0 {
            let primaryDocs = meta.totalDocuments - meta.editorialNoteCount
            if meta.editorialNoteCount > 0 {
                segments.append(String(
                    localized: "indexing.banner.meta.docsAndNotes",
                    defaultValue: "\(primaryDocs) docs + \(meta.editorialNoteCount) notes"
                ))
            } else {
                segments.append(String(
                    localized: "indexing.banner.meta.docs",
                    defaultValue: "\(primaryDocs) docs"
                ))
            }
        }
        return segments.isEmpty ? nil : segments.joined(separator: " · ")
    }
}

// MARK: - IndexingInsetState

/// Which of the bottom inset's five occupants owns it, as a value a test can reach.
///
/// **B-6 is why this exists.** The precedence used to live entirely inside
/// `MainTabView.indexingBanner`'s `if`/`else if` chain, where no test could see it — and it had a
/// hole. With a download QUEUED but no indexing batch started, every branch fell through: the
/// batch branches need `batch.latest`, the summary branch needs `completedIndexingMetadata`, and
/// the sync branch is false in the healthy case. The `@ViewBuilder` yielded nothing and the inset
/// collapsed to zero height, while `CloudSurfaceArbiter` had already refused the splash for the
/// same window. `CloudSurfaceArbiterTests.relaunchMidDownloadPrefersIndexing` passed throughout,
/// because it asserts the arbiter's verdict and the verdict was right — nothing rendered it.
///
/// This follows the precedent `AppRootRouter` set for the same reason: a decision living inside a
/// view body has no seam a test can reach, so the decision moves out and the body switches on it.
/// `MainTabView` MUST switch on this rather than re-testing the conditions, or the extraction buys
/// nothing and a mirrored copy in the test file would stay green while the view drifted.
///
/// Version history:
///   1.0 — B-6: extracted from `MainTabView.indexingBanner`, with the queued-download case added
enum IndexingInsetState: Equatable {
    /// The keyboard is up; nothing may render here (#1070).
    case hidden
    /// A sync state worth reporting, and no transient work to outrank it.
    case sync
    /// A live indexing batch.
    case batch
    /// Downloads queued, none of them indexing yet — the B-6 window.
    case downloadsQueued
    /// The post-batch summary card.
    case summary
    /// Nothing to report.
    case none

    /// Decides the occupant. Order is the decision.
    ///
    /// 1. **The keyboard wins outright** (#1070): the inset floats onto the keyboard's accessory
    ///    row and occluded the #861 Done bar. Every state here persists or re-announces.
    /// 2. **A live batch beats everything else**, as before.
    /// 3. **Queued downloads beat the summary card**, so newly queued work supersedes a card the
    ///    reader has not dismissed — the card describes finished work, the queue describes work
    ///    that is happening.
    /// 4. **Transient work beats sync.** This extends the rule already written for indexing at the
    ///    old `:438` — indexing is transient and finishes, while a local-only or failed-sync state
    ///    waits and will still be true when the inset frees up. A queued download is transient in
    ///    exactly the same way, so it inherits the same precedence rather than a new one.
    static func resolve(keyboardIsVisible: Bool,
                        hasBatch: Bool,
                        hasCompletedMetadata: Bool,
                        downloadQueueIsEmpty: Bool,
                        syncIsWorthShowing: Bool) -> IndexingInsetState {
        if keyboardIsVisible { return .hidden }
        if hasBatch { return .batch }
        if !downloadQueueIsEmpty { return .downloadsQueued }
        if hasCompletedMetadata { return .summary }
        if syncIsWorthShowing { return .sync }
        return .none
    }
}

// MARK: - DownloadQueueBannerView

/// The inset's account of downloads that are queued but not yet indexing.
///
/// Deliberately the plainest of the five: an icon, a count, and nothing else. It mirrors what the
/// Mac has shipped since `StatusBarView.activeTask`'s last fallthrough, which passes
/// `progress: nil` and `eta: nil` — there is no progress to report, because the batch that would
/// report it does not exist yet. A spinner here would imply the app knows how far along it is.
///
/// **"Queued" counts the transfer in flight**, because `allQueuedVolumeIds` is active-then-pending.
/// That is the wording the Mac already ships and matching it is the point; it is imprecise on both.
///
/// Version history:
///   1.0 — B-6: initial implementation
struct DownloadQueueBannerView: View {
    /// How many volumes are queued, including the one transferring.
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .font(FRUSTheme.captionFont)
                    .foregroundStyle(.secondary)

                // Two keys rather than a ternary inside one `defaultValue`: a single key carrying
                // two different strings is the silent collision the localized-key lesson warns
                // about, and it is already shipped once in this directory.
                Text(count == 1
                     ? String(localized: "indexing.banner.downloadsQueued.one",
                              defaultValue: "1 download queued")
                     : String(localized: "indexing.banner.downloadsQueued.many",
                              defaultValue: "\(count) downloads queued"))
                    .font(FRUSTheme.captionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .combine)
    }
}

#endif // os(iOS)
