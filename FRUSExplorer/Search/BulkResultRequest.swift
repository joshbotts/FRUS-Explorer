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

// MARK: - BulkResultRequest

/// A command chosen on search results, with the documents it acts on frozen at the moment it was
/// chosen (#1576 lane 2).
///
/// ## Why the list is frozen
///
/// A sheet presented over the results outlives the list it was opened from: a search can
/// complete behind it, checklist mode can hide a row, and (from lane 3) the selection can be
/// pruned. A sheet that read the live rows when its button was pressed would then write to
/// documents the reader never saw named in its title. So the request carries the documents
/// themselves, in the order they were on screen, and the sheet is presented with `.sheet(item:)`
/// on this value: everything the sheet needs is in the item, and nothing is a sibling `@State`
/// that could be a frame stale (#862).
///
/// In this lane one row's menu makes a request of one document. Lane 3's selection makes one of
/// many through the same type.
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation, Add to Collection
struct BulkResultRequest: Identifiable, Equatable {

    /// What the reader chose to do with the documents.
    enum Command: Equatable, Sendable {
        /// Add them to a collection the reader picks.
        case addToCollection
    }

    /// A new identity per request, so that asking twice for the same documents presents twice.
    let id = UUID()
    /// What to do.
    let command: Command
    /// The documents, in the order their rows were on screen when the command was chosen. Never
    /// empty, and each document once: the count a sheet's title prints is the count it acts on.
    let documents: [CollectionDocumentRef]
    /// Whether the rows came from a Meaning search. The documents are FRUS's either way; that
    /// these are the ones on the list is then this app's model's doing, and the sheet says so
    /// (the owner's decision 6).
    let fromMeaningSearch: Bool

    /// The request for a command on some results, or `nil` when there are none: a command on
    /// nothing has no sheet to present, and one that opened would confirm an add of nothing.
    ///
    /// - Parameters:
    ///   - command: What to do.
    ///   - results: The rows it acts on, in the order on screen. A document listed twice is
    ///     taken once, where it first stands.
    ///   - fromMeaningSearch: Whether a Meaning search produced the rows.
    init?(_ command: Command, results: [SearchResult], fromMeaningSearch: Bool) {
        var seen: Set<CollectionDocumentRef> = []
        let documents = results
            .map { CollectionDocumentRef(volumeId: $0.volumeId, documentId: $0.documentId) }
            .filter { seen.insert($0).inserted }
        guard !documents.isEmpty else { return nil }
        self.command = command
        self.documents = documents
        self.fromMeaningSearch = fromMeaningSearch
    }
}

// MARK: - BulkResultCopy

/// The words of the commands a result row offers, apart from the views so that both search hosts
/// say the same thing and a test can read them (#1576 lane 2).
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation
enum BulkResultCopy {

    /// The row menu's item that opens the collection picker, and on iPhone and iPad the row's
    /// VoiceOver action as well.
    static var addToCollection: String {
        String(localized: "search.result.addToCollection", defaultValue: "Add to Collection…")
    }
}

// MARK: - BulkResultSheets

/// Presents the sheet a ``BulkResultRequest`` asks for (#1576 lane 2).
///
/// One modifier for both search hosts, so `SearchView` and the Mac's Search window each hold a
/// request and mount this, and neither builds a sheet of its own from whatever is on screen
/// when the sheet opens. The sheet reads the request it is handed and nothing else.
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation
///   1.1 — #1576 lane 3: `onAdded`, the outcome of an Add to Collection handed to the host
private struct BulkResultSheets: ViewModifier {

    /// The request to present, or `nil`. Cleared when the sheet is dismissed.
    @Binding var request: BulkResultRequest?
    /// Told what an Add to Collection did (#1576 lane 3), or `nil` for a host that keeps no
    /// outcome on screen.
    let onAdded: ((CollectionDocumentAppend, Collection) -> Void)?

    func body(content: Content) -> some View {
        content.sheet(item: $request) { request in
            switch request.command {
            case .addToCollection:
                CollectionPickerSheet(documents: request.documents,
                                      fromMeaningSearch: request.fromMeaningSearch,
                                      onAdded: onAdded)
            }
        }
    }
}

extension View {

    /// Presents the sheet for a command chosen on search results, from the request's own frozen
    /// list (#1576 lane 2).
    ///
    /// - Parameters:
    ///   - request: The host's request; set it to present, and it is cleared on dismissal.
    ///   - onAdded: Told the outcome of an Add to Collection and the collection it went to, for a
    ///     host that shows it (#1576 lane 3).
    /// - Returns: The view, with the sheet attached.
    func bulkResultSheets(_ request: Binding<BulkResultRequest?>,
                          onAdded: ((CollectionDocumentAppend, Collection) -> Void)? = nil) -> some View {
        modifier(BulkResultSheets(request: request, onAdded: onAdded))
    }
}
