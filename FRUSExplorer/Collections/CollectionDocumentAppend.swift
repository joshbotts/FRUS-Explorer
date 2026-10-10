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

import Foundation
import SwiftData

// MARK: - CollectionDocumentRef

/// One document a command adds to a collection: its volume and its document identifier, and
/// nothing a row on screen could change under it (#1576 lane 2).
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation
struct CollectionDocumentRef: Hashable, Sendable {

    /// The volume the document belongs to (e.g. `"frus1969-76v01"`).
    let volumeId: String
    /// The document's `xml:id` within its volume (e.g. `"d42"`).
    let documentId: String

    /// The `"volumeId/documentId"` key the collection editors share.
    var key: String {
        CollectionDocumentDiscovery.documentKey(volumeId: volumeId, documentId: documentId)
    }
}

// MARK: - CollectionDocumentAppend

/// What ``CollectionDocumentDiscovery/appendDocuments(_:to:modelContext:)`` did.
///
/// The two figures add up to the distinct documents asked for: each was added or was there
/// already. A document named twice in the request is one document.
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation
struct CollectionDocumentAppend: Equatable, Sendable {

    /// The ids of the entries inserted, in the order their documents were given. Ids and not the
    /// entries: an undo re-fetches by id and treats a miss as already undone.
    let insertedEntryIds: [UUID]
    /// How many of the documents asked for the collection already held as a document entry.
    let alreadyPresent: Int

    /// How many documents were added.
    var insertedCount: Int { insertedEntryIds.count }
}

// MARK: - CollectionDocumentAppendRefusal

/// Why ``CollectionDocumentDiscovery/appendDocuments(_:to:modelContext:)`` added nothing.
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation
enum CollectionDocumentAppendRefusal: Error, Equatable {

    /// The collection is linked to a saved search. Its preview, exports, Archives Visit list and
    /// snapshot are built from the search's results, and an entry added by hand is in none of
    /// them (#1593).
    case smartCollection

    /// More documents than one bulk add takes (the owner's decision 5 on #1576).
    case overLimit(count: Int, limit: Int)
}

// MARK: - appendDocuments

extension CollectionDocumentDiscovery {

    /// The most documents one bulk add, or one bulk tag, takes (#1576, decision 5). The limit is
    /// on what one command carries, whatever the collection already holds of it. From lane 3 a
    /// selection over it has the commands disabled, with the reason; this is the same figure,
    /// held where the write is.
    static let bulkDocumentLimit = 1_000

    /// Adds several documents to a collection at one stroke, skipping those it already holds, and
    /// saves (#1576 lane 2).
    ///
    /// ## How it differs from the appends beside it
    ///
    /// ``appendEntries(_:collection:sortedEntries:modelContext:)`` is the editor's own add, where
    /// a repeat is a choice the reader made in front of the outline, so duplicates are allowed
    /// (decision A4). A bulk add comes from a list of search results chosen without the
    /// collection in view, where a repeat is noise: a document that already has a `.document`
    /// entry is skipped and counted (the owner's decision 3). **An excerpt of the same document
    /// does not count as present.** It carries the same volume and document identifiers, and
    /// reading it as the document would leave the collection with the excerpt and "0 documents".
    ///
    /// ## What it guarantees
    ///
    /// - The documents are added in the order given, from one
    ///   `CollectionEntryOrdering.nextSortOrder`, so they sit together after everything the
    ///   collection holds and no entry is renumbered.
    /// - Each entry is linked by the inverse (`entry.collection`), which is what attaches it to a
    ///   collection that has never been saved (see ``appendToCollection(documentId:volumeId:collection:modelContext:)``).
    /// - `collection.lastModified` is set, and the context is **saved once, here.** #1415 was an
    ///   edit lost for want of a save; a thousand entries are not left to the next autosave.
    /// - A smart collection is refused, and so is a list over ``bulkDocumentLimit``, before
    ///   anything is written.
    /// - With nothing to add, nothing is written: no save, and `lastModified` is left alone.
    /// - **A save that fails adds nothing.** The entries are taken back out of the context and
    ///   the collection's `lastModified` is put back before the error is thrown. Left in, they
    ///   would be counted by the collection's row while the caller says the add failed, read as
    ///   already present by a second attempt, and written by whatever saved next.
    ///
    /// - Parameters:
    ///   - documents: The documents to add, in the order they should sit. The caller freezes
    ///     this list when the command is chosen.
    ///   - collection: The collection that takes them.
    ///   - modelContext: The context the entries are inserted into and saved through.
    ///   - save: How the context is saved. The default is `ModelContext.save()`; a test passes
    ///     one that throws, since nothing else makes an in-memory store refuse a save.
    /// - Returns: The entries inserted and how many documents were already there.
    /// - Throws: ``CollectionDocumentAppendRefusal`` when the add is refused, or the save's error.
    @MainActor
    @discardableResult
    static func appendDocuments(
        _ documents: [CollectionDocumentRef],
        to collection: Collection,
        modelContext: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> CollectionDocumentAppend {
        guard collection.savedSearchId == nil else {
            throw CollectionDocumentAppendRefusal.smartCollection
        }

        // One document, however many times the list names it.
        var asked: Set<CollectionDocumentRef> = []
        let distinct = documents.filter { asked.insert($0).inserted }
        guard distinct.count <= bulkDocumentLimit else {
            throw CollectionDocumentAppendRefusal.overLimit(count: distinct.count, limit: bulkDocumentLimit)
        }

        // `.document` entries only: an excerpt, a heading or a note carries a document's
        // identifiers without being the document.
        let held = Set(CollectionEntryOrdering.liveEntries(of: collection)
            .filter { $0.entryKind == .document }
            .map { documentKey(volumeId: $0.volumeId, documentId: $0.documentId) })
        let missing = distinct.filter { !held.contains($0.key) }
        guard !missing.isEmpty else {
            return CollectionDocumentAppend(insertedEntryIds: [], alreadyPresent: distinct.count)
        }

        // The editor's own append, given an outline of its own to fill: it takes one
        // `nextSortOrder` and links each entry by the inverse.
        let stampBefore = collection.lastModified
        var inserted: [CollectionEntry] = []
        appendEntries(missing.map { (documentId: $0.documentId, volumeId: $0.volumeId) },
                      collection: collection, sortedEntries: &inserted, modelContext: modelContext)
        collection.lastModified = .now
        do {
            try save(modelContext)
        } catch {
            // Unlinked first: `documentEntries` goes on listing a deleted entry until the context
            // processes the deletion, and the collection's count reads that list.
            for entry in inserted {
                entry.collection = nil
                modelContext.delete(entry)
            }
            collection.lastModified = stampBefore
            throw error
        }
        return CollectionDocumentAppend(insertedEntryIds: inserted.map(\.id),
                                        alreadyPresent: distinct.count - missing.count)
    }
}
