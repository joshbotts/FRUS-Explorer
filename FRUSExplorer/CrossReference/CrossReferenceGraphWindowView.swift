// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI

// MARK: - CrossReferenceGraphWindowView

/// Root content for the "Cross-Reference Graph" macOS window scene (`frus.crossReferenceGraph`).
///
/// ## Document targeting
/// Observes `AppState.currentGraphEntry`, which `MainWindowView` sets immediately before
/// calling `openWindow(id: "frus.crossReferenceGraph")`. When the entry changes (user opens
/// the graph for a different document while the window is already open), the `.id(entry.id)`
/// modifier on `CrossReferenceGraphView` forces SwiftUI to tear down and reconstruct the view,
/// giving the new document a clean ViewModel with an empty history stack.
///
/// ## "View Document" interaction
/// `CrossReferenceGraphView` sets `appState.pendingBrowseDocument` on macOS instead of
/// pushing into an inline NavigationStack, so the document opens in the main FRUS window.
///
/// Version history:
///   1.0 — Initial implementation (replaces the two-line placeholder in SupportingViews.swift)
struct CrossReferenceGraphWindowView: View {

    @Environment(AppState.self) private var appState

    private var downloadedVolumeIds: Set<String> {
        let entries = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        return Set(entries.compactMap { entry -> String? in
            appState.downloadManager?.isVolumeDownloaded(entry.volumeId) == true
                ? entry.volumeId : nil
        })
    }

    var body: some View {
        if let entry = appState.currentGraphEntry,
           let store = appState.crossReferenceStore {
            CrossReferenceGraphView(
                entry: entry,
                crossReferenceStore: store,
                downloadedVolumeIds: downloadedVolumeIds
            )
            .id(entry.id)   // force re-init when the target document changes
        } else {
            ContentUnavailableView(
                "No Document Selected",
                systemImage: "point.3.connected.trianglepath.dotted",
                description: Text(
                    "Open a document in the main window, then click the Graph toolbar button to explore its cross-references."
                )
            )
            .frame(minWidth: 480, minHeight: 440)
        }
    }
}

#endif // os(macOS)
