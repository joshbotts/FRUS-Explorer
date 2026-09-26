// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ResumeReadingRow

/// "Continue reading" — the one thing a relaunch gives back (#754).
///
/// ## Why this rather than scene restoration
/// The app's entire restoration surface is three `@SceneStorage` keys — the selected tab and two
/// inspector toggles. No navigation, search or reading state survives a relaunch, and iOS terminates
/// backgrounded apps routinely under memory pressure. A researcher three levels into a volume comes
/// back to the corpus root with no trace of where they were (audit H-6).
///
/// Encoding navigation paths into `@SceneStorage` would restore the *ladder*; this restores the
/// *document*, which is the part that matters — and it does so from `ReadingHistoryEntry`, which the
/// app already writes and already syncs through CloudKit. That has three properties path-encoding
/// cannot have:
///
/// - it survives a **reinstall**, because the trail is not scene state;
/// - it works on a **second device**, for the same reason;
/// - it degrades **honestly** — a volume removed since the last read is a row this view filters out,
///   not a restored path that dead-ends or crashes at launch, which is the worst possible moment.
///
/// ## Offered, never forced
/// Nothing auto-opens. The launch a user sees is the one they expect, with one extra row they may
/// ignore or dismiss. Auto-reopening would make the app's first frame depend on history the user may
/// have moved on from, and there is no way to decline it.
///
/// Version history:
///   1.0 — Session 2026-08-08: #754 (audit H-6), owner decision: resume reading, offered
///   1.1 — #1431: on the Browse root in the iPad two-pane the row is a door like the others. While the
///          open root is a document it can offer, it offers THAT document rather than the newest read,
///          and is marked, however deep the reader goes (`openRoot`, `BrowseOpenDoor`)
struct ResumeReadingRow: View {

    /// The level the iPad two-pane's detail pane was opened from — `vm.navigationPath.first` — so the
    /// row can hold on to the document it opened and mark itself while that document is the root
    /// (#1431). `nil` wherever nothing sits beside the row to mark: the Browse stack, and the Mac's
    /// empty reader, which offers it alone.
    ///
    /// The row takes the root rather than a flag because only the row knows its document: the entry
    /// comes from the reading history, which the caller never sees.
    var openRoot: BrowserViewModel.BrowserLevel? = nil

    /// Called with the document to open when the row is tapped.
    let onResume: (DocumentBrowserEntry) -> Void

    @Environment(AppState.self) private var appState

    /// Most-recent-first; the first entry whose volume is still indexed wins.
    ///
    /// Fetched with a small limit rather than the whole trail: this is a launch-path query on the
    /// main context, and the answer is always in the first few rows.
    @Query(sort: \ReadingHistoryEntry.accessedAt, order: .reverse) private var history: [ReadingHistoryEntry]

    /// Dismissed for this session — the row is an offer, and an offer has to be refusable.
    @State private var dismissed = false

    /// The document to resume: the newest read whose volume is still in the index — or, in the iPad
    /// two-pane while the open root is a document the history holds, that document (#1431; the rule
    /// is `BrowseOpenDoor.resumeEntry(in:root:ids:isIndexed:)`).
    ///
    /// Filtering on `indexedVolumeIds` is what keeps the offer honest. A volume removed since the
    /// last read would otherwise produce a row that opens an empty reader.
    private var resumable: ReadingHistoryEntry? {
        guard !dismissed, appState.isBootComplete else { return nil }
        return BrowseOpenDoor.resumeEntry(in: history, root: openRoot,
                                          ids: { ($0.volumeId, $0.documentId) },
                                          isIndexed: { appState.indexedVolumeIds.contains($0) })
    }

    var body: some View {
        if let entry = resumable {
            Button {
                onResume(DocumentBrowserEntry(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    header: entry.displayTitle ?? entry.documentId))
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book.pages")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "browser.resume.title", defaultValue: "Continue reading"))
                            .font(.subheadline.weight(.medium))
                        Text(entry.displayTitle ?? entry.documentId)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(
                localized: "browser.resume.a11y",
                defaultValue: "Continue reading \(entry.displayTitle ?? entry.documentId)"))
            // #1431: marked while this document is the open root, which `resumable` keeps it on however
            // deep the reader goes — not while the same document is open under another door, which is
            // then the one marked.
            .browseOpenDoorMark(BrowseOpenDoor.opensDocument(volumeId: entry.volumeId,
                                                             documentId: entry.documentId, root: openRoot))
            .swipeActions(edge: .trailing) {
                Button(String(localized: "browser.resume.dismiss", defaultValue: "Dismiss"),
                       role: .destructive) { dismissed = true }
            }
        }
    }
}
