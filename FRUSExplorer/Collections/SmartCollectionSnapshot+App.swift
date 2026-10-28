// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// The app's half of `SmartCollectionSnapshot` (FRUS Explorer Light, S18b): inserting a snapshot into
// SwiftData. The saved search's run, the result limit and the snapshot's values are FRUSCoreKit's
// (`FRUSCoreKit/Collections/SmartCollectionSnapshot.swift`).

extension SmartCollectionSnapshot {

    /// Builds a new static collection from a smart collection's resolved results and inserts it
    /// (plus one ordered `.document` entry per result) into `context`.
    ///
    /// The snapshot is FRUSCoreKit's `snapshot(of:results:)`: the source's display name (suffixed),
    /// note, project membership, and composition settings, but **no** `savedSearchId`, so it is a
    /// normal editable collection. Every field the values leave out keeps the model's default. The
    /// caller saves the context and selects/opens the result.
    ///
    /// - Returns: The newly inserted snapshot `Collection`.
    @discardableResult
    static func create(
        from smart: Collection,
        results: [DocumentRef],
        into context: ModelContext
    ) -> Collection {
        let value = snapshot(of: CollectionExport(smart, entries: []), results: results)
        let snapshot = Collection(name: value.name, note: value.note, projectIds: value.projectIds)
        snapshot.defaultBodyDepth = value.defaultBodyDepth ?? snapshot.defaultBodyDepth
        snapshot.footnoteStyle = value.footnoteStyle ?? snapshot.footnoteStyle
        snapshot.includeFootnotes = value.includeFootnotes
        snapshot.includeSourceNote = value.includeSourceNote
        snapshot.tocStyle = value.tocStyle ?? snapshot.tocStyle
        snapshot.applyHighlights = value.applyHighlights ?? snapshot.applyHighlights
        snapshot.includeNotes = value.includeNotes ?? snapshot.includeNotes
        snapshot.includeWordCloud = value.includeWordCloud ?? snapshot.includeWordCloud
        snapshot.summaryPromptId = value.summaryPromptId
        context.insert(snapshot)

        for entryValue in value.entries {
            let entry = CollectionEntry(
                collectionId: snapshot.id,
                documentId: entryValue.documentId,
                volumeId: entryValue.volumeId,
                sortOrder: entryValue.sortOrder
            )
            entry.collection = snapshot
            context.insert(entry)
        }

        return snapshot
    }
}
