// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - SmartCollectionSnapshot

/// Materializes a smart (saved-search) collection into a new, fully static collection
/// (Collections rework Phase 4, D8).
///
/// A smart collection's membership resolves dynamically from a `SavedSearch` at export time,
/// so its contents aren't inspectable or editable in the manager, and it can't be shared as a
/// native `.fruscollection` file (which serializes static entries). A **snapshot** captures the
/// search's current results as ordinary `.document` entries in a new, `savedSearchId`-free
/// collection the researcher can reorder, annotate, section, and export like any other.
///
/// The snapshot is **non-destructive**: the original smart collection is untouched and stays
/// dynamic. The caller resolves the saved search (it needs the runtime `SearchService`) and
/// hands the resolved references here, keeping this step pure and testable.
///
/// Version history:
///   1.0 — Collections rework Phase 4 (D8): initial implementation
enum SmartCollectionSnapshot {

    /// A resolved document reference from a saved-search result.
    typealias DocumentRef = (documentId: String, volumeId: String)

    /// Builds a new static collection from a smart collection's resolved results and inserts it
    /// (plus one ordered `.document` entry per result) into `context`.
    ///
    /// The snapshot copies the source's display name (suffixed), note, project membership, and
    /// composition settings, but carries **no** `savedSearchId`, so it is a normal editable
    /// collection. The caller saves the context and selects/opens the result.
    ///
    /// - Returns: The newly inserted snapshot `Collection`.
    @discardableResult
    static func create(
        from smart: Collection,
        results: [DocumentRef],
        into context: ModelContext
    ) -> Collection {
        let snapshot = Collection(name: snapshotName(smart.name),
                                  note: smart.note,
                                  projectIds: smart.projectIds)
        // Preserve composition so the snapshot exports identically to the smart collection.
        snapshot.defaultBodyDepth = smart.defaultBodyDepth
        snapshot.footnoteStyle = smart.footnoteStyle
        snapshot.tocStyle = smart.tocStyle
        snapshot.applyHighlights = smart.applyHighlights
        snapshot.includeNotes = smart.includeNotes
        snapshot.includeWordCloud = smart.includeWordCloud
        snapshot.summaryPromptId = smart.summaryPromptId
        context.insert(snapshot)

        for (index, ref) in results.enumerated() {
            let entry = CollectionEntry(
                collectionId: snapshot.id,
                documentId: ref.documentId,
                volumeId: ref.volumeId,
                sortOrder: index
            )
            entry.collection = snapshot
            context.insert(entry)
        }

        return snapshot
    }

    /// The display name for a snapshot of a collection named `base`.
    static func snapshotName(_ base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? String(localized: "collection.snapshot.untitled",
                                            defaultValue: "Smart Collection") : trimmed
        return String(localized: "collection.snapshot.name",
                      defaultValue: "\(name) (Snapshot)")
    }
}
