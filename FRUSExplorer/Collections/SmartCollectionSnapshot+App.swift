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

    /// Builds a new static collection from a smart collection's resolved results and inserts it into
    /// `context`, with its entries.
    ///
    /// The snapshot is FRUSCoreKit's `snapshot(of:results:)`: every setting of the smart collection under
    /// its display name (suffixed) and with **no** `savedSearchId`, so it is a normal editable collection,
    /// and its entries are the smart collection's apparatus blocks around one `.document` entry per result
    /// (#1996, the third review's J39). The values are written into the models as Import from JSON writes
    /// them (`writeImport`), every field the values carry, so the snapshot holds every setting they hold;
    /// the models' dates are now. A carried block that names a headnote draft gets one of its own, so the
    /// two collections share no draft (#1999). The caller saves the context and selects/opens the result.
    ///
    /// - Returns: The newly inserted snapshot `Collection`.
    @discardableResult
    static func create(
        from smart: Collection,
        results: [DocumentRef],
        into context: ModelContext
    ) -> Collection {
        // The smart collection's live entries: `documentEntries` goes on listing an entry deleted from the context
        // until a save processes the deletion (#1359), and a block the reader has just deleted must not travel.
        let entries = (smart.documentEntries ?? []).filter { !$0.isDeleted }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(CollectionEntryExport.init)
        let value = snapshot(of: CollectionExport(smart, entries: entries), results: results)
        let snapshot = Collection.newForImport(value)
        let now = Date.now
        snapshot.createdAt = now
        snapshot.lastModified = now
        context.insert(snapshot)

        for entryValue in value.entries {
            let entry = CollectionEntry.newForImport(entryValue)
            entry.collectionId = snapshot.id
            entry.createdAt = now
            entry.lastModified = now
            entry.collection = snapshot
            context.insert(entry)
            GeneratedSummary.duplicateHeadnoteDraft(id: entryValue.headnoteSummaryId, to: entry, in: context)
        }

        return snapshot
    }
}
